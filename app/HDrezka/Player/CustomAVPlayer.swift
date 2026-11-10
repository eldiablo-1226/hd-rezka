import AVFoundation

/// AVPlayer whose asset is served by `CustomAVAssetResourceLoaderDelegate` so that external
/// subtitles show up as a native HLS subtitle group.
class CustomAVPlayer: AVPlayer {
    private var loaderQueue = DispatchQueue(label: "resourceLoader")
    private var delegate: CustomAVAssetResourceLoaderDelegate

    init?(m3u8: URL, subtitles: [MovieSubtitles]) {
        delegate = CustomAVAssetResourceLoaderDelegate(m3u8: m3u8, subtitles: subtitles)
        super.init()
        guard let url = replaceURLWithScheme("mainm3u8", url: m3u8) else { return nil }
        let asset = AVURLAsset(url: url, options: nil)
        asset.resourceLoader.setDelegate(delegate, queue: loaderQueue)
        replaceCurrentItem(with: AVPlayerItem(asset: asset))
        preventsDisplaySleepDuringVideoPlayback = true
    }

    /// "https://host/x.m3u8" -> "<scheme>://host/x.m3u8"; nil when the URL has no ":".
    func replaceURLWithScheme(_ scheme: String, url: URL) -> URL? {
        let urlString = url.absoluteString
        guard let colon = urlString.firstIndex(of: ":") else { return nil }
        return URL(string: scheme + urlString[colon...])
    }
}
