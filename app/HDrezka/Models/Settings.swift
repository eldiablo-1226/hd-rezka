import Foundation

enum DefaultSettings {
    /// Default site mirror, stored under the "mirror" UserDefaults key.
    static let mirror = "ijobs.app"

    /// improvement: mirrors to pick from (Settings → Зеркало сайта), checked on 2026-11-11 from the user's network the
    /// way the app requests them. Each serves HDRezka's catalogue from its own static CDN (static.hdrezka.ac) and shares
    /// the default mirror's DNS host (ClouDNS) and address range (179.43.x.x). Left out: lookalikes on other
    /// infrastructure (hdrezka.film, hdrezka.inc behind Cloudflare), domains behind a challenge page, and official
    /// domains blocked on this network (hdrezka.ag, rezka.ag, hdrezka.me, …), which the field below still accepts.
    static let knownMirrors: [KnownMirror] = [
        KnownMirror(host: mirror),
        KnownMirror(host: "hdrezka-home.tv"),
        KnownMirror(host: "hdrezka.in"),
        KnownMirror(host: "hdrezka.kim"),
        KnownMirror(host: "hdrezka.name"),
        KnownMirror(host: "hdrezka.website"),
        KnownMirror(host: "omnirezka.tv"),
        KnownMirror(host: "hdrezka.cm", needsLogin: true),
        KnownMirror(host: "standby-rezka.tv", needsLogin: true),
    ]

    /// improvement: registered at launch, so these shadow every `@AppStorage` literal and raw `bool(forKey:)` read.
    /// 1.6.0 declared them with different defaults in different places (Settings showed autoplay on, the quality
    /// sheet read it as off); where they disagreed, the value Settings shows wins. Background downloads are the
    /// exception: they always ran in the background while the Behavior toggle showed off, so the toggle now shows on.
    static let values: [String: Any] = [
        "autoplayNextEpisode": true,
        "background_url_session": true,
        "saveHistory": true,
    ]

    static func register(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: values)
    }
}

/// A mirror from the known list; `needsLogin` when it shows guests the sign-in page instead of the catalogue.
struct KnownMirror: Hashable {
    let host: String
    var needsLogin = false
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
