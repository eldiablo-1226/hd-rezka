import SwiftUI

/// iPad list of collections: only the first page is loaded (no paging in the original).
struct CollectionsListViewComponentIpad: View {
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 160), spacing: 16)]
    @Binding var isPresented: Bool
    @Binding var id: String
    @EnvironmentObject var collectionsParser: CollectionsParser

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns) {
                    ForEach(collectionsParser.collections, id: \.name) { collection in
                        NavigationLink(destination: CollectionsMovieListViewComponentIpad(name: collection.name, id: collection.id)
                            .environmentObject(CollectionsParser())) {
                            CollectionsCardViewComponentIpad(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationTitle("key_collections")
            }
            .padding(.horizontal, 16)
            .navigationDestination(isPresented: $isPresented) {
                DetailsView(id: id)
            }
        }
        .onAppear {
            Task {
                try await collectionsParser.parseCollections(CollectionsNetwork().getCollections(page: 1))
            }
        }
    }
}
