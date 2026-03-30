import Foundation

@Observable
final class AppState {
    var recentSources: [URL] = []
    var recentDestinations: [URL] = []

    private static let recentSourcesKey = "recentSources"
    private static let recentDestinationsKey = "recentDestinations"
    private static let maxRecent = 10

    init() {
        loadRecents()
    }

    func addRecentSource(_ url: URL) {
        recentSources.removeAll { $0 == url }
        recentSources.insert(url, at: 0)
        if recentSources.count > Self.maxRecent {
            recentSources = Array(recentSources.prefix(Self.maxRecent))
        }
        saveRecents()
    }

    func addRecentDestination(_ url: URL) {
        recentDestinations.removeAll { $0 == url }
        recentDestinations.insert(url, at: 0)
        if recentDestinations.count > Self.maxRecent {
            recentDestinations = Array(recentDestinations.prefix(Self.maxRecent))
        }
        saveRecents()
    }

    private func loadRecents() {
        if let paths = UserDefaults.standard.stringArray(forKey: Self.recentSourcesKey) {
            recentSources = paths.map { URL(fileURLWithPath: $0) }
        }
        if let paths = UserDefaults.standard.stringArray(forKey: Self.recentDestinationsKey) {
            recentDestinations = paths.map { URL(fileURLWithPath: $0) }
        }
    }

    private func saveRecents() {
        UserDefaults.standard.set(recentSources.map(\.path), forKey: Self.recentSourcesKey)
        UserDefaults.standard.set(recentDestinations.map(\.path), forKey: Self.recentDestinationsKey)
    }
}
