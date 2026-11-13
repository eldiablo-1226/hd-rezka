import SwiftUI

/// «Каталог» tab (iPhone; 1.6.0: Collections): the list with a fresh parser (0x100086d54).
struct CollectionsView: View {
    @Binding var isPresented: Bool
    @Binding var id: String
    /// The tab's own parser, kept across redraws: the shell redraws its tabs on a tab switch, and a parser made in the
    /// body came up without the collections.
    @StateObject private var parser = CollectionsParser()

    var body: some View {
        CollectionsListViewComponent(isPresented: $isPresented, id: $id)
            .environmentObject(parser)
    }
}
