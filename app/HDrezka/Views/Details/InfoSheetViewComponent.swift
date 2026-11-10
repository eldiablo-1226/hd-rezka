import SwiftUI
import Flow
import YouTubePlayerKit

struct InfoSheetViewComponent: View {
    var id: String
    var detail: MovieDetailed
    var trailer: String?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var detailsNetwork: MovieDetailsParser
    @Binding var personId: String
    @Binding var listData: MovieList
    @Binding var isPresentedPersonInfo: Bool
    @Binding var isPresentedList: Bool
    @Binding var isPresentedMoreSheet: Bool

    // Full-screen "more" page: titles, trailer, description and the info rows (0x100004000…0x100009db4).
    // Tapping a person or a list closes this sheet and opens it on the movie page.
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.nameRussian)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    if let nameOriginal = detail.nameOriginal {
                        Text(nameOriginal)
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    Divider()
                    if let trailer {
                        // shortcut: every Configuration argument at 0x100004834 looks like its default, so .init() is used; compare with YouTubePlayerKit 1.9 defaults
                        YouTubePlayerViewComponent(youTubePlayer: YouTubePlayer(source: .video(id: trailer)))
                    }
                    Text(detail.description)
                        .textSelection(.enabled)
                        .font(.body)
                        .padding(.top, 10)
                    Divider()
                    Text("key_information")
                        .font(.title2)
                        .fontWeight(.bold)
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading) {
                            rowTitle("key_country")
                            rowValue(detail.country)
                        }
                        if detail.releaseDate != nil {
                            VStack(alignment: .leading) {
                                rowTitle("key_releasedate")
                                rowValue(detail.releaseDate!)
                            }
                        }
                        VStack(alignment: .leading) {
                            rowTitle("key_genre")
                            HFlow {
                                ForEachWithIndex(detail.genres) { index, genre in
                                    if index == detail.genres.count - 1 {
                                        item(genre.name)
                                            .lineLimit(2)
                                    } else {
                                        item(genre.name + ",")
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        if let producer = detail.producer {
                            VStack(alignment: .leading) {
                                rowTitle("key_director")
                                HFlow {
                                    ForEachWithIndex(producer) { index, person in
                                        if index == producer.count - 1 {
                                            personLink(person, text: person.name, lineLimit: 2)
                                        } else {
                                            personLink(person, text: person.name + ",", lineLimit: 2)
                                        }
                                    }
                                }
                            }
                        }
                        if let actors = detail.actors {
                            VStack(alignment: .leading) {
                                rowTitle("key_actors")
                                HFlow {
                                    ForEachWithIndex(actors) { index, person in
                                        if index == actors.count - 1 {
                                            personLink(person, text: person.name, lineLimit: nil)
                                        } else {
                                            personLink(person, text: person.name + ",", lineLimit: nil)
                                        }
                                    }
                                    Text("key_and+others")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        if let lists = detail.lists {
                            HFlow {
                                rowTitle("key_lists")
                                ForEachWithIndex(lists) { index, list in
                                    if index == lists.count - 1 {
                                        listLink(list, text: list.name)
                                    } else {
                                        listLink(list, text: list.name + ",")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .listStyle(.plain)
                .toolbar {
                    ToolbarItem(placement: trailingPlacement) {
                        Button {
                            dismiss()
                        } label: {
                            Text("done")
                                .bold()
                        }
                    }
                }
            }
        }
    }

    private var trailingPlacement: ToolbarItemPlacement {
        if #available(iOS 17.0, *) {
            return .topBarTrailing
        } else {
            return .navigationBarTrailing
        }
    }

    private func rowTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.body)
            .fontWeight(.medium)
            .multilineTextAlignment(.leading)
    }

    private func rowValue(_ value: String) -> some View {
        Text(value)
            .font(.callout)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
    }

    private func item(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
    }

    // closure #1 in closure #1 in closure #1 in closure #4 … (0x100008de0)
    private func personLink(_ person: PersonSimple, text: String, lineLimit: Int?) -> some View {
        item(text)
            .lineLimit(lineLimit)
            .underline(true, pattern: .solid)
            .onTapGesture {
                personId = person.id.removeMirror()
                isPresentedPersonInfo.toggle()
                isPresentedMoreSheet.toggle()
            }
    }

    // closure #1 in closure #1 in closure #6 … (0x100009908)
    private func listLink(_ list: MovieList, text: String) -> some View {
        Text(text)
            .font(.callout)
            .underline(true)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .onTapGesture {
                listData = list
                isPresentedList.toggle()
                isPresentedMoreSheet.toggle()
            }
    }
}
