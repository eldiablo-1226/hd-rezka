import SwiftUI

/// Quality list (plus the subtitle picker for Infuse); starts playback in the app player or in Infuse
/// (body 0x10001d924, play 0x10001f7c4…0x1000206c4).
struct QualitySelectionSheet: View {
    @AppStorage("useInfuse") var useInfuse: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("autoplayNextEpisode") var autoplayNextEpisode: Bool = true
    @AppStorage("preferredQuality") var preferredQuality: PlayerQualityPreference = .ask
    @AppStorage("saveHistory") var saveHistory: Bool = true
    /// improvement: the quality picked last time gets a checkmark.
    @AppStorage("lastQualityName") var lastQualityName: String = ""
    @Environment(\.openURL) var openURL
    @EnvironmentObject var detailService: MovieDetailsService
    var id: String
    var selectedActing: MovieVoiceActing
    var selectedSeason: MovieSeason?
    var selectedEpisode: MovieEpisode?
    @Binding var video: String
    var dismiss: DismissAction
    @Binding var coverData: CoverData?
    @State var selectedSubtitle: MovieSubtitles = MovieSubtitles(name: "", link: "", lang: "")
    @State var qualitySelectionPresent: Bool = false
    @State var proceedSubtitles: [MovieSubtitles] = []
    @State var movieVideo: [Quality] = []
    @State var didAutoPlay: Bool = false
    /// improvement: the links did not load; 1.6.0 kept spinning (the error was dropped inside the Task).
    @State var loadFailure: PageLoadFailure? = nil
    /// improvement: the sheet was swiped away (or popped) before the links arrived; nothing may start playing then.
    @State var isGone: Bool = false
    /// improvement: the tapped quality becomes «Предпочтительное качество», so «Смотреть» stops asking.
    @State var remembersQuality: Bool = false

    // A ZStack around the states, so switching from the spinner to the list is not a disappearance.
    var body: some View {
        ZStack { content }
            .onDisappear { isGone = true }
    }

