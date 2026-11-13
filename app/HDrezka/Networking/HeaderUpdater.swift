import Foundation
import Alamofire

class HeaderUpdater {
    /// Fetches the current app version that is sent as X-Hdrezka-Ios-App-Version.
    static func updateHeader() async throws -> String {
        let response = try await getHeader()
        return try version(fromUpdates: response)
    }

    /// `{"code":"45","version":"2.2.5",...}` -> "2.2.5". improvement: any other shape throws; 1.6.0 trapped when a value
    /// was not a string (a number or null), and HomeView reads this on every return to the foreground.
    static func version(fromUpdates response: String) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any],
              let version = json["version"] as? String else { throw URLError(.cannotParseResponse) }
        return version
    }

    /// Update feed of the official Android app, requested without the app headers.
    private static func getHeader() async throws -> String {
        try await siteString(URLRequest(url: "https://api.hdrezka.tech/get.hdrezka_android_app_updates", method: .get))
    }
}
