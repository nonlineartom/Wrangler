import Foundation

enum DateFormatting {
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let reportFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func displayString(from date: Date) -> String {
        displayFormatter.string(from: date)
    }

    static func reportString(from date: Date) -> String {
        reportFormatter.string(from: date)
    }

    static func shortString(from date: Date) -> String {
        shortFormatter.string(from: date)
    }
}
