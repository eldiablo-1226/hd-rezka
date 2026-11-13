import SwiftUI
import AVKit
import MediaPlayer

struct PlayerViewComponent: UIViewControllerRepresentable {
    var url: String
    var subtitles: [MovieSubtitles]
    var name: String
    var voiceActing: String
    var poster: String
    var progressKey: String?
    var autoplay: AutoplayContext?
    var localFileURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(progressKey: progressKey, name: name, subtitle: voiceActing, poster: poster, autoplay: autoplay)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player: AVPlayer
        if let localFileURL {
            player = AVPlayer(playerItem: AVPlayerItem(url: localFileURL))
            player.preventsDisplaySleepDuringVideoPlayback = true
        } else {
            player = CustomAVPlayer(m3u8: URL(string: "\(url):hls:manifest.m3u8")!, subtitles: subtitles)!
        }
        let controller = AVPlayerViewController()
        controller.player = player

        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = name as NSString
        titleItem.extendedLanguageTag = "und"
        let subtitleItem = AVMutableMetadataItem()
        subtitleItem.identifier = .iTunesMetadataTrackSubTitle
        subtitleItem.value = voiceActing as NSString
        let artworkItem = AVMutableMetadataItem()
        setupArtworkMetadata(artworkItem)
        player.currentItem?.externalMetadata = [titleItem, subtitleItem, artworkItem]
        player.currentItem?.isAudioSpatializationAllowed = false

        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = false
        controller.exitsFullScreenWhenPlaybackEnds = autoplay?.followingEpisode == nil

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error initializing audio: \(error)")
        }
        context.coordinator.attach(player: player, controller: controller)
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.persistAndDetach()
    }

    /// Progress key of a series episode: `movieId|translatorId|seasonId|episodeId` (the callers' `CoverData.progressKey` uses the same format).
    nonisolated static func progressKey(movieId: String, translatorId: String, seasonId: String, episodeId: String) -> String {
        movieId + "|" + translatorId + "|" + seasonId + "|" + episodeId
    }

    /// The saved time to seek to: only past 5 s and, when the duration is finite, more than 10 s before the end (0x100080c50).
    nonisolated static func restorePosition(saved: Double?, duration: Double) -> Double? {
        guard let saved, saved > 5, !duration.isFinite || duration - 10 > saved else { return nil }
        return saved
    }

    /// What the player stores at `seconds`: 0 where it wouldn't resume from (the first 5 s, the last 10 s).
    /// improvement: a title closed at its end stored its whole length, and the page and «Досмотреть» offered to resume
    /// there («с 1:39:55») while the player started from 0:00.
    nonisolated static func positionToSave(_ seconds: Double, duration: Double) -> Double {
        restorePosition(saved: seconds, duration: duration) ?? 0
    }

    /// Fills `item` with the poster (JPEG data, tagged PNG as in the original) once it is downloaded.
    private func setupArtworkMetadata(_ item: AVMutableMetadataItem) {
        guard let url = URL(string: poster) else { return }
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                print("Error downloading image: \(error)")
                return
            }
            guard let data, let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 1) else { return }
            DispatchQueue.main.async {
                item.identifier = .commonIdentifierArtwork
                item.value = jpeg as NSData
                item.dataType = kCMMetadataBaseDataType_PNG as String
                item.extendedLanguageTag = "und"
            }
        }.resume()
    }

    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        private var progressKey: String?
        private let movieName: String
        private var subtitle: String
        private let posterUrl: String
        private var autoplay: AutoplayContext?
        private var player: AVPlayer?
        private weak var controller: AVPlayerViewController?
        private var timeObserver: Any?
        private var statusObservation: NSKeyValueObservation?
        private var rateObservation: NSKeyValueObservation?
        private var endObserver: NSObjectProtocol?
        private var backgroundObserver: NSObjectProtocol?
        private var foregroundObserver: NSObjectProtocol?
        private var didRestore = false
        private var isAdvancing = false
        private var isPictureInPictureActive = false
        private var artworkImage: UIImage?
        private var manualNowPlayingActive = false

        init(progressKey: String?, name: String, subtitle: String, poster: String, autoplay: AutoplayContext?) {
            self.progressKey = progressKey
            movieName = name
            self.subtitle = subtitle
            posterUrl = poster
            self.autoplay = autoplay
            super.init()
        }

        deinit {
            persistAndDetach()
        }

        func attach(player: AVPlayer, controller: AVPlayerViewController) {
            self.player = player
            self.controller = controller
            controller.delegate = self
            attachItemObservers(item: player.currentItem)
            installTimeObserver()
            installLifecycleObservers()
            loadArtwork()
            beginManualNowPlaying()
        }

        func persistAndDetach() {
            if let progressKey, let player, didRestore {
                let seconds = player.currentTime().seconds
                if seconds.isFinite, seconds > 0 {
                    let duration = player.currentItem?.duration.seconds ?? .nan
                    PlaybackProgressStore.shared.save(time: PlayerViewComponent.positionToSave(seconds, duration: duration),
                                                      forKey: progressKey)
                }
            }
            if let timeObserver {
                player?.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            statusObservation?.invalidate()
            statusObservation = nil
            rateObservation?.invalidate()
            rateObservation = nil
            for observer in [endObserver, backgroundObserver, foregroundObserver].compactMap({ $0 }) {
                NotificationCenter.default.removeObserver(observer)
            }
            endObserver = nil
            backgroundObserver = nil
            foregroundObserver = nil
            endManualNowPlaying()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            player = nil
            controller = nil
        }

        // MARK: AVPlayerViewControllerDelegate

        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            isPictureInPictureActive = true
        }

        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            isPictureInPictureActive = false
        }

        // MARK: Progress

        /// Restores the saved position once the item is ready (only past 5 s and more than 10 s before the end)
        /// and watches for the end of playback.
        private func attachItemObservers(item: AVPlayerItem?) {
            statusObservation?.invalidate()
            statusObservation = nil
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
            guard let item else { return }
            if let progressKey {
                didRestore = false
                statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                    // The status may arrive on an AVFoundation queue; viewContext and didRestore belong to main.
                    // An item replaced by autoplay in the meantime is skipped.
                    DispatchQueue.main.async {
                        guard let self, !self.didRestore, item.status == .readyToPlay, item === self.player?.currentItem else { return }
                        if let saved = PlayerViewComponent.restorePosition(saved: PlaybackProgressStore.shared.time(forKey: progressKey),
                                                                           duration: item.duration.seconds) {
                            self.player?.seek(to: CMTime(seconds: saved, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                        }
                        self.didRestore = true
                    }
                }
            } else {
                didRestore = true
            }
            endObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name("AVPlayerItemDidPlayToEndTimeNotification"), object: item, queue: .main) { [weak self] _ in
                self?.handlePlaybackEnded()
            }
        }

        private func installTimeObserver() {
            guard let player else { return }
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 600), queue: .main) { [weak self] time in
                guard let self else { return }
                if self.manualNowPlayingActive {
                    self.updateNowPlayingElapsedTime()
                }
                guard self.didRestore, let progressKey = self.progressKey else { return }
                let seconds = time.seconds
                if seconds.isFinite, seconds > 0 {
                    let duration = self.player?.currentItem?.duration.seconds ?? .nan
                    PlaybackProgressStore.shared.save(time: PlayerViewComponent.positionToSave(seconds, duration: duration),
                                                      forKey: progressKey)
                }
            }
        }

        /// Detaches the player from the controller in background so audio keeps playing (unless PiP/AirPlay).
        private func installLifecycleObservers() {
            if backgroundObserver == nil {
                backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                    guard let self, let controller = self.controller else { return }
                    if !self.isPictureInPictureActive, !(self.player?.isExternalPlaybackActive ?? false) {
                        controller.player = nil
                    }
                }
            }
            if foregroundObserver == nil {
                foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                    guard let self, let controller = self.controller, controller.player == nil else { return }
                    controller.player = self.player
                }
            }
        }

        // MARK: Now Playing

        private func loadArtwork() {
            guard let url = URL(string: posterUrl) else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self?.artworkImage = image
                    self?.updateNowPlayingInfo()
                }
            }.resume()
        }

        private func beginManualNowPlaying() {
            guard !manualNowPlayingActive else { return }
            manualNowPlayingActive = true
            observeRate()
            updateNowPlayingInfo()

            let center = MPRemoteCommandCenter.shared()
            for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                            center.skipForwardCommand, center.skipBackwardCommand, center.changePlaybackPositionCommand] {
                command.isEnabled = true
            }
            center.playCommand.addTarget { [weak self] _ in
                guard let self, let player = self.player else { return .commandFailed }
                try? AVAudioSession.sharedInstance().setActive(true)
                player.play()
                self.updateNowPlayingElapsedTime()
                return .success
            }
            center.pauseCommand.addTarget { [weak self] _ in
                guard let self, let player = self.player else { return .commandFailed }
                player.pause()
                self.updateNowPlayingElapsedTime()
                return .success
            }
            center.togglePlayPauseCommand.addTarget { [weak self] _ in
                guard let self, let player = self.player else { return .commandFailed }
                if player.rate == 0 {
                    try? AVAudioSession.sharedInstance().setActive(true)
                    player.play()
                } else {
                    player.pause()
                }
                self.updateNowPlayingElapsedTime()
                return .success
            }
            center.skipForwardCommand.preferredIntervals = [15]
            center.skipForwardCommand.addTarget { [weak self] _ in
                self?.skip(by: +) ?? .commandFailed
            }
            center.skipBackwardCommand.preferredIntervals = [15]
            center.skipBackwardCommand.addTarget { [weak self] _ in
                self?.skip(by: -) ?? .commandFailed
            }
            center.changePlaybackPositionCommand.addTarget { [weak self] event in
                guard let self, let player = self.player,
                      let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
                player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 600)) { [weak self] _ in
                    self?.updateNowPlayingElapsedTime()
                }
                return .success
            }
        }

        /// Seeks 15 s forward (`+`) or back (`-`); the binary shares one closure body for both commands.
        private func skip(by step: (CMTime, CMTime) -> CMTime) -> MPRemoteCommandHandlerStatus {
            guard let player else { return .commandFailed }
            player.seek(to: step(player.currentTime(), CMTime(seconds: 15, preferredTimescale: 600))) { [weak self] _ in
                self?.updateNowPlayingElapsedTime()
            }
            return .success
        }

        private func observeRate() {
            rateObservation?.invalidate()
            rateObservation = player?.observe(\.rate, options: [.new]) { [weak self] _, _ in
                self?.updateNowPlayingElapsedTime()
            }
        }

        private func endManualNowPlaying() {
            guard manualNowPlayingActive else { return }
            manualNowPlayingActive = false
            rateObservation?.invalidate()
            rateObservation = nil
            let center = MPRemoteCommandCenter.shared()
            for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                            center.skipForwardCommand, center.skipBackwardCommand, center.changePlaybackPositionCommand] {
                command.removeTarget(nil)
            }
        }

        private func updateNowPlayingInfo() {
            var info: [String: Any] = [:]
            info[MPMediaItemPropertyTitle] = movieName
            if !subtitle.isEmpty {
                info[MPMediaItemPropertyArtist] = subtitle
            }
            setPlaybackTimes(in: &info)
            if let artworkImage {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }

        private func updateNowPlayingElapsedTime() {
            guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
                updateNowPlayingInfo()
                return
            }
            setPlaybackTimes(in: &info)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }

        private func setPlaybackTimes(in info: inout [String: Any]) {
            if let duration = player?.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
                info[MPMediaItemPropertyPlaybackDuration] = duration
            }
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime().seconds ?? 0
            info[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0
        }

        // MARK: Autoplay

        private func handlePlaybackEnded() {
            guard let autoplay, let nextEpisode = autoplay.followingEpisode, !isAdvancing else { return }
            isAdvancing = true
            if let progressKey {
                PlaybackProgressStore.shared.save(time: 0, forKey: progressKey)
            }
            Task { [weak self] in
                guard let self else { return }
                do {
                    let video = try await MovieDetailsService().getMovieVideo(voiceActing: autoplay.voiceActing, season: autoplay.season,
                                                                              episode: nextEpisode, id: autoplay.movieId)
                    guard let quality = video.getAvailableQualities().preferred(name: autoplay.qualityName) else {
                        await MainActor.run { self.isAdvancing = false }
                        return
                    }
                    if UserDefaults.standard.bool(forKey: "isLoggedIn"), UserDefaults.standard.bool(forKey: "saveHistory") {
                        _ = try? await AccountService().saveWatchingState(voiceActing: autoplay.voiceActing, season: autoplay.season, episode: nextEpisode)
                    }
                    let nextKey = PlayerViewComponent.progressKey(movieId: autoplay.movieId, translatorId: autoplay.voiceActing.translatorId,
                                                                  seasonId: autoplay.season.id, episodeId: nextEpisode.id)
                    let next = AutoplayContext(movieId: autoplay.movieId, voiceActing: autoplay.voiceActing, season: autoplay.season,
                                               currentEpisode: nextEpisode, qualityName: quality.name)
                    await MainActor.run {
                        self.swapToNext(url: quality.url, subtitles: video.subtitles ?? [], episode: nextEpisode,
                                        voiceActing: autoplay.voiceActing, progressKey: nextKey, autoplay: next)
                    }
                } catch {
                    print("Autoplay next episode failed: \(error)")
                    await MainActor.run { self.isAdvancing = false }
                }
            }
        }

        private func swapToNext(url: String, subtitles: [MovieSubtitles], episode: MovieEpisode, voiceActing: MovieVoiceActing, progressKey: String, autoplay: AutoplayContext) {
            guard let controller,
                  let newPlayer = CustomAVPlayer(m3u8: URL(string: "\(url):hls:manifest.m3u8")!, subtitles: subtitles) else {
                isAdvancing = false
                return
            }
            if let timeObserver {
                player?.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            player?.pause()
            player?.replaceCurrentItem(with: nil)

            let newSubtitle = voiceActing.name.isEmpty ? episode.name : voiceActing.name + ", " + episode.name
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = .commonIdentifierTitle
            titleItem.value = movieName as NSString
            titleItem.extendedLanguageTag = "und"
            let subtitleItem = AVMutableMetadataItem()
            subtitleItem.identifier = .iTunesMetadataTrackSubTitle
            subtitleItem.value = newSubtitle as NSString
            var metadata: [AVMetadataItem] = [titleItem, subtitleItem]
            // The original looks for the artwork only after clearing the old item, so this never finds it.
            if let artwork = player?.currentItem?.externalMetadata.first(where: { $0.identifier == .commonIdentifierArtwork }) {
                metadata.append(artwork)
            }
            newPlayer.currentItem?.externalMetadata = metadata
            newPlayer.currentItem?.isAudioSpatializationAllowed = false

            controller.exitsFullScreenWhenPlaybackEnds = autoplay.followingEpisode == nil
            controller.player = newPlayer
            self.progressKey = progressKey
            self.autoplay = autoplay
            player = newPlayer
            subtitle = newSubtitle
            attachItemObservers(item: newPlayer.currentItem)
            installTimeObserver()
            if manualNowPlayingActive {
                observeRate()
                updateNowPlayingInfo()
            }
            newPlayer.play()
            isAdvancing = false
        }
    }
}

extension AutoplayContext {
    /// The episode after `currentEpisode` in its season, if any.
    var followingEpisode: MovieEpisode? {
        guard let index = season.episodes.firstIndex(of: currentEpisode), index + 1 < season.episodes.count else { return nil }
        return season.episodes[index + 1]
    }
}

/// improvement: the «Безопасная зона» switch (Профиль → Плеер): on, the video keeps clear of the notch or Dynamic Island
/// behind black bars, as the switch's picture shows; off, it fills the screen. 1.6.0 stored the switch and read it nowhere.
struct PlayerSafeArea: ViewModifier {
    @AppStorage("hideNotch") private var hidesNotch = false

    func body(content: Content) -> some View {
        content
            .ignoresSafeArea(.all, edges: hidesNotch ? .vertical : .all)
            .background(Color.black.ignoresSafeArea())
    }
}
