import SwiftUI

/// iPhone grid of full search results (`network.search`).
struct SearchGridComponent: View {
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 110), spacing: 10)]
    @EnvironmentObject var network: Network

    var body: some View {
        LazyVGrid(columns: columns) {
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
