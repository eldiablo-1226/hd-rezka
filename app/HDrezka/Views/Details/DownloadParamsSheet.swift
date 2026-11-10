import SwiftUI
import UIKit
import AlertKit

/// Download sheet: season / episode / voice acting / quality pickers, the download and copy-link buttons,
/// and this title's downloads (body 0x10002af1c).
struct DownloadParamsSheet: View {
    var id: String
    var name: String
    var poster: String
    var voiceActing: [MovieVoiceActing]?
    @State var movieVideo: [Quality] = []
    @State var video: String = ""
    @State var seasons: [MovieSeason]? = nil
    @State var selectedActing: MovieVoiceActing = MovieVoiceActing(id: "", name: "", translatorId: "", isCamrip: "", isAds: "", isDirector: "", isSelected: false, isPremium: false, url: nil)
    @State var selectedSeason: MovieSeason = MovieSeason(id: "", name: "", episodes: [], isSelected: false, url: nil)
    @State var selectedEpisode: MovieEpisode = MovieEpisode(id: "", name: "", isSelected: false, url: nil)
    @EnvironmentObject var detailService: MovieDetailsService
    @EnvironmentObject var downloadManager: DownloadManager
    @AppStorage("downloadDestination") var downloadDestination: DownloadDestination = .app

    var body: some View {
        VStack {
            Form {
                Section {
                    if seasons != nil {
                        Picker("season", selection: $selectedSeason) {
                            ForEach(seasons!, id: \.name) { season in
                                Text(season.name).tag(season)
                            }
                        }
                        Picker("episode", selection: $selectedEpisode) {
                            ForEach(selectedSeason.episodes, id: \.self) { episode in
                                Text(episode.name).tag(episode)
                            }
                        }
                    }
                    Picker("voice acting", selection: $selectedActing) {
                        ForEach(voiceActing!, id: \.name) { acting in
                            Text(acting.name).tag(acting)
                        }
                    }
                    Picker("quality", selection: $video) {
                        ForEach(movieVideo, id: \.name) { quality in
                            Text(quality.name).tag(quality.url)
                        }
                    }
                }
                Section {
                    Button {
                        // closure #1 in closure #2 (0x10002c9ec); DownloadManager.download is inlined there.
                        let quality = Self.qualityName(of: video, in: movieVideo)
                        let subtitle = Self.downloadSubtitle(seasons: seasons, season: selectedSeason, episode: selectedEpisode, acting: selectedActing)
                        downloadManager.download(title: name, subtitle: subtitle, poster: poster, quality: quality,
                                                 url: URL(string: video)!, destination: downloadDestination)
                        AlertKitAPI.present(title: String(localized: "Download started"), icon: .done, style: .iOS17AppleMusic, haptic: .success)
                    } label: {
                        Label("Download", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        UIPasteboard.general.string = video
                        AlertKitAPI.present(title: String(localized: "key_copied"), icon: .done, style: .iOS17AppleMusic, haptic: .success)
                    } label: {
                        Label("key_copy", systemImage: "doc.on.doc")
                    }
                }
                List {
                    ForEach(downloadManager.downloads.filter { $0.title == name }) { download in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(download.displayName)
                                .font(.caption)
                                .lineLimit(1)
                            if download.state == .completed {
                                Label("key_downloaded_status", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(Color.green)
                            } else {
                                ProgressView(value: download.fractionCompleted)
                                if download.receivedBytes > 0 {
                                    Text(downloadByteProgress(download))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        let downloads = downloadManager.downloads.filter { $0.title == name }
                        for index in indexSet {
                            downloadManager.delete(downloads[index])
                        }
                    }
                }
            }
        }
        .onAppear {
            selectedActing = voiceActing![voiceActing!.firstIndex(where: { $0.isSelected }) ?? 0]
            if seasons != nil {
                if let season = seasons!.first(where: { $0.isSelected }) {
                    selectedSeason = season
                }
            }
            downloadManager.requestAuthorization()
        }
        .onChange(of: selectedActing) { _ in
            Task { @MainActor in
                seasons = try await detailService.getSeriesSeasons(movieId: id, voiceActing: selectedActing)
            }
            Task { @MainActor in
                let movie: MovieVideo
                if seasons != nil {
                    movie = try await detailService.getMovieVideo(voiceActing: selectedActing, season: selectedSeason, episode: selectedEpisode, id: id)
                } else {
                    movie = try await detailService.getMovieVideo(voiceActing: selectedActing, season: nil, episode: nil, id: id)
                }
                movieVideo = movie.getAvailableQualities()
                video = movieVideo.last!.url
            }
        }
        .onChange(of: selectedSeason) { _ in
            if let episode = selectedSeason.episodes.first(where: { $0.isSelected }) {
                selectedEpisode = episode
            }
            loadQualities()
        }
        .onChange(of: selectedEpisode) { _ in
            loadQualities()
        }
    }

    /// Body of the Tasks in closures #4 and #5 (the binary merged their resume partials, 0x10002fe0c).
    private func loadQualities() {
        Task { @MainActor in
            let movie = try await detailService.getMovieVideo(voiceActing: selectedActing, season: selectedSeason, episode: selectedEpisode, id: id)
            movieVideo = movie.getAvailableQualities()
            video = movieVideo.last!.url
        }
    }

    /// "<received>" or "<received> / <total>" (0x100030ce8; private in the binary, internal for tests).
    func downloadByteProgress(_ download: Download) -> String {
        var progress = ByteCountFormatter.string(fromByteCount: download.receivedBytes, countStyle: .file)
        if download.totalBytes > 0 {
            progress += " / " + ByteCountFormatter.string(fromByteCount: download.totalBytes, countStyle: .file)
        }
        return progress
    }
}

// Built inline in the download button's action (0x10002c9ec); kept apart so they can be tested.
extension DownloadParamsSheet {
    /// Name of the quality whose link is selected, "" when none matches.
    static func qualityName(of video: String, in qualities: [Quality]) -> String {
        qualities.first { $0.url == video }?.name ?? ""
    }

    /// Series: "S<season number> E<episode number> [<voice acting>]"; film: the voice acting name.
    static func downloadSubtitle(seasons: [MovieSeason]?, season: MovieSeason, episode: MovieEpisode, acting: MovieVoiceActing) -> String {
        guard seasons != nil else { return acting.name }
        return "S" + season.name.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
            + " E" + episode.name.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
            + " [" + acting.name + "]"
    }
}
