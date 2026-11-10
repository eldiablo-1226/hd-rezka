import SwiftUI

/// One released episode of a followed series; the card background links to the series (0x10005be80).
struct SeriesUpdateCardView: View {
    var episode: SeriesUpdateItem

    var body: some View {
        ViewThatFits {
            VStack {
                HStack {
                    Text(episode.seriesName).bold()
                    Text(episode.season).foregroundStyle(.secondary)
                    Spacer()
                    VStack {
                        Text(episode.releasedEpisode)
                        Text(episode.chosenVoiceActing).foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                .lineLimit(1)
            }
        }
        .padding(15)
        .background(alignment: .center) {
            NavigationLink {
                DetailsView(id: episode.id)
            } label: {
                RoundedRectangle(cornerRadius: 15, style: .continuous).foregroundStyle(.quinary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
}
