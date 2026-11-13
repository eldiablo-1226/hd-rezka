import SwiftUI

/// One career block of a person: the first 15 titles in a row plus «Все». improvement (critique r2): its header as the
/// title page heads its sections (title3 bold, a header for VoiceOver), with the same «Все» as Home's row.
struct PesonHorizontalGrid: View {
    var movies: [MovieSimple]
    var title: LocalizedStringKey
    @Binding var isNavigated: Bool

    var body: some View {
        VStack {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                SeeAllLink {
                    PersonGridComponent(movies: movies, title: title)
                        .environmentObject(Network())
                        .onAppear { isNavigated = true }
                        .onDisappear { isNavigated = false }
                }
            }
            .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(movies.prefix(15)) { movie in
                        NavigationLink {
                            DetailsView(id: movie.id, preview: movie)
                                .onAppear { isNavigated = true }
                                .onDisappear { isNavigated = false }
                        } label: {
                            TitleCardComponent(model: movie, fillsColumn: false)
                                .padding(.leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
