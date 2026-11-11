import SwiftUI

/// improvement (Details redesign): the one selection behind the page's «Смотреть» half: a voice acting and, for a
/// series, that voice acting's own seasons with the marked (or first) season and episode picked. A voice acting's
/// seasons differ from the page's, so a change reloads them; a later tap wins over a slower earlier one.
@MainActor
final class PlaybackSelection: ObservableObject {
    typealias SeasonsLoader = (MovieVoiceActing) async throws -> [MovieSeason]?

    @Published private(set) var actings: [MovieVoiceActing] = []
    @Published private(set) var acting: MovieVoiceActing?
    @Published private(set) var seasons: [MovieSeason]?
    @Published private(set) var season: MovieSeason?
    @Published private(set) var episode: MovieEpisode?
    @Published private(set) var isLoadingSeasons = false
    @Published private(set) var seasonsFailed = false

    private var loadSeasons: SeasonsLoader = { _ in nil }
    private var loadToken = 0
    private var isConfigured = false

    /// Once per page (later calls keep the user's choice): its voice actings and seasons, from what «Смотреть»
    /// plays by default.
    func configure(actings: [MovieVoiceActing]?, seasons: [MovieSeason]?, initial: PlaybackChoice?,
                   loader: @escaping SeasonsLoader) {
        guard !isConfigured else { return }
        isConfigured = true
        self.actings = actings ?? []
        self.seasons = seasons
        acting = initial?.acting
        season = initial?.season
        episode = initial?.episode
        loadSeasons = loader
    }

    var isSeries: Bool { !(seasons?.isEmpty ?? true) }

    /// What «Смотреть» plays now; nil while a voice acting's seasons load or failed, or when a series has no episode.
    var choice: PlaybackChoice? {
        guard let acting, !isLoadingSeasons, !seasonsFailed else { return nil }
        guard seasons != nil else { return PlaybackChoice(acting: acting, season: nil, episode: nil) }
        guard let season, let episode else { return nil }
        return PlaybackChoice(acting: acting, season: season, episode: episode)
    }

    /// Tapping the same voice acting again retries its seasons after a failure.
    func select(_ newActing: MovieVoiceActing) async {
        guard newActing != acting || seasonsFailed else { return }
        acting = newActing
        seasonsFailed = false
        guard seasons != nil else { return }
        loadToken += 1
        let token = loadToken
        isLoadingSeasons = true
        do {
            let fresh = try await loadSeasons(newActing)
            guard token == loadToken else { return }
            apply(fresh)
        } catch {
            guard token == loadToken else { return }
            seasonsFailed = true
        }
        isLoadingSeasons = false
    }

    func select(season newSeason: MovieSeason) {
        season = newSeason
        episode = Self.markedOrFirst(newSeason.episodes)
    }

    func select(episode newEpisode: MovieEpisode) {
        episode = newEpisode
    }

    private func apply(_ fresh: [MovieSeason]?) {
        guard let fresh, !fresh.isEmpty else {
            seasonsFailed = true
            return
        }
        seasons = fresh
        let picked = fresh.first(where: \.isSelected) ?? fresh[0]
        season = picked
        episode = Self.markedOrFirst(picked.episodes)
    }

    private static func markedOrFirst(_ episodes: [MovieEpisode]) -> MovieEpisode? {
        episodes.first(where: \.isSelected) ?? episodes.first
    }

    /// The first `limit` rows; a chosen voice acting that ranks lower takes the last of them, so it never hides.
    static func visibleVoices(_ ordered: [MovieVoiceActing], chosen: MovieVoiceActing?, showsAll: Bool,
                              limit: Int) -> [MovieVoiceActing] {
        guard !showsAll, ordered.count > limit else { return ordered }
        var visible = Array(ordered.prefix(limit))
        if let chosen, !visible.contains(chosen), ordered.contains(chosen) {
            visible[limit - 1] = chosen
        }
        return visible
    }
}

/// improvement: what a voice acting row says besides «chosen» and «premium»: the site's share of viewers
/// (`voiceActingRating`, the page's popularity tooltip).
struct VoiceActingSignals {
    private let shares: [String: Float]

    init(ratings: [MovieVoiceActingRating]?) {
        shares = Dictionary((ratings ?? []).map { (Self.key($0.name), $0.percent) }, uniquingKeysWith: { first, _ in first })
    }

    /// In percent; nil when the tooltip has no row for this voice acting.
    func percent(for acting: MovieVoiceActing) -> Float? {
        return shares[Self.key(acting.name)]
    }

