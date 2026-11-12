import SwiftUI

/// Grid of `network.movies` with an invisible paging cell at the end (0x1000d9e50…0x1000da8c4).
struct TitleGridComponent: View {
    @EnvironmentObject var network: Network
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var page: Int
    @State var startPaging: Bool = false

    var body: some View {
        // improvement: a failed first page offers Retry instead of endless skeletons; outside the grid, so it isn't a cell.
        if network.movies.isEmpty && network.moviesLoadFailed {
            // Only vertical room: the view keeps its own side margins, and with the grid's 16 pt on top of them
            // «Сменить зеркало» and «Повторить» didn't fit side by side and Retry fell under the tab bar.
            PageLoadFailedView(failure: network.moviesLoadFailure) { network.retryMovies() }
                .padding(.vertical, DesignTokens.space8)
        } else {
            if network.movies.isEmpty {
                SlowLoadNotice()
                    .padding(.horizontal)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: TitleCardComponent.columnMinimum(typeSize)), spacing: 10)]) {
                ForEach(network.movies) { movie in
                    NavigationLink(destination: DetailsView(id: movie.id, preview: movie)) {
                        TitleCardComponent(model: movie)
                    }
                    .buttonStyle(.plain)
                }
                // improvement: shimmer cards until the first page arrives (1.6.0 showed an empty screen).
                if network.movies.isEmpty {
                    ForEach(0..<12, id: \.self) { _ in
                        TitleCardComponent(model: .placeholder)
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
            // ViewDidLoadModifier here (0x1000d9ff0); the iPad grid uses a plain onAppear.
            .onLoad {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    Task { startPaging = true }
                }
            }
        }
    }
}
