import SwiftUI

/// Grid of `network.movies` with an invisible paging cell at the end (0x1000d9e50…0x1000da8c4).
struct TitleGridComponent: View {
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 100), spacing: 10)]
    @EnvironmentObject var network: Network
    @Binding var page: Int
    @State var startPaging: Bool = false

    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(network.movies) { movie in
                NavigationLink(destination: DetailsView(id: movie.id)) {
                    TitleCardComponent(model: movie)
                }
                .buttonStyle(.plain)
            }
            if startPaging {
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
