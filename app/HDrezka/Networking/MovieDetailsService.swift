import Foundation
import SwiftUI
import Alamofire

class MovieDetailsService: ObservableObject {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""

    /// POST /ajax/get_cdn_series/ with the given form fields; returns the raw JSON text.
    func getMovieVideo(params: [String: String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            AF.request(Self.cdnSeriesURL(mirror: settingStore), method: .post, parameters: params,
                       encoder: URLEncodedFormParameterEncoder.default, headers: headers)
                .responseString { response in
                    switch response.result {
                    case .success(let value): continuation.resume(returning: value)
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }
        }
    }

    /// GET of a full page URL (a translator or episode link), with the same headers as the POST.
    func getMovieVideo(url: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get, headers: headers)
                .responseString { response in
                    switch response.result {
                    case .success(let value): continuation.resume(returning: value)
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }
        }
    }

    func getMovieVideo(voiceActing: MovieVoiceActing, season: MovieSeason?, episode: MovieEpisode?, id: String) async throws -> MovieVideo {
        if let url = Self.pageURL(voiceActing: voiceActing, episode: episode) {
            return try await getMovieVideo(url: url).getMovieVideo()
        }
        return try await getMovieVideo(params: Self.videoParams(voiceActing: voiceActing, season: season, episode: episode, id: id)).getMovieVideo()
    }

    func getSeriesSeasons(movieId: String, voiceActing: MovieVoiceActing) async throws -> [MovieSeason]? {
        let response: String
        if let url = voiceActing.url {
            response = try await getMovieVideo(url: url)
        } else {
            response = try await getMovieVideo(params: Self.seasonsParams(movieId: movieId, voiceActing: voiceActing))
        }
        return MovieDetailsParser().parseSeriesSeasons(response)
    }

    private var headers: HTTPHeaders {
        ["Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
         "X-Hdrezka-Ios-App": "1",
         "X-Hdrezka-Ios-App-Version": remoteVersion]
    }
}

// Request pieces, kept pure so they can be tested without network.
extension MovieDetailsService {
    /// `t` is the current Unix time in whole seconds (String(format: "%.0f", timeIntervalSince1970)).
    static func cdnSeriesURL(mirror: String, date: Date = Date()) -> String {
        "https://" + mirror + "/ajax/get_cdn_series/?t=" + String(format: "%.0f", date.timeIntervalSince1970)
    }

    /// Page that getMovieVideo(voiceActing:season:episode:id:) GETs instead of the POST: the episode link wins
    /// over the translator link. getSeriesSeasons checks only voiceActing.url.
    static func pageURL(voiceActing: MovieVoiceActing, episode: MovieEpisode?) -> String? {
        episode?.url ?? voiceActing.url
    }

    /// Fields for a film (action get_movie) or one episode (get_stream, when both season and episode are given).
    static func videoParams(voiceActing: MovieVoiceActing, season: MovieSeason?, episode: MovieEpisode?, id: String) -> [String: String] {
        var params: [String: String] = [:]
        params["id"] = numericId(voiceActing.id.isEmpty ? id : voiceActing.id)
        params["translator_id"] = voiceActing.translatorId
        if !voiceActing.isCamrip.isEmpty { params["is_camrip"] = voiceActing.isCamrip }
        if !voiceActing.isAds.isEmpty { params["is_ads"] = voiceActing.isAds }
        if !voiceActing.isDirector.isEmpty { params["is_director"] = voiceActing.isDirector }
        if let season, let episode {
            params["season"] = season.id
            params["episode"] = episode.id
            params["action"] = "get_stream"
        } else {
            params["action"] = "get_movie"
        }
        return params
    }

    /// Fields for the season/episode list of one translator (action get_episodes).
    static func seasonsParams(movieId: String, voiceActing: MovieVoiceActing) -> [String: String] {
        var params: [String: String] = [:]
        params["id"] = numericId(movieId)
        params["translator_id"] = voiceActing.translatorId
        params["action"] = "get_episodes"
        return params
    }

    /// Like String.getMovieId(), but nil instead of "" (the binary then leaves "id" out of the form).
    private static func numericId(_ value: String) -> String? {
        value.components(separatedBy: "/").last?.components(separatedBy: "-").first
    }
}
