import SwiftUI

struct DiffTreeView: View {
    let entries: [DiffEntry]
    @Binding var selectedID: String?

    var body: some View {
        List(entries, selection: $selectedID) { entry in
            DiffRowView(entry: entry)
                .tag(entry.id)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}
