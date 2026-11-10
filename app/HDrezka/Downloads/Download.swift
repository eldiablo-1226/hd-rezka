import Foundation

enum DownloadDestination: String, CaseIterable, Codable, Identifiable {
    case app
    case gallery
    case files

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .app: return String(localized: "key_download_destination_app")
        case .gallery: return String(localized: "key_download_destination_gallery")
        case .files: return String(localized: "key_download_destination_files")
        }
    }
}

enum DownloadState: String, Codable {
    case downloading
    case paused
    case completed
    case failed
}

struct Download: Codable, Hashable, Identifiable {
    let id: UUID
    var title: String
    var subtitle: String
    var poster: String
    var quality: String
    var sourceURL: String
    var fileName: String
    var state: DownloadState
    var createdAt: Date
    var destination: DownloadDestination
    var receivedBytes: Int64
    var totalBytes: Int64

    private enum CodingKeys: CodingKey {
        case id, title, subtitle, poster, quality, sourceURL, fileName, state, createdAt, destination, receivedBytes, totalBytes
    }

    var displayName: String { subtitle.isEmpty ? title : title + " — " + subtitle }

    var fractionCompleted: Double {
        guard totalBytes > 0 else { return state == .completed ? 1 : 0 }
        return min(Double(receivedBytes) / Double(totalBytes), 1)
    }
}

// In an extension so the memberwise init survives. Only `destination` is optional
// (entries saved before it existed decode as `.app`); `encode(to:)` stays synthesized.
extension Download {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        poster = try container.decode(String.self, forKey: .poster)
        quality = try container.decode(String.self, forKey: .quality)
        sourceURL = try container.decode(String.self, forKey: .sourceURL)
        fileName = try container.decode(String.self, forKey: .fileName)
        state = try container.decode(DownloadState.self, forKey: .state)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        destination = try container.decodeIfPresent(DownloadDestination.self, forKey: .destination) ?? .app
        receivedBytes = try container.decode(Int64.self, forKey: .receivedBytes)
        totalBytes = try container.decode(Int64.self, forKey: .totalBytes)
    }
}
