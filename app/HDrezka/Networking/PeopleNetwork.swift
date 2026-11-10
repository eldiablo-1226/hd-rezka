import Foundation
import SwiftUI
import Alamofire

class PeopleNetwork {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""

    /// `id` is the person slug ("4176-vudi-harrelson"); the site redirects to the URL with a trailing slash.
    func getPersonDetails(id: String) async throws -> String {
        try await send(siteRequest("https://\(settingStore)/person/\(id)",
                                   headers: siteHeaders(version: remoteVersion, contentType: false)))
    }

    /// The only network access; tests override it to capture the request.
    func send(_ request: URLRequest) async throws -> String {
        try await siteString(request)
    }
}
