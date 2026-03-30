import Foundation
import QuickLookUI

/// Thin wrapper around QLPreviewPanel so any view can trigger Quick Look
/// without worrying about the responder chain.
enum QuickLookHelper {
    static func preview(url: URL) {
        Coordinator.shared.show(url: url)
    }
}

// MARK: - Internal coordinator

private final class Coordinator: NSObject, QLPreviewPanelDataSource {
    static let shared = Coordinator()

    private var currentURL: URL?

    func show(url: URL) {
        currentURL = url
        let panel = QLPreviewPanel.shared()!
        panel.dataSource = self
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        currentURL != nil ? 1 : 0
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        currentURL.map { $0 as NSURL }
    }
}
