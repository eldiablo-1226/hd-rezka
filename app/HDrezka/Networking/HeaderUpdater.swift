import Foundation
import Alamofire

class HeaderUpdater {
    /// Fetches the current app version that is sent as X-Hdrezka-Ios-App-Version.
    static func updateHeader() async throws -> String {
        let response = try await getHeader()
        return try version(fromUpdates: response)
    }

    /// `{"code":"45","version":"2.2.5",...}` -> "2.2.5". Like the original it traps on any other
    /// JSON shape (all values must be strings); invalid JSON throws.
    static func version(fromUpdates response: String) throws -> String {
        let json = try JSONSerialization.jsonObject(with: response.data(using: .utf8)!) as! [String: String]
        return json["version"]!
    }

    /// Update feed of the official Android app, requested without the app headers.
    private static func getHeader() async throws -> String {
        try await siteString(URLRequest(url: "https://api.hdrezka.tech/get.hdrezka_android_app_updates", method: .get))
    }
}
