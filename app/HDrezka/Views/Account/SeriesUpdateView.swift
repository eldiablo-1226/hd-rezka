import SwiftUI

/// Followed-series updates grouped by day (body 0x1000170c0, load 0x100018538…).
/// improvement: a system list with a section per day and the screen's title (1.6.0: untitled grey cards, and a lone
/// circle symbol when there was nothing).
struct SeriesUpdateView: View {
    @State var updatesGroup: [SeriesUpdateGroup]? = nil
    /// improvement: a failed request is an error with Retry, not "nothing here" (1.6.0 showed an empty list).
    @State var loadFailure: PageLoadFailure? = nil

    var body: some View {
        content
            .navigationTitle("key_series_updates")
    }

    @ViewBuilder
    private var content: some View {
        if let updatesGroup {
            if !updatesGroup.isEmpty {
                List {
                    ForEach(updatesGroup) { group in
                        Section(group.date.trimmingCharacters(in: .whitespaces)) {
                            // By position: two episodes of one series on one day share the series' id.
                            ForEach(group.releasedEpisodes.indices, id: \.self) { index in
                                let episode = group.releasedEpisodes[index]
                                NavigationLink {
                                    DetailsView(id: episode.id)
                                } label: {
                                    SeriesUpdateCardView(episode: episode)
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("key_nothing+here", systemImage: "bell")
            }
        } else if let loadFailure {
            // Back to the orb, whose task loads the updates again.
            PageLoadFailedView(failure: loadFailure) { self.loadFailure = nil }
        } else {
            LoadingOrb()
                .task(priority: .userInitiated) {
                    do {
                        let groups = try await AccountService().getSeriesUpdates()
                        withAnimation(.default) { updatesGroup = groups }
                    } catch {
                        withAnimation(.default) { loadFailure = PageLoadFailure(error: error, statusCode: nil) }
                    }
                }
        }
    }
}
