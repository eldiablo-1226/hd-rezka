import SwiftUI

/// Quality list (plus the subtitle picker for Infuse); starts playback in the app player or in Infuse
/// (body 0x10001d924, play 0x10001f7c4…0x1000206c4).
struct QualitySelectionSheet: View {
    @AppStorage("useInfuse") var useInfuse: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("autoplayNextEpisode") var autoplayNextEpisode: Bool = false
    @AppStorage("preferredQuality") var preferredQuality: PlayerQualityPreference = .ask
    @AppStorage("saveHistory") var saveHistory: Bool = true
    @Environment(\.openURL) var openURL
    @Environment(\.colorScheme) var colorScheme
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

    var body: some View {
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
                Section {
                    ForEach(movieVideo, id: \.name) { quality in
                        Button {
                            video = quality.url
                            play(quality: quality)
                        } label: {
                            Text(quality.name)
                                .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                        }
                    }
                }
            }
            .navigationBarTitle("key_select_quality", displayMode: .inline)
        } else {
            ViewThatFits {
                ProgressView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGray6))
            .navigationBarTitle("key_select_quality", displayMode: .inline)
            .onAppear {
                // closure #3 (0x10001ede0 / 0x10001f208).
                Task { @MainActor in
                    let movie = try await detailService.getMovieVideo(voiceActing: selectedActing, season: selectedSeason,
                                                                      episode: selectedEpisode, id: id)
                    movieVideo = movie.getAvailableQualities()
                    proceedSubtitles = movie.subtitles ?? []
                    if !proceedSubtitles.isEmpty {
                        selectedSubtitle = proceedSubtitles[0]
                    }
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
        }
    }

    private func play(quality: Quality) {
        Task { @MainActor in
            // A failed history save throws out of the Task and skips playback, as in the binary.
            if isLoggedIn && saveHistory {
                _ = try await AccountService().saveWatchingState(voiceActing: selectedActing, season: selectedSeason, episode: selectedEpisode)
            }
            if useInfuse {
                openURL(URL(string: Self.infuseURL(video: video, subtitle: selectedSubtitle))!)
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
