import SwiftUI
import UIKit
import AlertKit

/// Download sheet: voice acting / season / episode / quality pickers, the download and copy-link buttons,
/// and this title's downloads (body 0x10002af1c).
/// improvement (Details redesign): the choice runs on the page's PlaybackSelection, starting where the page's
/// «Смотреть» half stands. 1.6.0 reloaded a voice acting's seasons without picking one, so «Сезон» went blank, put the
/// voice acting last although it decides the seasons, and showed premium voice actings without their lock.
struct DownloadParamsSheet: View {
    var id: String
    var name: String
    var poster: String
    var voiceActing: [MovieVoiceActing]?
    /// The page's seasons, which belong to its marked voice acting.
    var seasons: [MovieSeason]? = nil
    /// What the page's «Смотреть» half has chosen; the page's default when nil.
    var initial: PlaybackChoice? = nil
    @StateObject var selection = PlaybackSelection()
    @State var movieVideo: [Quality] = []
    @State var video: String = ""
    // improvement: the links could not be fetched (1.6.0 dropped the error and left the pickers empty).
    @State var qualitiesFailed: Bool = false
    /// improvement: the number of the latest quality request; an older answer arriving later is dropped.
    @State var qualitiesRequest: Int = 0
    @EnvironmentObject var detailService: MovieDetailsService
    @EnvironmentObject var downloadManager: DownloadManager
    @AppStorage("downloadDestination") var downloadDestination: DownloadDestination = .app
    @AppStorage("hasPremium") var hasPremium: String = ""

