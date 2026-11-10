import AVFoundation

/// Serves a synthetic master playlist (`mainm3u8://`) that adds the external subtitles as a
/// `SUBTITLES` group, the real media playlist with absolute segment URLs (`fragmentsm3u8://`)
/// and one single-segment WebVTT playlist per subtitle (`subtitlesm3u8://<lang>`).
class CustomAVAssetResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    private let fragmentsScheme = "fragmentsm3u8"
    private let subtitlesScheme = "subtitlesm3u8"
    private let extInfPrefix = "#EXTINF:"
    private var m3u8: URL
    private var subtitles: [MovieSubtitles]
    private(set) var m3u8String: String?
    private(set) var playlistDuration: Double = 0

    init(m3u8: URL, subtitles: [MovieSubtitles]) {
        self.m3u8 = m3u8
        self.subtitles = subtitles
        super.init()
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let scheme = loadingRequest.request.url?.scheme else { return false }
        switch scheme {
        case "mainm3u8":
            return handleMainRequest(loadingRequest)
        case fragmentsScheme:
            guard let data = m3u8String?.data(using: .utf8) else { return false }
            loadingRequest.dataRequest?.respond(with: data)
            loadingRequest.finishLoading()
            return true
        case subtitlesScheme:
            return handleSubtitles(loadingRequest)
        default:
            return false
        }
    }

    func handleMainRequest(_ loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        let task = URLSession.shared.dataTask(with: m3u8) { [weak self] data, _, error in
            if let error {
                loadingRequest.finishLoading(with: error)
                return
            }
            guard let data else {
                loadingRequest.finishLoading(with: nil)
                return
            }
            self?.processPlaylistWithData(data)
            self?.finishRequestWithMainPlaylist(loadingRequest)
        }
        task.resume()
        return true
    }

    func handleSubtitles(_ loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let url = loadingRequest.request.url,
              let subtitle = subtitles.first(where: { $0.lang == url.host() }),
              let data = getSubtitlem3u8WithDuration(playlistDuration, subtitle: subtitle).data(using: .utf8)
        else { return false }
        loadingRequest.dataRequest?.respond(with: data)
        loadingRequest.finishLoading()
        return true
    }

    func getMainm3u8() -> String {
        var playlist = "#EXTM3U\n"
        for subtitle in subtitles {
            playlist += "#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"subs\",NAME=\"\(subtitle.name)\",DEFAULT=NO,AUTOSELECT=NO,FORCED=NO,URI=\"subtitlesm3u8://\(subtitle.lang)\",LANGUAGE=\"\(subtitle.lang.replacingOccurrences(of: "ua", with: "uk"))\"\n"
        }
        playlist += subtitles.isEmpty
            ? "#EXT-X-STREAM-INF:BANDWIDTH=1280000,CLOSED-CAPTIONS=NONE\nfragmentsm3u8://foo"
            : "#EXT-X-STREAM-INF:BANDWIDTH=1280000,SUBTITLES=\"subs\",CLOSED-CAPTIONS=NONE\nfragmentsm3u8://foo"
        return playlist
    }

    func getSubtitlem3u8WithDuration(_ duration: Double, subtitle: MovieSubtitles) -> String {
        let durationString = String(format: "%.3f", duration)
        return "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-MEDIA-SEQUENCE:1\n#EXT-X-PLAYLIST-TYPE:VOD\n#EXT-X-ALLOW-CACHE:NO\n#EXT-X-TARGETDURATION:\(Int(duration))\n#EXTINF:\(durationString), no desc\n\(subtitle.link)\n#EXT-X-ENDLIST"
    }

    /// Stores the media playlist with every segment made absolute (manifest URL without query,
    /// minus its last path component, plus the segment line) and sums the `#EXTINF` durations.
    func processPlaylistWithData(_ data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        let lines = string.components(separatedBy: "\n")
        var result: [String] = []
        playlistDuration = 0
        var index = 0
        while index < lines.count {
            let line = lines[index]
            result.append(line)
            guard line.hasPrefix(extInfPrefix) else {
                index += 1
                continue
            }
            guard index + 1 < lines.count else { break }
            let segment = lines[index + 1]
            // "#EXTINF:10.000," -> "10.000"; a title after the comma makes it unparsable (counted as 0).
            playlistDuration += Double(line.components(separatedBy: ":")[1].dropLast()) ?? 0
            var absoluteSegment = segment
            if var components = URLComponents(string: m3u8.absoluteString) {
                components.query = nil
                if let url = components.url {
                    absoluteSegment = url.deletingLastPathComponent().absoluteString + segment
                }
            }
            result.append(absoluteSegment)
            index += 2
        }
        m3u8String = result.joined(separator: "\n")
    }

    func finishRequestWithMainPlaylist(_ loadingRequest: AVAssetResourceLoadingRequest) {
        guard let data = getMainm3u8().data(using: .utf8) else { return }
        loadingRequest.dataRequest?.respond(with: data)
        loadingRequest.finishLoading()
    }
}
