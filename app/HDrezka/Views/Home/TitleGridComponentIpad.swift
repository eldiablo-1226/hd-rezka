import SwiftUI

/// TitleGridComponent with iPad cards and a lift hover effect (0x100079dfc…0x10007ab78).
struct TitleGridComponentIpad: View {
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 100), spacing: 10)]
    @EnvironmentObject var network: Network
    @Binding var page: Int
    @State var startPaging: Bool = false

    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(network.movies) { movie in
                NavigationLink(destination: DetailsView(id: movie.id)) {
                    TitleCardComponentIpad(model: movie)
                        .hoverEffect(.lift)
                }
                .buttonStyle(.plain)
            }
            if startPaging {
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
