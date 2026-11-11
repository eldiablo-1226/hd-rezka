import SwiftUI

/// Followed-series updates grouped by day (body 0x1000170c0, load 0x100018538…).
struct SeriesUpdateView: View {
    @State var updatesGroup: [SeriesUpdateGroup]? = nil
    /// improvement: a failed request is an error with Retry, not "nothing here" (1.6.0 showed an empty list).
    @State var loadFailure: PageLoadFailure? = nil

    var body: some View {
        if let updatesGroup {
            if !updatesGroup.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    ForEach(updatesGroup) { group in
                        HStack {
                            Text(group.date).bold()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                        .padding(.vertical)
                        ForEach(group.releasedEpisodes) { episode in
                            SeriesUpdateCardView(episode: episode)
                        }
                    }
                }
            } else {
                Image(systemName: "circle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .padding(4)
                Text("key_nothing+here")
                    .font(.title3)
                    .bold()
            }
        } else if let loadFailure {
            // Back to the spinner, whose task loads the updates again.
            PageLoadFailedView(failure: loadFailure) { self.loadFailure = nil }
        } else {
            ProgressView()
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
