import SwiftUI

/// All titles of one career block ("more" from PesonHorizontalGrid).
struct PersonGridComponent: View {
    var movies: [MovieSimple]
    var title: LocalizedStringKey
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: TitleCardComponent.columnMinimum(typeSize)), spacing: 10)]) {
                ForEach(movies) { movie in
                    NavigationLink {
                        DetailsView(id: movie.id, preview: movie)
                    } label: {
                        TitleCardComponent(model: movie)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
