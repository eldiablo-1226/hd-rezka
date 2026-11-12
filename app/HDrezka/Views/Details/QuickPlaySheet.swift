import SwiftUI

/// improvement: what «Смотреть» plays without asking: the voice acting the page marks (the one last watched, or the
/// site's default), and for a series the marked season and episode.
struct PlaybackChoice: Identifiable, Equatable {
    let acting: MovieVoiceActing
    let season: MovieSeason?
    let episode: MovieEpisode?

    /// translatorId, not acting.id: the parser gives every voice acting of a page the same id.
    var id: String { [acting.translatorId, season?.id ?? "", episode?.id ?? ""].joined(separator: "|") }

    /// "Сезон 2, Серия 6 · HDrezka Studio" for a series, the voice acting for a film; empty parts are left out
    /// (a page without a translator list has a nameless voice acting).
    var caption: String {
        let episodePart = [season?.name, episode?.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return [episodePart, acting.name].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// One rule for film or series, used by the caption, the buttons and the voice chips.
    static func isSeries(_ detail: MovieDetailed) -> Bool {
        !(detail.seasons?.isEmpty ?? true)
    }

    static func `default`(for detail: MovieDetailed, hasPremium: Bool = true) -> PlaybackChoice? {
        `default`(voiceActing: detail.voiceActing, seasons: detail.seasons, hasPremium: hasPremium)
    }

    /// nil when there is nothing to play without the full sheet: no voice acting, or a series season without episodes.
    /// Without a subscription a film's marked premium voice acting gives way to the first free one, if there is one
    /// (not for a series: its seasons and episodes belong to the marked voice acting).
    static func `default`(voiceActing: [MovieVoiceActing]?, seasons: [MovieSeason]?, hasPremium: Bool = true) -> PlaybackChoice? {
        guard var acting = DownloadParamsSheet.initialActing(in: voiceActing) else { return nil }
        if acting.isPremium, !hasPremium, seasons?.isEmpty ?? true, let free = voiceActing?.first(where: { !$0.isPremium }) {
            acting = free
        }
        guard let seasons, !seasons.isEmpty else { return PlaybackChoice(acting: acting, season: nil, episode: nil) }
        let season = seasons.first(where: \.isSelected) ?? seasons[0]
        guard let episode = season.episodes.first(where: \.isSelected) ?? season.episodes.first else { return nil }
        return PlaybackChoice(acting: acting, season: season, episode: episode)
    }
}

/// improvement: one tap to play. The quality list itself plays at once in the preferred quality; it asks only when the
/// preference is "ask" or Infuse is on. A premium voice acting without the subscription explains why it can't play.
struct QuickPlaySheet: View {
    var id: String
    var choice: PlaybackChoice
    @Binding var video: String
    @Binding var coverData: CoverData?
    @AppStorage("hasPremium") var hasPremium: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            if choice.acting.isPremium && hasPremium.isEmpty {
                PremiumUnavailableView()
            } else {
                QualitySelectionSheet(id: id, selectedActing: choice.acting, selectedSeason: choice.season,
                                      selectedEpisode: choice.episode, video: $video, dismiss: dismiss, coverData: $coverData)
            }
        }
        // improvement: large too, so a long quality list (up to 4K) isn't cut at half height.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .opaqueSheetBackground()
    }
}
