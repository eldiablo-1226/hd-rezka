import SwiftUI

/// All titles of one career block ("more" from PesonHorizontalGrid).
struct PersonGridComponent: View {
    var movies: [MovieSimple]
    var title: LocalizedStringKey
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
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
