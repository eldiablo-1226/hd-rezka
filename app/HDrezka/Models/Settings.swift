import Foundation

enum DefaultSettings {
    /// Default site mirror, stored under the "mirror" UserDefaults key.
    static let mirror = "ijobs.app"
}

/// Raw values come from the binary's string-switch tables (stored in UserDefaults as-is).
enum PlayerQualityPreference: String, CaseIterable, Identifiable {
    case ask
    case p360 = "360p"
    case p480 = "480p"
    case p720 = "720p"
    case p1080 = "1080p"
    case p1080Ultra = "1080p Ultra"
    case k2 = "2K"
    case k4 = "4K"

    var id: Self { self }

    var displayName: String {
        self == .ask ? String(localized: "key_quality_ask") : rawValue
    }
}

enum ShareMenuVariation: String {
    case selectOption
    case url
    case universalLink
}

/// Raw values read from the binary's switch table (0x1005be1a8); they double as localization keys.
enum StartupPageVariation: String, CaseIterable {
    case watching = "Now watching"
    case last = "key_last_releases"
    case popular = "key_popular"
    case soon = "key_comingsoon"
}
