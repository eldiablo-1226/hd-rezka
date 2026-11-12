import SwiftUI

/// One released episode of a followed series (0x10005be80). improvement: the content of a system list row, whose link
/// is the row itself, so VoiceOver reads the series' name (1.6.0's link was the grey card's background shape).
struct SeriesUpdateCardView: View {
    var episode: SeriesUpdateItem

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space4) {
            Text(episode.seriesName)
                .font(.headline)
            Text(Self.episodeLine(episode))
                .font(.subheadline)
            if let voice = Self.voiceName(episode.chosenVoiceActing) {
                Text(voice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignTokens.space4)
    }

    /// «15 серия (1 сезон)» from the site's "15 серия " and "(1 сезон)".
    static func episodeLine(_ episode: SeriesUpdateItem) -> String {
        [episode.releasedEpisode, episode.season].map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// «Дубляж» from "(Дубляж)"; nil when the site names none.
    static func voiceName(_ text: String) -> String? {
        let name = text.trimmingCharacters(in: CharacterSet(charactersIn: "()").union(.whitespaces))
        return name.isEmpty ? nil : name
    }
}
