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

    /// «Дубляж» from "(Дубляж)", «FanVoxUA (Украинский)» from "(FanVoxUA (Украинский))"; nil when the site names none.
    static func voiceName(_ text: String) -> String? {
        var name = text.trimmingCharacters(in: .whitespaces)
        if name.hasPrefix("("), name.hasSuffix(")") { name = String(name.dropFirst().dropLast()) }
        name = name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
}

extension SeriesUpdateItem {
    /// The episode the row announces, for its page (critique r3): "(1 сезон)" and "10 серия " are the page's season and
    /// episode ids "1" and "10"; nil when either number is missing.
    var target: EpisodeTarget? {
        guard let season = season.firstMatch(of: /\d+/), let episode = releasedEpisode.firstMatch(of: /\d+/) else { return nil }
        return EpisodeTarget(season: String(season.output), episode: String(episode.output),
                             voice: SeriesUpdateCardView.voiceName(chosenVoiceActing))
    }
}
