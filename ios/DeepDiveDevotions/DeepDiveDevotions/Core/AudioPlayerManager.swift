import Foundation
import AVFoundation
import Combine

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
