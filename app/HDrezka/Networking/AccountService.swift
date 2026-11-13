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

    /// improvement: throws `SiteRefusal` when the site says `success: false` (a session that isn't valid on this mirror),
    /// so the caller can offer «Войти» instead of a bare failure.
    func createBookmarksCategory(name: String) async throws -> Bookmark? {
        let response = try await AccountNetwork().performBookmarksAction(["name": name, "action": "add_cat"])
        if Self.isRefusal(response) { throw SiteRefusal() }
        return try Self.createdCategory(response, name: name)
    }

    func deleteBookmarksCategory(id: Int) async throws -> String {
        try await AccountNetwork().performBookmarksAction(["cat_id": "\(id)", "action": "remove_cat"])
    }

    func removeWatchingItem(item: MovieWatchLater) async throws -> Bool {
        try await AccountNetwork().removeWatchingItem(["id": item.dataId]).isSuccess()
    }

    /// improvement: false when the site refuses the order (1.6.0 ignored the answer, so a refused order stayed on
    /// screen). script.673.js alerts only on `success: false`, so an answer without the flag counts as saved.
    func reorderBookmarksCategories(_ bookmarks: [Bookmark]) async throws -> Bool {
        !Self.isRefusal(try await AccountNetwork().reorderBookmarks(Self.reorderParams(bookmarks)))
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

    /// Ends the session and forgets the premium badge, which the original kept until the next listing page.
    /// improvement: the session cookies go here too, after GET /logout whatever it answers. 1.6.0 left that to the site's
    /// answer, so offline, or on a mirror the cookie doesn't belong to, «Выйти» cleared only the flag and every request
    /// stayed signed in.
    func logout(network: AccountNetwork = AccountNetwork()) async throws {
        await MainActor.run {
            UserDefaults.standard.set("", forKey: "hasPremium")
            ContinueWatchingCache.clear()  // improvement: the row's list belongs to the account
        }
        defer { HTTPCookieStorage.shared.removeCookies(since: .distantPast) }
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

    /// The registration form serialized into one "data" field: `key=value` pairs in dictionary order (the outer form
    /// encoding escapes the whole string once). The site's own form sends it through jQuery's serialize() and
    /// quick_register.php reads it like PHP's parse_str. improvement: a value's "&", "+", "=" and "%" (and what a query
    /// can't hold) are escaped; 1.6.0 sent them raw, so «p&ss» was stored as «p» and «neo+hd@…» as «neo hd@…».
    static func signUpData(email: String, username: String, password: String) -> String {
        let fields = ["email": email, "prevent_autofill_name": "", "name": username,
                      "prevent_autofill_password1": "", "password1": password, "rules": "1",
                      "submit_reg": "submit_reg", "do": "register"]
        let plain = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+="))
        return fields.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: plain) ?? $0.value)" }
            .joined(separator: "&")
    }

    static func reorderParams(_ bookmarks: [Bookmark]) -> [String: [String]] {
        ["action": ["sort_cats"], "cats[]": bookmarks.map { $0.id.description }]
    }

    // MARK: - Answers

    /// The site said no: JSON with `success: false`, the answer script.673.js shows its message for.
    static func isRefusal(_ response: String) -> Bool {
        guard let json = (try? JSONSerialization.jsonObject(with: Data(response.utf8))) as? [String: Any] else { return false }
        return (json["success"] as? Bool) == false
    }

    /// The `success` flag of the login JSON (0x10003a3b4). Traps on any other answer shape, as the original.
    static func loginSucceeded(_ response: String) throws -> Bool {
        let json = try JSONSerialization.jsonObject(with: Data(response.utf8)) as! [String: Any]
        return json["success"]! as! Bool
    }

    /// The new category, or nil when the answer has no numeric "id": `as? Int`, so a string id gives nil too
    /// (0x10003c200). improvement: an answer that isn't a JSON object (a block page served with 200) gives nil too;
    /// 1.6.0 trapped on it.
    static func createdCategory(_ response: String, name: String) throws -> Bookmark? {
        guard let json = (try? JSONSerialization.jsonObject(with: Data(response.utf8))) as? [String: Any],
              let id = json["id"] as? Int else { return nil }
        return Bookmark(id: id, name: name)
    }
}

/// The site answered `success: false` to an account action.
struct SiteRefusal: Error {}