    @ViewBuilder
    private var content: some View {
        if qualitySelectionPresent {
            Form {
                // The app player lists every subtitle itself; only Infuse needs one picked here.
                if !proceedSubtitles.isEmpty && useInfuse {
                    Section {
                        Picker("key_subtitle_language", selection: $selectedSubtitle) {
                            ForEach(proceedSubtitles, id: \.name) { subtitle in
                                Text(subtitle.name.isEmpty ? String(localized: "key_no_subtitles") : subtitle.name)
                                    .tag(subtitle)
                            }
                        }
                    }
                }
                // improvement: best first, last time's choice checked, and what plays named above the list.
                Section {
                    ForEach(movieVideo.reversed(), id: \.name) { quality in
                        Button {
                            video = quality.url
                            play(quality: quality)
                        } label: {
                            HStack {
                                Text(quality.name)
                                Spacer()
                                if quality.name == lastQualityName {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            // Color.primary: in a button `.primary` is the tint's primary level, i.e. the accent.
                            .foregroundStyle(Color.primary)
                        }
                        .accessibilityValue(Text(quality.name == lastQualityName ? "key_last_used" : ""))
                    }
                } header: {
                    Text(verbatim: whatPlays)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                Section {
                    Toggle("key_remember_quality", isOn: $remembersQuality)
                } footer: {
                    Text("key_remember_quality_hint")
                }
            }
            .navigationBarTitle("key_select_quality", displayMode: .inline)
        } else if let loadFailure {
            // Back to the spinner, whose onAppear loads the links again.
            PageLoadFailedView(failure: loadFailure) { self.loadFailure = nil }
                .navigationBarTitle("key_select_quality", displayMode: .inline)
        } else {
            ViewThatFits {
                ProgressView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The list's own background, so the switch to it doesn't flash (1.6.0: systemGray6 under a grouped list).
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitle("key_watch", displayMode: .inline)
            .onAppear(perform: loadQualities)
        }
    }

    /// closure #3 (0x10001ede0 / 0x10001f208). improvement: a failed request or no playable quality shows the error.
    private func loadQualities() {
        Task { @MainActor in
            do {
                let movie = try await detailService.getMovieVideo(voiceActing: selectedActing, season: selectedSeason,
                                                                  episode: selectedEpisode, id: id)
                movieVideo = movie.getAvailableQualities()
                proceedSubtitles = movie.subtitles ?? []
            } catch {
                loadFailure = PageLoadFailure(error: error, statusCode: nil)
                return
            }
            guard !movieVideo.isEmpty else {
                loadFailure = .other
                return
            }
            if !proceedSubtitles.isEmpty {
                selectedSubtitle = proceedSubtitles[0]
            }
            guard !isGone else { return }
            if preferredQuality != .ask, !useInfuse, !didAutoPlay,
               let quality = movieVideo.preferred(name: preferredQuality.rawValue) {
                didAutoPlay = true
                video = quality.url
                play(quality: quality)
            } else {
                qualitySelectionPresent = true
            }
        }
    }

    /// «Сезон 2, Серия 8 · HDrezka Studio · с 23:14»: the same words as the page's button.
    private var whatPlays: String {
        let choice = PlaybackChoice(acting: selectedActing, season: selectedSeason, episode: selectedEpisode)
        let resume = PlaybackProgressStore.shared.time(forKey: Self.progressKey(id: id, acting: selectedActing,
                                                                                 season: selectedSeason, episode: selectedEpisode))
        return choice.detailLine(resume: resume)
    }

    private func play(quality: Quality) {
        guard !isGone else { return }
        lastQualityName = quality.name
        if remembersQuality, let preference = PlayerQualityPreference(rawValue: quality.name) {
            preferredQuality = preference
        }
        // improvement: the history save runs on its own; 1.6.0 awaited it, so a failure skipped playback and a slow
        // mirror delayed it.
        if isLoggedIn && saveHistory {
            let acting = selectedActing, season = selectedSeason, episode = selectedEpisode
            Task { _ = try? await AccountService().saveWatchingState(voiceActing: acting, season: season, episode: episode) }
        }
        Task { @MainActor in
            if useInfuse {
                // improvement: no force unwrap; the stream link goes in unencoded and may not form a URL.
                if let url = URL(string: Self.infuseURL(video: video, subtitle: selectedSubtitle)) { openURL(url) }
            } else {
                dismiss()
                DispatchQueue.main.async {
                    var autoplay: AutoplayContext? = nil
                    if autoplayNextEpisode, let selectedSeason, let selectedEpisode {
                        autoplay = AutoplayContext(movieId: id, voiceActing: selectedActing, season: selectedSeason,
                                                   currentEpisode: selectedEpisode, qualityName: quality.name)
                    }
                    coverData = CoverData(body: video,
                                          actingName: Self.coverActingName(acting: selectedActing, episode: selectedEpisode),
                                          subtitles: proceedSubtitles,
                                          progressKey: Self.progressKey(id: id, acting: selectedActing, season: selectedSeason, episode: selectedEpisode),
                                          autoplay: autoplay)
                }
            }
        }
    }
}

// The binary builds these strings inline in play(quality:); kept apart so they can be tested.
extension QualitySelectionSheet {
    static let infusePrefix = "infuse://x-callback-url/play?x-success=some-app://x-callback-url/playbackDidFinish&x-error=some-app://x-callback-url/playbackDidFail&url="

    /// The stream URL goes in unencoded; a subtitle link is added only when the picked subtitle has a name.
    static func infuseURL(video: String, subtitle: MovieSubtitles) -> String {
        subtitle.name == "" ? "\(infusePrefix)\(video)" : "\(infusePrefix)\(video)&sub=\(subtitle.link)"
    }

    /// Playback progress key "<id>|<translatorId>|<seasonId>|<episodeId>"; a film uses "0" for season and episode.
    static func progressKey(id: String, acting: MovieVoiceActing, season: MovieSeason?, episode: MovieEpisode?) -> String {
        id + "|" + acting.translatorId + "|" + (season?.id ?? "0") + "|" + (episode?.id ?? "0")
    }

    /// Player subtitle: "<voice acting>, <episode>", or whichever of the two exists (three branches at 0x10002097c).
    static func coverActingName(acting: MovieVoiceActing, episode: MovieEpisode?) -> String {
        if let episode, !acting.name.isEmpty {
            return acting.name + ", " + episode.name
        } else if let episode {
            return episode.name
        }
        return acting.name
    }
}
