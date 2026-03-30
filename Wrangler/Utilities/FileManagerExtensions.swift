import Foundation

extension FileManager {
    func ownerOfItem(atPath path: String) -> String? {
        guard let attributes = try? attributesOfItem(atPath: path),
              let ownerName = attributes[.ownerAccountName] as? String else {
            return nil
        }
        return ownerName
    }
}