    /// Most watched first; voice actings the tooltip doesn't list keep the page's order after them.
    func ordered(_ actings: [MovieVoiceActing]) -> [MovieVoiceActing] {
        return actings.enumerated().sorted { lhs, rhs in
            let left = percent(for: lhs.element) ?? -1
            let right = percent(for: rhs.element) ?? -1
            return left != right ? left > right : lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// The tooltip and the translator list spell a name slightly differently ("Украинский (1+1) 🇺🇦" next to
    /// "Украинский (1+1)  🇺🇦"): compared without flag emoji, case and repeated spaces.
    static func key(_ name: String) -> String {
        let letters = name.unicodeScalars.filter { !(0x1F1E6...0x1F1FF).contains($0.value) }
        return String(String.UnicodeScalarView(letters)).lowercased()
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// The translator list's data attributes, "1" when set.
enum VoiceFlag: CaseIterable {
    case camrip, ads, directorsCut

    static func flags(of acting: MovieVoiceActing) -> [VoiceFlag] {
        return [acting.isCamrip == "1" ? .camrip : nil, acting.isAds == "1" ? .ads : nil,
         acting.isDirector == "1" ? .directorsCut : nil].compactMap { $0 }
    }

    var title: LocalizedStringKey {
        switch self {
        case .camrip: return "key_voice_camrip"
        case .ads: return "key_voice_ads"
        case .directorsCut: return "key_voice_directors_cut"
        }
    }
}

/// improvement (contract «Два режима одной страницы»): the page's two halves under one header of facts.
enum DetailsMode: Hashable {
    case watch, about

    /// «Смотреть» when the title has saved progress or the page opened to continue it; «О фильме» otherwise, and
    /// always when nothing can play here.
    static func initial(canPlay: Bool, opensOnWatch: Bool, hasProgress: Bool) -> DetailsMode {
        return canPlay && (opensOnWatch || hasProgress) ? .watch : .about
    }

    /// «Смотреть», and «О фильме» or «О сериале».
    func title(isSeries: Bool) -> LocalizedStringKey {
        switch self {
        case .watch: return "key_mode_watch"
        case .about: return isSeries ? "key_mode_about_series" : "key_mode_about"
        }
    }
}

/// improvement: one spelling of seasons, episodes and resume points across the page and its sheets.
enum EpisodeNames {
    /// The page names seasons «Сезон 2», a voice acting's reloaded list only «2»: both read «Сезон 2».
    static func season(_ season: MovieSeason) -> String {
        numbered(season.name, format: "key_season_number")
    }

    static func episode(_ episode: MovieEpisode) -> String {
        numbered(episode.name, format: "key_episode_number")
    }

    /// 1394 -> "23:14", 3730 -> "1:02:10".
    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600, minutes = total % 3600 / 60, rest = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
    }

    private static func numbered(_ name: String, format key: String) -> String {
        return !name.isEmpty && name.allSatisfy(\.isNumber) ? String(format: NSLocalizedString(key, comment: ""), name) : name
    }
}

extension PlaybackChoice {
    /// Saved positions under this are not worth resuming from.
    static let resumeThreshold: Double = 10

    func isResume(_ seconds: Double?) -> Bool {
        return (seconds ?? 0) >= Self.resumeThreshold
    }

    /// The primary button's second line: «Сезон 2, Серия 8 · HDrezka Studio · с 23:14»; a film names its voice acting.
    /// `voiceName` stands in for a page without a translator list, whose one voice acting has no name of its own.
    func detailLine(resume seconds: Double?, voiceName: String? = nil) -> String {
        let episodePart = [season.map(EpisodeNames.season), episode.map(EpisodeNames.episode)]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        let voice = acting.name.isEmpty ? voiceName ?? "" : acting.name
        let resume = isResume(seconds) ? String(format: NSLocalizedString("key_resume_from", comment: ""),
                                                EpisodeNames.clock(seconds ?? 0)) : ""
        return [episodePart, voice, resume].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

extension MovieDetailed {
    /// «Фантастика · 2012 · США»: the first genre, the release year (or the date as the site writes it), the country.
    var factsLine: String {
        let date = releaseDate.map { Self.year(in: $0) ?? $0 }
        return [genres.first?.name, date, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// "19 сентября 2026 года" -> "2026".
    static func year(in date: String) -> String? {
        return date.range(of: #"(19|20)\d{2}"#, options: .regularExpression).map { String(date[$0]) }
    }
}
