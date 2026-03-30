# Wrangler

A native macOS application for video professionals who need to reliably move and synchronize large project directories — hundreds of gigabytes of MXF, ProRes, RAW footage, and project files — between external SSDs, network shares, and remote AFP/SMB volumes.

Built as a modern, first-party-quality replacement for ChronoSync, with a focus on **data integrity**, **transfer visibility**, and **professional workflow speed**.

---

## Features

### Two Modes

**Backup Mode** — Synchronize a directory from an external SSD to a mounted network volume. Analyzes differences with mandatory checksum verification, shows exactly what's in sync and what isn't, then syncs only what needs to change.

**Ingest Mode** — Copy files and folders between any two mounted volumes using a clean dual-pane browser. Designed for fast on-set or in-studio ingests where you need to move footage quickly with confidence it arrived intact.

---

### Data Integrity

- **Mandatory SHA256 checksums** — Every file comparison uses CryptoKit SHA256, not just file size or modification date. You get proof that files are byte-identical.
- **Post-copy verification** — After every file is copied, its destination is checksummed and compared to the source. A file is only marked complete if both checksums match.
- **Resumable transfers** — Copies write to a `.wrangler-partial` temp file. If a transfer drops (network blip, disconnected drive, app crash), restarting picks up from the exact byte offset where it left off. The partial is renamed to the final filename only after checksum verification passes.

---

### Visual Transfer Feedback

- **Block-level progress** — The current file is shown as a grid of 1MB blocks filling in as they transfer. For a 14GB MXF clip, that's ~14,000 blocks lighting up in real time — far more informative than a progress bar.
- **Media thumbnail grid** — When a scan or copy starts, Wrangler extracts thumbnails from every video and photo file in the directory tree (regardless of nesting depth) and displays them in a scrollable grid. MXF, ProRes, R3D, BRAW, JPEG, CR2, ARW, DNG — all supported.
- **Throughput gauge** — Real-time MB/s display with a rolling 5-second average and estimated time remaining.
- **Per-file transfer log** — A scrolling list of completed files with verification status, auto-scrolls as files finish.

---

### Backup Mode in Detail

**Three-phase diff analysis:**

| Phase | Speed | What it does |
|-------|-------|-------------|
| Structural scan | Fast | Enumerates both directory trees in parallel. Files only on one side are immediately classified as New or Orphaned. |
| Size comparison | Fast | Files on both sides with different sizes are classified as Modified without needing a checksum. |
| Checksum verification | Slower | Files with matching sizes are SHA256 checksummed on both source and destination. Match = Identical, mismatch = Modified. |

**Diff visualization:**

- Filter sidebar with counts: All / Identical / New / Modified / Orphaned
- Color-coded tree view: green (identical), blue (new), orange (modified), red (orphaned)
- Directory nodes show aggregate status — if any child is out of sync, the folder shows as modified
- File inspector panel shows side-by-side source vs destination attributes: size, modification date, owner, SHA256

**Post-sync dashboard:**
- Large visual confirmation: "All Files Verified" with checksum seal icon
- Stats: files synced, total bytes transferred, duration, average throughput
- "Re-verify All" button — re-checksums every file in the destination on demand
- Export sync report as plain text or Markdown

---

### Ingest Mode in Detail

- **Dual-pane browser** — left pane is source, right pane is destination
- Navigate by clicking folders; breadcrumb path bar at the top of each pane
- Sort by name, date, or size
- Media files show inline thumbnails (video frame at 1 second, photo thumbnail)
- Select files/folders with cmd/shift-click, then click the copy arrow or drag across
- Full block-level progress and verification during copy

---

### Sync Report

After a Backup sync, Wrangler generates a structured report:

```
Wrangler Sync Report
Generated: 2026-03-30 14:22:05

Source:      /Volumes/SSD_01/Projects/ClientA
Destination: /Volumes/Server/Archive/ClientA
Duration:    12m 34s  |  Throughput: 182.4 MB/s avg
Transferred: 16.3 GB  |  Verified: All checksums match

--- Summary ---
Copied:   28 files
Updated:   5 files
Skipped: 812 files (already identical)
Errors:    0

--- Copied Files ---
  + Media/A001.mxf  14.2 GB  2026-03-28  owner:tom  SHA256:a3f2...
  + Spot_v3.prproj   2.1 MB  2026-03-29  owner:tom  SHA256:8b1c...

--- Updated Files ---
  ~ Spot_v2.prproj   1.8 MB  2026-03-30  owner:tom  SHA256:4e9a...
```

Export as `.txt` or `.md`. File owner is read from POSIX filesystem metadata.

---

## Requirements

- macOS 14.0 (Sonoma) or later
- All source and destination directories must already be mounted in Finder — Wrangler does not mount AFP/SMB shares itself

## Supported Media Formats (for thumbnails)

**Video:** `.mxf`, `.mp4`, `.mov`, `.avi`, `.r3d`, `.braw`, `.mkv`, `.m4v`, `.mpg`

**Photo/RAW:** `.jpg`, `.jpeg`, `.png`, `.tiff`, `.tif`, `.cr2`, `.arw`, `.dng`, `.nef`, `.heic`, `.heif`, `.webp`

---

## Building from Source

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/nonlineartom/Wrangler.git
cd Wrangler
xcodegen generate
open Wrangler.xcodeproj
```

Build and run with ⌘R in Xcode.

**Or build from the command line:**

```bash
xcodebuild -project Wrangler.xcodeproj \
  -scheme Wrangler \
  -configuration Release \
  -derivedDataPath build \
  build
```

The built app will be at `build/Build/Products/Release/Wrangler.app`.

---

## Architecture

```
Wrangler/
├── App/                    # Entry point and global state
├── Engine/
│   ├── ChecksumEngine      # Streaming SHA256 via CryptoKit
│   ├── CopyEngine          # Resumable block copy + post-verify
│   ├── DiffEngine          # Three-phase directory comparison
│   ├── ThumbnailEngine     # AVFoundation + ImageIO thumbnail extraction
│   └── VolumeDetector      # Mounted volume metadata
├── Models/                 # FileEntry, DiffEntry, CopyProgress, SyncReport
├── ViewModels/
│   ├── BackupSession       # Observable coordinator for Backup mode
│   ├── IngestSession       # Observable coordinator for Ingest mode
│   └── FileBrowserModel    # Directory navigation state for Ingest panes
├── Views/
│   ├── Backup/             # Setup, diff tree, progress, dashboard views
│   ├── Ingest/             # Dual-pane browser, file rows, progress view
│   ├── Shared/             # Block progress grid, throughput gauge, thumbnails
│   └── Report/             # Sync report viewer and exporter
└── Utilities/              # Byte/date formatting, report generation
```

**Key design decisions:**

- `ChecksumEngine` and `CopyEngine` are Swift `actor`s — all I/O is safely concurrent without data races
- `DiffEngine` parallelizes checksum computation across all CPU cores via `TaskGroup`
- `ThumbnailEngine` runs on a separate low-priority queue so thumbnail extraction never competes with active file transfers
- `BlockProgressView` is a `Canvas`-based renderer — efficient for thousands of block squares updating at transfer speed
- The project is deliberately unsandboxed for direct distribution, giving full filesystem access to any mounted volume without Security-Scoped Bookmark ceremony

---

## License

MIT
