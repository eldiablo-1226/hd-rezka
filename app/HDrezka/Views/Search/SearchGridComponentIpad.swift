import SwiftUI

/// iPad grid of full search results (`network.search`).
struct SearchGridComponentIpad: View {
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 150), spacing: 16)]
    @EnvironmentObject var network: Network

    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(network.search) { movie in
                NavigationLink(destination: DetailsView(id: movie.id, preview: movie)) {
                    TitleCardComponentIpad(model: movie)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}
