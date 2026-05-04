import Foundation

struct DownloadedEpisode: Codable, Identifiable {
    let id: String
    let title: String
    let scriptureReference: String?
    var fileSizeBytes: Int64
}

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadedEpisodes: [DownloadedEpisode] = []
    @Published var isDownloading: Set<String> = []

    private let storeKey = "downloaded_episodes_v1"

    private init() { load() }

    // MARK: - Public API

    func isDownloaded(_ id: String) -> Bool {
        downloadedEpisodes.contains { $0.id == id }
    }

    func fileURL(for id: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("episode_\(id).m4a")
    }

    func download(_ episode: Episode) async throws {
        guard let audioURL = episode.audioURL else { return }
        isDownloading.insert(episode.id)
        defer { isDownloading.remove(episode.id) }

        let dest = fileURL(for: episode.id)
        let (tempURL, _) = try await URLSession.shared.download(from: audioURL)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)

        let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
        downloadedEpisodes.removeAll { $0.id == episode.id }
        downloadedEpisodes.append(DownloadedEpisode(
            id: episode.id,
            title: episode.title,
            scriptureReference: episode.scriptureReference,
            fileSizeBytes: size
        ))
        save()
    }

    func delete(_ id: String) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
        downloadedEpisodes.removeAll { $0.id == id }
        save()
    }

    func deleteAll() {
        for ep in downloadedEpisodes {
            try? FileManager.default.removeItem(at: fileURL(for: ep.id))
        }
        downloadedEpisodes.removeAll()
        save()
    }

    func formattedSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        return mb < 1 ? "<1 MB" : String(format: "%.1f MB", mb)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let list = try? JSONDecoder().decode([DownloadedEpisode].self, from: data) else { return }
        // Filter out any files that were manually deleted
        downloadedEpisodes = list.filter {
            FileManager.default.fileExists(atPath: fileURL(for: $0.id).path)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(downloadedEpisodes) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}
