import SwiftUI

/// Downloads list: pause / resume / delete by swipe, finished in-app files play full screen (body 0x100100c14).
struct DownloadsView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @State var playing: Download? = nil

    var body: some View {
        List {
            ForEach(downloadManager.downloads) { download in
                DownloadRow(download: download) {
                    if download.state == .completed, download.destination == .app {
                        playing = download
                    }
                }
                // improvement: no full swipe, so a file that took time and traffic goes only with a tap on «Удалить».
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        downloadManager.delete(download)
                    } label: {
                        Label("key_delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    pauseOrResume(download)
                }
                // improvement: the same actions on a long press, for whoever doesn't know the swipes.
                .contextMenu {
                    pauseOrResume(download)
                    Button(role: .destructive) {
                        downloadManager.delete(download)
                    } label: {
                        Label("key_delete", systemImage: "trash")
                    }
                }
            }
        }
        .overlay(alignment: .center) {
            // improvement: says where downloads appear and how to start one (1.6.0: «Сейчас ничего не загружается»).
            if downloadManager.downloads.isEmpty {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView("No downloads", systemImage: "arrow.down.circle",
                                           description: Text("key_downloads_empty_hint"))
                } else {
                    Text("No downloads").bold()
                }
            }
        }
        .navigationTitle("Downloads")
        .fullScreenCover(item: $playing) { download in
            if let url = downloadManager.localURL(for: download) {
                PlayerViewComponent(url: "", subtitles: [], name: download.title, voiceActing: download.subtitle,
                                    poster: download.poster, progressKey: nil, autoplay: nil, localFileURL: url)
                    .ignoresSafeArea(.all, edges: .all)
                    .persistentSystemOverlays(.hidden)
            }
        }
    }
}

extension DownloadsView {
    @ViewBuilder
    fileprivate func pauseOrResume(_ download: Download) -> some View {
        switch download.state {
        case .downloading:
            Button {
                downloadManager.pause(download)
            } label: {
                Label("key_pause", systemImage: "pause.fill")
            }
            // improvement: grey, not orange, so the accent stays the one hue (DESIGN.md).
            .tint(.gray)
        case .paused, .failed:
            Button {
                downloadManager.resume(download)
            } label: {
                Label("key_resume", systemImage: "play.fill")
            }
            // The fill, not the tint: white on the dark-mode tint is about 3:1.
            .tint(Color("AccentFill"))
        case .completed:
            EmptyView()
        }
    }
}

/// One download: poster, titles, quality and the state line (body 0x100104340, content 0x100102a20).
/// Private in the binary; internal here (stub contract, tests).
struct DownloadRow: View {
    var download: Download
    var onTap: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: onTap) {
            // Beside the poster at accessibility sizes the text column truncated every line: the poster goes above it.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            layout {
                AsyncImage(url: URL(string: download.poster)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().foregroundStyle(.quaternary)
                }
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusPoster, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.title)
                        .font(.headline)
                        .lineLimit(2)
                    if !download.subtitle.isEmpty {
                        Text(download.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    }
                    Text(download.quality)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    statusLine
                }
                if !typeSize.isAccessibilitySize {
                    Spacer()
                    playSymbol
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Stacked, the symbol would get a row of its own under the text: it sits beside the poster instead.
            .overlay(alignment: .topTrailing) {
                if typeSize.isAccessibilitySize { playSymbol }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var playSymbol: some View {
        if download.state == .completed, download.destination == .app {
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(.accent))
        }
    }

    @ViewBuilder var statusLine: some View {
        switch download.state {
        case .downloading:
            VStack(alignment: .leading, spacing: 2) {
                ProgressView(value: download.fractionCompleted)
                Text(progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        case .paused:
            VStack(alignment: .leading, spacing: 2) {
                // improvement: secondary, not orange: a status, not something to tap.
                Label("key_paused", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if download.receivedBytes > 0 {
                    Text(progressText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case .completed:
            Label(byteString(download.totalBytes), systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(Color.green)
        case .failed:
            Label("key_failed", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Color.red)
        }
    }

    /// "<received>" or "<received> / <total>" once the size is known. Inlined into both statusLine closures in the
    /// binary (0x100103d5c, 0x100104028); internal here for tests.
    var progressText: String {
        var text = byteString(download.receivedBytes)
        if download.totalBytes > 0 {
            text += " / " + byteString(download.totalBytes)
        }
        return text
    }

    /// File-style byte count; 0 or less reads "Downloaded" (key_downloaded_status), as in the binary (0x10010421c).
    func byteString(_ bytes: Int64) -> String {
        bytes > 0 ? ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            : String(localized: "key_downloaded_status")
    }
}
