import Foundation
import SwiftSoup

/// Account actions: builds the form fields, calls AccountNetwork and interprets the answers.
/// The session itself is only the cookie Alamofire's shared session keeps after `login`.
class AccountService {
    var network = Network()

    /// Movies of one bookmarks category; appended to `network.bookmarks` like every Network parser.
    func getBookmarksByCategory(id: Int, page: Int) async throws -> [MovieSimple] {
        let network = self.network
        let html = try await AccountNetwork().getBookmarksByCategory(id: id, page: page)
        return try await network.parseBookmarks(html: html)  // Network is @MainActor: this hops to main, as the binary does
    }

    func getBookmarks() async throws -> [Bookmark] {
        let parser = await AccountParser()
        let html = try await AccountNetwork().getBookmarks()
        return try await parser.parseBookmarks(html: html)
    }

    func getSeriesUpdates() async throws -> [SeriesUpdateGroup] {
        let parser = await AccountParser()
        let html = try await AccountNetwork().getSeriesUpdates()
        return try await parser.parseSeriesUpdates(html: html)
    }

    /// true when the site answers that the address is free.
    func checkEmail(email: String) async throws -> Bool {
        let parser = await AccountParser()
        let html = try await AccountNetwork().checkRegistration(["email": email])
        return try await parser.checkAvailability(html: html)
    }

    /// true when the site answers that the name is free.
    func checkUsername(username: String) async throws -> Bool {
        let parser = await AccountParser()
        let html = try await AccountNetwork().checkRegistration(["name": username])
        return try await parser.checkAvailability(html: html)
    }

    func createBookmarksCategory(name: String) async throws -> Bookmark? {
        let response = try await AccountNetwork().performBookmarksAction(["name": name, "action": "add_cat"])
        return try Self.createdCategory(response, name: name)
    }

    func deleteBookmarksCategory(id: Int) async throws -> String {
        try await AccountNetwork().performBookmarksAction(["cat_id": "\(id)", "action": "remove_cat"])
    }

    func removeWatchingItem(item: MovieWatchLater) async throws -> Bool {
        try await AccountNetwork().removeWatchingItem(["id": item.dataId]).isSuccess()
    }

    func reorderBookmarksCategories(_ bookmarks: [Bookmark]) async throws {
        _ = try await AccountNetwork().reorderBookmarks(Self.reorderParams(bookmarks))
    }

    func addToBookmarks(movieId: String, bookmarkUserCategory: Int) async throws -> String {
        try await AccountNetwork().performBookmarksAction(
            ["post_id": movieId, "cat_id": "\(bookmarkUserCategory)", "action": "add_post"])
    }

    func changeBookmarksCategoryName(id: Int, newName: String) async throws -> Bool {
        try await AccountNetwork().performBookmarksAction(
            ["name": newName, "cat_id": "\(id)", "action": "change_cat_name"]).isSuccess()
    }

    /// On success also reads the premium badge from the start page header; the original waited for the next
    /// listing page, so a subscription showed up late. A failed badge request does not fail the login.
    func login(username: String, password: String, network: AccountNetwork = AccountNetwork()) async throws -> Bool {
        let response = try await network.getLoginResponse(
            ["login_name": username, "login_password": password, "login_not_save": "0"])
        guard try Self.loginSucceeded(response) else { return false }
        if let startPage = try? await network.getSeriesUpdates() {  // GET of the bare start page
            await MainActor.run { _ = try? SwiftSoup.parse(startPage).checkPremium() }
        }
        return true
    }

    /// Ends the session (the site drops the cookie in its answer to GET /logout) and forgets the premium badge,
    /// which the original kept until the next listing page.
    func logout(network: AccountNetwork = AccountNetwork()) async throws {
        await MainActor.run { UserDefaults.standard.set("", forKey: "hasPremium") }
        _ = try await network.logout()
    }

    func saveWatchingState(voiceActing: MovieVoiceActing, season: MovieSeason?, episode: MovieEpisode?) async throws -> Bool {
        try await AccountNetwork().sendWatching(
            Self.watchingStateParams(voiceActing: voiceActing, season: season, episode: episode)).isSuccess()
    }

    func signUp(email: String, username: String, password: String) async throws -> Bool {
        let html = try await AccountNetwork().getSignUpResponse(
            ["data": Self.signUpData(email: email, username: username, password: password)])
        let parser = await AccountParser()
        return try await parser.checkRegistration(html: html)
    }

    // MARK: - Form fields

    /// post_id is the number in front of the first "-" of the voice acting's page name
    /// (".../205-golodnye-igry-2012.html" -> "205"); a film sends season and episode "0".
    static func watchingStateParams(voiceActing: MovieVoiceActing, season: MovieSeason?,
                                    episode: MovieEpisode?) -> [String: String] {
        ["post_id": voiceActing.id.components(separatedBy: "/").last!.components(separatedBy: "-").first!,
         "translator_id": voiceActing.translatorId,
         "season": season?.id ?? "0",
         "episode": episode?.id ?? "0",
         "current_time": "1"]
    }

    /// The registration form serialized into one "data" field: unescaped `key=value` pairs in
    /// dictionary order (the outer form encoding escapes the whole string once).
    static func signUpData(email: String, username: String, password: String) -> String {
        let fields = ["email": email, "prevent_autofill_name": "", "name": username,
                      "prevent_autofill_password1": "", "password1": password, "rules": "1",
                      "submit_reg": "submit_reg", "do": "register"]
        return fields.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }

    static func reorderParams(_ bookmarks: [Bookmark]) -> [String: [String]] {
        ["action": ["sort_cats"], "cats[]": bookmarks.map { $0.id.description }]
    }

    // MARK: - Answers

    /// The `success` flag of the login JSON (0x10003a3b4). Traps on any other answer shape, as the original.
    static func loginSucceeded(_ response: String) throws -> Bool {
        let json = try JSONSerialization.jsonObject(with: Data(response.utf8)) as! [String: Any]
        return json["success"]! as! Bool
    }

    /// The new category, or nil when the answer has no numeric "id": `as? Int`, so a string id gives nil too
    /// (0x10003c200). Traps on a non-object answer, as the original.
    static func createdCategory(_ response: String, name: String) throws -> Bookmark? {
        let json = try JSONSerialization.jsonObject(with: Data(response.utf8)) as! [String: Any]
        guard let id = json["id"] as? Int else { return nil }
        return Bookmark(id: id, name: name)
    }
}
