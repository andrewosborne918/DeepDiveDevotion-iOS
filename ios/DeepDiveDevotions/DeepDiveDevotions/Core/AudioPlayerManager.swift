import Foundation
import AVFoundation
import Combine
import MediaPlayer

@MainActor
final class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()

    @Published var currentEpisode: Episode?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 1
    @Published var recentlyPlayed: [Episode] = []
    @Published var playbackRate: Float
    @Published var finishedEpisodeId: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: Any?
    private var resumePositions: [String: Double] = [:]
    private let speedKey          = "player_playback_rate"
    private let recentlyPlayedKey  = "player_recently_played"

    private init() {
        let saved = UserDefaults.standard.float(forKey: speedKey)
        self.playbackRate = (saved > 0 ? saved : 1.0)
        // Restore persisted recently-played list
        if let data = UserDefaults.standard.data(forKey: recentlyPlayedKey),
           let episodes = try? JSONDecoder().decode([Episode].self, from: data) {
            self.recentlyPlayed = episodes
        }
        setupAudioSession()
        setupRemoteControls()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Audio session setup error: \(error)")
        }
    }

    private func setupRemoteControls() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.toggle(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.toggle(); return .success
        }
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skip(30); return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skip(-15); return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let episode = currentEpisode else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: "Deep Dive Devotions",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackRate) : 0.0,
        ]
        if let ref = episode.scriptureReference {
            info[MPMediaItemPropertyAlbumTitle] = ref
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Load thumbnail asynchronously
        if let thumbURL = episode.thumbnailURL {
            Task.detached {
                if let data = try? Data(contentsOf: thumbURL),
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    updated[MPMediaItemPropertyArtwork] = artwork
                    await MainActor.run {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
                    }
                }
            }
        }
    }

    func play(episode: Episode) {
        guard let url = episode.audioURL else { return }

        markRecentlyPlayed(episode)

        if currentEpisode?.id != episode.id {
            stopObserver()
            player = AVPlayer(url: url)
            currentEpisode = episode
            addObserver()

            if let saved = resumePositions[episode.id], saved > 1 {
                seek(to: saved)
            }
        }

        player?.play()
        player?.rate = playbackRate
        isPlaying = true
        updateNowPlaying()
    }

    func toggle() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            player.rate = playbackRate
            isPlaying = true
        }
        updateNowPlaying()
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
        if let id = currentEpisode?.id {
            resumePositions[id] = seconds
        }
    }

    func skip(_ delta: Double) {
        let next = max(0, min(currentTime + delta, duration))
        seek(to: next)
    }

    private func addObserver() {
        guard let player else { return }

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] _ in
            guard let self, let item = player.currentItem else { return }
            self.currentTime = item.currentTime().seconds
            self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 1
            if let id = self.currentEpisode?.id {
                self.resumePositions[id] = self.currentTime
            }
            self.updateNowPlaying()
        }

        // Notify when episode plays to end
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.finishedEpisodeId = self.currentEpisode?.id
                self.isPlaying = false
            }
        }
    }

    private func stopObserver() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    func savedPosition(for episode: Episode) -> Double {
        resumePositions[episode.id] ?? 0
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        UserDefaults.standard.set(rate, forKey: speedKey)
        if isPlaying {
            player?.rate = rate
        }
    }

    private func markRecentlyPlayed(_ episode: Episode) {
        recentlyPlayed.removeAll { $0.id == episode.id }
        recentlyPlayed.insert(episode, at: 0)
        if recentlyPlayed.count > 20 {
            recentlyPlayed = Array(recentlyPlayed.prefix(20))
        }
        // Persist
        if let data = try? JSONEncoder().encode(recentlyPlayed) {
            UserDefaults.standard.set(data, forKey: recentlyPlayedKey)
        }
    }
}
