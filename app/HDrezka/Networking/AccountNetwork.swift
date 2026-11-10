import Foundation
import SwiftUI
import Alamofire

/// Raw site calls of the account screens; every answer is returned as the body string.
class AccountNetwork {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""

    /// Username / e-mail availability check of the sign-up form.
    func checkRegistration(_ params: [String: String]) async throws -> String {
        try await send(request("/engine/ajax/registration.php", .post, params, contentType: false))
    }

    func getBookmarks() async throws -> String {
        try await send(request("/favorites"))
    }

    func getBookmarksByCategory(id: Int, page: Int) async throws -> String {
        try await send(request("/favorites/\(id)/page/\(page)", contentType: false))
    }

    func getLoginResponse(_ params: [String: String]) async throws -> String {
        try await send(request("/ajax/login/", .post, params))
    }

    /// The start page: its sidebar holds the series updates (followed ones are `.tracked`).
    func getSeriesUpdates() async throws -> String {
        try await send(request(""))
    }

    func getSignUpResponse(_ params: [String: String]) async throws -> String {
        try await send(request("/engine/ajax/quick_register.php", .post, params, contentType: false))
    }

    func getWatchingLaterMovies() async throws -> String {
        try await send(request("/continue/"))
    }

    func logout() async throws -> String {
        try await send(request("/logout"))
    }

    func performBookmarksAction(_ params: [String: String]) async throws -> String {
        try await send(request("/ajax/favorites/", .post, params))
    }

    /// GET with the parameters in the query, as in the binary.
    func removeWatchingItem(_ params: [String: String]) async throws -> String {
        try await send(request("/engine/ajax/cdn_saves_remove.php", .get, params))
    }

    /// `cats[]` repeats in the given order: no extra brackets, keys not sorted.
    func reorderBookmarks(_ params: [String: [String]]) async throws -> String {
        let encoder = URLEncodedFormParameterEncoder(
            encoder: URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, arrayEncoding: .noBrackets))
        let urlRequest = try URLRequest(url: "https://\(settingStore)/ajax/favorites/", method: .post,
                                        headers: siteHeaders(version: remoteVersion, contentType: true))
        return try await send(encoder.encode(params, into: urlRequest))
    }

    /// GET with the parameters appended to `?t=<unix seconds>`, as in the binary.
    func sendWatching(_ params: [String: String]) async throws -> String {
        let time = String(format: "%.0f", Date().timeIntervalSince1970)
        return try await send(request("/ajax/send_save/?t=\(time)", .get, params))
    }

    /// `https://<mirror><path>` with the app headers.
    func request(_ path: String, _ method: HTTPMethod = .get, _ params: [String: String]? = nil,
                 contentType: Bool = true) throws -> URLRequest {
        try siteRequest("https://\(settingStore)\(path)", method, params,
                        headers: siteHeaders(version: remoteVersion, contentType: contentType))
    }

    /// The only network access; tests override it to capture the request.
    func send(_ request: URLRequest) async throws -> String {
        try await siteString(request)
    }
}
