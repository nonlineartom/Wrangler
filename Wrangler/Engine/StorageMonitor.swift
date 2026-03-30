import Foundation
import IOKit

// MARK: - Storage Monitor

@Observable
final class StorageMonitor {

    struct Sample {
        let readBytesPerSec: Double
        let writeBytesPerSec: Double
        let temperatureCelsius: Double?  // nil if SMC unavailable
    }

    static let shared = StorageMonitor()

    private(set) var history: [Sample] = []
    private(set) var current: Sample = Sample(readBytesPerSec: 0, writeBytesPerSec: 0, temperatureCelsius: nil)

    let historyCapacity = 60  // 60 seconds

    // Peak values for graph Y-axis auto-scale
    var peakBytesPerSec: Double {
        let peaks = history.flatMap { [$0.readBytesPerSec, $0.writeBytesPerSec] }
        return max(peaks.max() ?? 0, 1_048_576)  // floor at 1 MB/s so graph isn't blank
    }

    private var prevReadBytes: UInt64 = 0
    private var prevWriteBytes: UInt64 = 0
    private var prevSampleTime: Date = .now
    private var timer: Timer?
    private var smcConn: io_connect_t = 0
    private var smcAvailable = false

    private init() {
        openSMC()
        // Baseline: capture current totals without computing a rate
        let (r, w) = diskIOBytes()
        prevReadBytes = r
        prevWriteBytes = w
        // Pre-fill history with zeros so graph renders immediately
        history = Array(repeating: Sample(readBytesPerSec: 0, writeBytesPerSec: 0, temperatureCelsius: nil),
                        count: historyCapacity)
        scheduleTimer()
    }

    deinit {
        timer?.invalidate()
        if smcConn != 0 { IOServiceClose(smcConn) }
    }

    // MARK: - Timer

    private func scheduleTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Date.now
        let elapsed = now.timeIntervalSince(prevSampleTime)
        guard elapsed > 0 else { return }

        let (readBytes, writeBytes) = diskIOBytes()
        let readRate  = max(0, Double(readBytes)  - Double(prevReadBytes))  / elapsed
        let writeRate = max(0, Double(writeBytes) - Double(prevWriteBytes)) / elapsed
        prevReadBytes = readBytes
        prevWriteBytes = writeBytes
        prevSampleTime = now

        let temp = smcAvailable ? readSSDTemperature() : nil
        let sample = Sample(readBytesPerSec: readRate, writeBytesPerSec: writeRate, temperatureCelsius: temp)
        current = sample
        history.append(sample)
        if history.count > historyCapacity { history.removeFirst() }
    }

    // MARK: - Disk I/O via IOKit

    private func diskIOBytes() -> (read: UInt64, write: UInt64) {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IOBlockStorageDriver"),
                                           &iter) == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iter) }

        var service = IOIteratorNext(iter)
        while service != 0 {
            defer { IOObjectRelease(service) }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {
                totalRead  += (stats["Bytes (Read)"]  as? UInt64) ?? 0
                totalWrite += (stats["Bytes (Write)"] as? UInt64) ?? 0
            }
            service = IOIteratorNext(iter)
        }
        return (totalRead, totalWrite)
    }

    // MARK: - SMC Temperature

    // Flat struct mirroring SMCKeyData_t (80 bytes).
    // Layout matches the C struct via explicit padding fields.
    private struct SMCKeyData {
        var key: UInt32 = 0
        // SMCVers_t (6 bytes)
        var versMajor: UInt8 = 0, versMinor: UInt8 = 0, versBuild: UInt8 = 0, versReserved: UInt8 = 0
        var versRelease: UInt16 = 0
        var _p1: UInt16 = 0          // 2-byte pad so pLimitData is 4-byte aligned (offset 12)
        // SMCPLimitData_t (16 bytes, offset 12)
        var pLimitVersion: UInt16 = 0, pLimitLength: UInt16 = 0
        var pLimitCPU: UInt32 = 0, pLimitGPU: UInt32 = 0, pLimitMem: UInt32 = 0
        // SMCKeyInfoData_t (offset 28)
        var keyInfoDataSize: UInt32 = 0   // IOByteCount32
        var keyInfoDataType: UInt32 = 0
        var keyInfoDataAttributes: UInt8 = 0
        var _p2: UInt8 = 0, _p3: UInt8 = 0, _p4: UInt8 = 0  // 3-byte pad (offset 40)
        // Fields (offset 40)
        var result: UInt8 = 0, status: UInt8 = 0, data8: UInt8 = 0
        var _p5: UInt8 = 0           // pad before data32 (offset 44)
        var data32: UInt32 = 0       // offset 44
        // Payload bytes (offset 48, 32 bytes)
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
                   (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private func fourCC(_ s: String) -> UInt32 {
        let b = Array(s.utf8)
        guard b.count == 4 else { return 0 }
        return UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3])
    }

    private func openSMC() {
        guard MemoryLayout<SMCKeyData>.size == 80 else { return }
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard svc != 0 else { return }
        defer { IOObjectRelease(svc) }
        if IOServiceOpen(svc, mach_task_self_, 0, &smcConn) == KERN_SUCCESS {
            smcAvailable = true
        }
    }

    private func smcCallStruct(input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        var outSize = MemoryLayout<SMCKeyData>.size
        return withUnsafeMutableBytes(of: &output) { outPtr in
            withUnsafeBytes(of: &input) { inPtr in
                IOConnectCallStructMethod(smcConn, 2,
                                         inPtr.baseAddress!, MemoryLayout<SMCKeyData>.size,
                                         outPtr.baseAddress!, &outSize)
            }
        }
    }

    /// Read a key's raw bytes from SMC. Returns nil on any failure.
    private func smcReadBytes(key: String) -> [UInt8]? {
        guard smcConn != 0 else { return nil }

        // Phase 1: get key info (data size + type)
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = fourCC(key)
        input.data8 = 9  // kSMCGetKeyInfo

        guard smcCallStruct(input: &input, output: &output) == KERN_SUCCESS,
              output.result == 0 else { return nil }

        let dataSize = output.keyInfoDataSize
        guard dataSize > 0, dataSize <= 32 else { return nil }

        // Phase 2: read key value
        input = SMCKeyData()
        input.key = fourCC(key)
        input.keyInfoDataSize = dataSize
        input.data8 = 5  // kSMCReadKey
        output = SMCKeyData()

        guard smcCallStruct(input: &input, output: &output) == KERN_SUCCESS,
              output.result == 0 else { return nil }

        return withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(dataSize))) }
    }

    /// Decode sp78 fixed-point (signed 7.8) temperature from two bytes.
    private func sp78ToDouble(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        let temp = Double(raw) / 256.0
        return (temp > 0 && temp < 120) ? temp : nil
    }

    /// Try common NVMe / flash storage temperature SMC keys.
    private func readSSDTemperature() -> Double? {
        // Apple Silicon NVMe keys, then Intel/Thunderbolt fallbacks
        let candidates = ["Ts0D", "Ts1D", "Ts2D", "TH0A", "TH0B", "TH1A", "TSOD"]
        for key in candidates {
            if let bytes = smcReadBytes(key: key), let temp = sp78ToDouble(bytes) {
                return temp
            }
        }
        return nil
    }
}
