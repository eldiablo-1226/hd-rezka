import SwiftUI

/// TitleGridComponent with iPad cards and a lift hover effect (0x100079dfc…0x10007ab78).
struct TitleGridComponentIpad: View {
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 100), spacing: 10)]
    @EnvironmentObject var network: Network
    @Binding var page: Int
    @State var startPaging: Bool = false

    var body: some View {
        // improvement: a failed first page offers Retry instead of endless skeletons; outside the grid, so it isn't a cell.
        if network.movies.isEmpty && network.moviesLoadFailed {
            PageLoadFailedView(failure: network.moviesLoadFailure) { network.retryMovies() }
                .padding()
        } else {
            LazyVGrid(columns: columns) {
                ForEach(network.movies) { movie in
                    NavigationLink(destination: DetailsView(id: movie.id)) {
                        TitleCardComponentIpad(model: movie)
                            .hoverEffect(.lift)
                    }
                    .buttonStyle(.plain)
                }
                // improvement: shimmer cards until the first page arrives (1.6.0 showed an empty screen).
                if network.movies.isEmpty {
                    ForEach(0..<12, id: \.self) { _ in
                        TitleCardComponentIpad(model: .placeholder)
                            .redacted(reason: .placeholder)
                            .accessibilityHidden(true)
                    }
                }
                // improvement: no paging cell under the skeletons, or a Retry would also request the next page.
                if startPaging && !network.movies.isEmpty {
                    Color.clear.onAppear { page += 1 }
                }
            }
            .padding()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    Task { startPaging = true }
                }
            }
        }
    }
}
