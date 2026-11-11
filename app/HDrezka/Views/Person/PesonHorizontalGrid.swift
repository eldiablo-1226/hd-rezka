import SwiftUI

/// One career block of a person: the first 15 titles in a row plus "more".
struct PesonHorizontalGrid: View {
    var movies: [MovieSimple]
    var title: LocalizedStringKey
    @Binding var isNavigated: Bool

    var body: some View {
        VStack {
            HStack {
                Text(title)
                    .font(.title2)
                    .bold()
                Spacer()
                NavigationLink {
                    PersonGridComponent(movies: movies, title: title)
                        .environmentObject(Network())
                        .onAppear { isNavigated = true }
                        .onDisappear { isNavigated = false }
                } label: {
                    Text("key_more")
                }
            }
            .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(movies.prefix(15)) { movie in
                        NavigationLink {
                            DetailsView(id: movie.id, preview: movie)
                                .onAppear { isNavigated = true }
                                .onDisappear { isNavigated = false }
                        } label: {
                            TitleCardComponent(model: movie)
                                .padding(.leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
