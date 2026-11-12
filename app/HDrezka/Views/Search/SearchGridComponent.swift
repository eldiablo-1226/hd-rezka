import SwiftUI

/// iPhone grid of full search results (`network.search`).
struct SearchGridComponent: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject var network: Network

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: TitleCardComponent.columnMinimum(typeSize, phone: 110)), spacing: 10)]) {
            ForEach(network.search) { movie in
                NavigationLink(destination: DetailsView(id: movie.id, preview: movie)) {
                    TitleCardComponent(model: movie)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}