    var body: some View {
        Form {
            Section {
                if selection.actings.count > 1 {
                    Picker("voice acting", selection: actingBinding) {
                        ForEach(selection.actings, id: \.rowID) { acting in
                            if acting.isPremium && hasPremium.isEmpty {
                                Label(acting.name, systemImage: "lock.fill").tag(acting.rowID)
                            } else {
                                Text(acting.name).tag(acting.rowID)
                            }
                        }
                    }
                }
                if selection.isSeries {
                    Picker("season", selection: seasonBinding) {
                        ForEach(selection.seasons ?? [], id: \.id) { season in
                            Text(EpisodeNames.season(season)).tag(season.id)
                        }
                    }
                    .disabled(selection.isLoadingSeasons)
                    Picker("episode", selection: episodeBinding) {
                        ForEach(selection.season?.episodes ?? [], id: \.id) { episode in
                            Text(EpisodeNames.episode(episode)).tag(episode.id)
                        }
                    }
                    .disabled(selection.isLoadingSeasons)
                }
                if movieVideo.isEmpty && !qualitiesFailed {
                    LabeledContent("quality") { ProgressView() }
                } else {
                    Picker("quality", selection: $video) {
                        ForEach(movieVideo.reversed(), id: \.name) { quality in
                            Text(quality.name).tag(quality.url)
                        }
                    }
                }
            } header: {
                // improvement: the sheet says what it downloads.
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .lineLimit(2)
            } footer: {
                if selection.seasonsFailed {
                    Text("key_seasons_failed")
                } else if qualitiesFailed {
                    VStack(alignment: .leading, spacing: DesignTokens.space8) {
                        Text("key_qualities_not_loaded")
                        Button("key_retry", action: loadQualities)
                            .font(.footnote.bold())
                    }
                }
            }
            Section {
                // improvement: the sheet's one action in the page's primary style, naming what it saves.
                PrimaryActionButton(title: "Download", detail: downloadDetail, systemImage: "arrow.down.circle") {
                    startDownload()
                }
                .disabled(Self.downloadURL(video) == nil || selection.choice == nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section {
                Button {
                    UIPasteboard.general.string = video
                    AlertKitAPI.present(title: String(localized: "key_copied"), icon: .done, style: .iOS17AppleMusic, haptic: .success)
                } label: {
                    Label {
                        Text("key_copy")
                    } icon: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(Color.secondary)
                    }
                }
                // Secondary: grey, not a faded accent (that measured under 3:1 on the row background).
                .tint(.secondary)
                .disabled(video.isEmpty)
            }
            let downloads = downloadManager.downloads.filter { $0.title == name }
            if !downloads.isEmpty {
                Section {
                    ForEach(downloads) { download in
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
                        for index in indexSet {
                            downloadManager.delete(downloads[index])
                        }
                    }
                }
            }
        }
        .onAppear {
            // improvement: no notification prompt on opening; DownloadManager.download asks when the first download starts.
            selection.configure(actings: voiceActing, seasons: seasons,
                                initial: initial ?? PlaybackChoice.default(voiceActing: voiceActing, seasons: seasons)) { [id, detailService] acting in
                try await detailService.getSeriesSeasons(movieId: id, voiceActing: acting)
            }
            if Self.initialActing(in: voiceActing) == nil {
                // improvement: a page whose translators list is empty trapped here; now it says the links are missing.
                qualitiesFailed = true
            } else {
                loadQualities()
            }
        }
        // The whole choice: two voice actings of a film can share a translatorId (and so `id`) and still differ in
        // their links (director's cut, camrip).
        .onChange(of: selection.choice) {
            loadQualities()
        }
    }

    private var actingBinding: Binding<String> {
        Binding(get: { selection.acting?.rowID ?? "" }, set: { rowID in
            if let acting = selection.actings.first(where: { $0.rowID == rowID }) {
                Task { await selection.select(acting) }
            }
        })
    }

    private var seasonBinding: Binding<String> {
        Binding(get: { selection.season?.id ?? "" }, set: { id in
            if let season = selection.seasons?.first(where: { $0.id == id }) { selection.select(season: season) }
        })
    }

    private var episodeBinding: Binding<String> {
        Binding(get: { selection.episode?.id ?? "" }, set: { id in
            if let episode = selection.season?.episodes.first(where: { $0.id == id }) { selection.select(episode: episode) }
        })
    }

    /// «Сезон 2, Серия 8 · HDrezka Studio · 1080p Ultra».
    private var downloadDetail: String? {
        guard let choice = selection.choice else { return nil }
        let quality = Self.qualityName(of: video, in: movieVideo)
        return [choice.detailLine(resume: nil), quality].filter { !$0.isEmpty }.joined(separator: PlaybackChoice.separator)
    }

    // closure #1 in closure #2 (0x10002c9ec); DownloadManager.download is inlined there.
    private func startDownload() {
        // improvement: no link yet means no download (1.6.0 force-unwrapped URL(string: "") and crashed).
        guard let url = Self.downloadURL(video), let choice = selection.choice else { return }
        let quality = Self.qualityName(of: video, in: movieVideo)
        let subtitle = Self.downloadSubtitle(seasons: selection.seasons,
                                             season: choice.season ?? MovieSeason(id: "", name: "", episodes: [], isSelected: false, url: nil),
                                             episode: choice.episode ?? MovieEpisode(id: "", name: "", isSelected: false, url: nil),
                                             acting: choice.acting)
        downloadManager.download(title: name, subtitle: subtitle, poster: poster, quality: quality,
                                 url: url, destination: downloadDestination)
        AlertKitAPI.present(title: String(localized: "Download started"), icon: .done, style: .iOS17AppleMusic, haptic: .success)
    }

    /// Body of the Tasks in closures #4 and #5 (the binary merged their resume partials, 0x10002fe0c), and of the
    /// voice-acting one, which passes no season for a film. improvement: a failed request or no qualities shows an
    /// error with Retry instead of trapping on `movieVideo.last!`; nothing is asked while seasons load.
    private func loadQualities() {
        qualitiesFailed = false
        qualitiesRequest += 1
        let request = qualitiesRequest
        // improvement: no link until the new choice's arrive; Download stayed on and saved the last episode's file under
        // the new episode's name.
        movieVideo = []
        video = ""
        guard let choice = selection.choice else { return }
        Task { @MainActor in
            let qualities: [Quality]
            do {
                let movie = try await detailService.getMovieVideo(voiceActing: choice.acting, season: choice.season,
                                                                  episode: choice.episode, id: id)
                qualities = movie.getAvailableQualities()
            } catch {
                qualities = []
            }
            // A stale answer would show another episode's links, or wipe good ones with an old failure.
            guard request == qualitiesRequest else { return }
            movieVideo = qualities
            video = Self.defaultVideo(in: qualities)
            qualitiesFailed = qualities.isEmpty
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
    /// The preselected link: the last (best) quality, "" when there is none.
    static func defaultVideo(in qualities: [Quality]) -> String {
        qualities.last?.url ?? ""
    }

    /// The link to download, nil while none is selected.
    static func downloadURL(_ video: String) -> URL? {
        video.isEmpty ? nil : URL(string: video)
    }

    /// The voice acting the page marks as selected, else the first; nil for an empty or missing list.
    static func initialActing(in actings: [MovieVoiceActing]?) -> MovieVoiceActing? {
        actings?.first { $0.isSelected } ?? actings?.first
    }

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
