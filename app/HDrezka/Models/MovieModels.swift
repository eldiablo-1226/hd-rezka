import Foundation

// Stored properties, their order and conformances mirror the Swift reflection
// metadata of the shipped binary (re/swift-interface.txt).

struct MovieSimple: Equatable, Identifiable {
    let id: String
    let name: String
    let details: String
    let poster: String
    // improvement: the listing card's type ("Сериал") and series progress ("2 сезон, 8 серия"); 1.6.0 dropped them.
    var entity: String? = nil
    var info: String? = nil
}

struct SearchResult: Identifiable {
    let id: String
    let name: String
    let details: String
}

struct MovieDetailed: Identifiable {
    let id: String
    let nameRussian: String
    let nameOriginal: String?
    let poster: String
    let hPoster: String
    let duration: String
    let description: String
    let releaseDate: String?
    let country: String
    let ageRestriction: String
    let imdbRating: MovieRating?
    let kpRating: MovieRating?
    let genres: [MovieGenre]
    let lists: [MovieList]?
    let collections: [String: String]?
    let schedule: [SeriesScheduleGroup]?
    let franchise: [MovieFranchisePart]?
    let producer: [PersonSimple]?
    let actors: [PersonSimple]?
    var ytTrailerLink: String?
    let ytTrailerPreview: String?
    let availability: Availability
    let comingSoon: Bool
    let voiceActing: [MovieVoiceActing]?
    let singleVoiceActingName: String?
    let voiceActingRating: [MovieVoiceActingRating]?
    let seasons: [MovieSeason]?
    let video: MovieVideo?
    let bookmarks: [Bookmark: Bool]
    let commentsCount: Int
}

enum Availability: Equatable, Hashable {
    case AVAILABLE_ON_REZKA
    case UNAVAILABLE
}

struct MovieGenre: Identifiable {
    let id: String
    let name: String
}

struct MovieList: Identifiable {
    let id: String
    let name: String
    let moviePosition: Int
}

struct MovieRating {
    let value: Float
    let votesCount: String
    let link: String
}

struct MovieFranchisePart: Equatable, Hashable {
    let id: String
    let name: String
    let year: String
    let rating: Float?
    let current: Bool
    let position: Int
}

struct MovieSeason: Equatable, Hashable {
    let id: String
    let name: String
    let episodes: [MovieEpisode]
    let isSelected: Bool
    let url: String?
}

struct MovieEpisode: Equatable, Hashable {
    let id: String
    let name: String
    let isSelected: Bool
    let url: String?
}

struct MovieVoiceActing: Equatable, Hashable {
    let id: String
    let name: String
    let translatorId: String
    let isCamrip: String
    let isAds: String
    let isDirector: String
    let isSelected: Bool
    let isPremium: Bool
    let url: String?
}

struct MovieVoiceActingRating {
    let name: String
    let percent: Float
}

struct MovieVideo: Equatable, Hashable {
    let name: String
    let _360p: String?
    let _480p: String?
    let _720p: String?
    let _1080p: String?
    let _1080pUltra: String?
    let _1440p: String?
    let _2160p: String?
    let subtitles: [MovieSubtitles]?
    let position: Int
}

struct MovieSubtitles: Equatable, Hashable {
    let name: String
    let link: String
    let lang: String
}

struct Quality: Equatable, Hashable {
    let name: String
    let url: String
}

/// Codable for ContinueWatchingCache.
struct MovieWatchLater: Equatable, Hashable, Codable {
    var id: String
    var name: String
    var details: String
    var watchingInfo: String
    var date: String
    var buttonText: String?
    var dataId: String
}

struct SeriesScheduleGroup: Identifiable {
    var id = UUID()
    let name: String
    let items: [SeriesScheduleItem]
}

struct SeriesScheduleItem: Identifiable {
    var id = UUID()
    let title: String
    let russianEpisodeName: String
    let originalEpisodeName: String?
    let releaseDate: String
}

struct SeriesUpdateGroup: Identifiable {
    var id = UUID()
    var date: String
    var releasedEpisodes: [SeriesUpdateItem]
}

struct SeriesUpdateItem: Identifiable {
    var id: String
    var seriesName: String
    var season: String
    var releasedEpisode: String
    var chosenVoiceActing: String
}

struct Bookmark: Equatable, Hashable {
    let id: Int
    var name: String
}

struct Collection: Equatable, Identifiable {
    let id: String
    let name: String
    let poster: String
    let count: Int
}

struct PersonSimple: Identifiable {
    let id: String
    let name: String
    /// improvement: the `data-photo` of the page's person item, for the cast row; nil when the site has none.
    var photo: String? = nil
}

struct PersonDetailed {
    let nameRu: String
    let nameOrig: String?
    let photo: String
    let career: String
    let birthDate: String?
    let birthPlace: String?
    let deathDate: String?
    let deathPlace: String?
    let height: String?
    let actorMovies: [MovieSimple]?
    let directorMovies: [MovieSimple]?
    let producerMovies: [MovieSimple]?
    let screenwriterMovies: [MovieSimple]?
    let operatorMovies: [MovieSimple]?
    let editorMovies: [MovieSimple]?
    let artistMovies: [MovieSimple]?
}

/// Context for automatically continuing with the next episode.
struct AutoplayContext {
    let movieId: String
    let voiceActing: MovieVoiceActing
    let season: MovieSeason
    let currentEpisode: MovieEpisode
    let qualityName: String
}

/// What the player sheet needs to start playback.
struct CoverData: Identifiable {
    let body: String
    let actingName: String
    let subtitles: [MovieSubtitles]
    let progressKey: String?
    let autoplay: AutoplayContext?

    var id: String { body }
}
