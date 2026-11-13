import Foundation
import SwiftSoup

extension String {
    /// "https://<mirror>/films/comedy/93744-name-2026.html" -> "93744".
    func getMovieId() -> String {
        String(components(separatedBy: "/").last?.components(separatedBy: "-").first ?? "")
    }

    /// Reads the player JSON: a get_cdn_series answer ({"url": ...}) or a details page whose
    /// initCDN*Events(...) call carries {"id":"cdnplayer","streams": ...}. With the X-Hdrezka-Ios-App
    /// headers the site sends plain "[360p]https://….mp4,[720p]…" lists, so nothing is decoded here.
    func getMovieVideo() -> MovieVideo {
        let json = (try? JSONSerialization.jsonObject(with: data(using: .utf8)!, options: .fragmentsAllowed)) as? [String: Any]
            ?? pagePlayerJSON()!
        let streams = json["url"] as? String ?? json["streams"] as! String

        var links: [String: String] = [:]
        do {
            try streams.split(separator: ",").forEach { item in
                // A label may be HTML, e.g. <span class="pjs-prem-quality">1080p Ultra<img ...></span>.
                let parts = item.replacingOccurrences(of: "[", with: "").trimmingCharacters(in: .whitespaces).split(separator: "]")
                let label = try SwiftSoup.parse(String(parts[0])).text()
                links[label] = String(parts[1])
            }
        } catch {
            print("error in getMovieVideo")
            return MovieVideo(name: "", _360p: "", _480p: "", _720p: "", _1080p: "", _1080pUltra: "", _1440p: "", _2160p: "",
                              subtitles: nil, position: 0)
        }

        var subtitles: [MovieSubtitles] = []
        if let subtitle = json["subtitle"] as? String, let languages = json["subtitle_lns"] as? [String: Any] {
            subtitles = subtitle.split(separator: ",").compactMap { item in
                let parts = item.split(separator: "]")
                guard parts.count > 1 else { return nil }  // no "]" means no link; the original trapped here
                let name = String(parts[0]).replacingOccurrences(of: "[", with: "")
                let link = String(parts[1])
                guard let lang = languages[name] as? String else { return nil }
                return MovieSubtitles(name: name, link: link, lang: lang)
            }
        }

        return MovieVideo(name: "", _360p: links["360p"], _480p: links["480p"], _720p: links["720p"], _1080p: links["1080p"],
                          _1080pUltra: links["1080p Ultra"], _1440p: links["2K"], _2160p: links["4K"], subtitles: subtitles, position: 0)
    }

    /// The player JSON inside a details page: from `{"id":` through the `}` of the closing `});`.
    private func pagePlayerJSON() -> [String: Any]? {
        let start = range(of: "{\"id\":")!
        guard let end = range(of: "});", range: start.lowerBound..<endIndex) else { return nil }
        let object = self[start.lowerBound...end.lowerBound]
        return (try? JSONSerialization.jsonObject(with: object.data(using: .utf8)!, options: .fragmentsAllowed)) as? [String: Any]
    }

    /// `success` of an ajax JSON answer; false when it is not JSON or has no Bool `success`.
    func isSuccess() -> Bool {
        guard let data = data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return false }
        return json["success"] as? Bool ?? false
    }

    /// "https://<mirror>/films/x.html" -> "films/x.html"; strings not starting with "http" stay as they are.
    func removeMirror() -> String {
        starts(with: "http") ? split(separator: "/").dropFirst(2).joined(separator: "/") : self
    }

    /// Vote counts: "(9 715)" -> "9,7K", "(503 278)" -> "503K". The decimal is the first digit of the
    /// remainder, as in the binary (1 043 261 -> "1,4M").
    func toShortNumber() -> String {
        let number = Int(replacingOccurrences(of: "[\\D\\s]", with: "", options: .regularExpression)) ?? 0
        switch number {
        case 10_000_000...100_000_000: return "\(number / 1_000_000)M"
        case 1_000_000...10_000_000: return "\(number / 1_000_000),\(String(number % 1_000_000).first!)M"
        case 10_000...1_000_000: return "\(number / 1000)K"
        case 1000...10_000: return "\(number / 1000),\(String(number % 1000).first!)K"
        default: return String(number)
        }
    }
}

extension MovieVideo {
    func getAvailableQualities() -> [Quality] {
        [("360p", _360p), ("480p", _480p), ("720p", _720p), ("1080p", _1080p), ("1080p Ultra", _1080pUltra), ("2K", _1440p), ("4K", _2160p)]
            .compactMap { name, url in url.map { Quality(name: name, url: $0) } }
    }
}

extension Array where Element == Quality {
    /// The quality named `name` (the "preferredQuality" setting), else the best one below it, else the lowest.
    /// improvement (critique r1): never above it, so «Смотреть» can say «до 1080p» before the episode's list is known;
    /// 1.6.0 took the highest one when the named one was missing. The site's lists start at 360p, so the lowest one is
    /// above the setting only for a list without the setting's own step or any below it.
    func preferred(name: String) -> Quality? {
        let ranks = PlayerQualityPreference.allCases.map(\.rawValue)
        guard let limit = ranks.firstIndex(of: name) else { return last }
        return last { ranks.firstIndex(of: $0.name).map { $0 <= limit } ?? false } ?? first
    }
}
