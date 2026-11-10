import Foundation
import SwiftUI
import Alamofire

class CollectionsNetwork {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""

    func getCollections(page: Int) async throws -> String {
        try await send(siteRequest("https://\(settingStore)/collections/page/\(page)",
                                   headers: siteHeaders(version: remoteVersion, contentType: true)))
    }

    /// `id` is the collection slug ("4768-filmy-xyz-films").
    func getMoviesInCollectionFiltered(id: String, page: Int, filter: String) async throws -> String {
        try await send(siteRequest("https://\(settingStore)/collections/\(id)/page/\(page)/?filter=\(filter)",
                                   headers: siteHeaders(version: remoteVersion, contentType: true)))
    }

    /// The only network access; tests override it to capture the request.
    func send(_ request: URLRequest) async throws -> String {
        try await siteString(request)
    }
}
