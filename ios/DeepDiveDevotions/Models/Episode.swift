import Foundation

struct Episode: Codable, Identifiable, Hashable {
    let id: String
    let episodeNumber: Int
    let title: String
    let description: String?
    let publishDate: String?
    let fileName: String?
    let audioUrl: String?
    let videoUrl: String?
    let youtubeUrl: String?
    let thumbnailUrl: String?
    let scriptureReference: String?
    let bookName: String?
    let chapterNumber: Int?
    let testament: String?
    let transcript: String?
    let premium: Bool
    let processed: Bool
    let locked: Bool?
    let createdAt: String?
    let updatedAt: String?

    var formattedPublishDate: String? {
        guard let publishDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: publishDate) else { return publishDate }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }

    var isLocked: Bool { locked ?? false }

    var audioURL: URL? {
        if let audioUrl, let remote = URL(string: audioUrl) {
            return remote
        }

        guard
            let root = Bundle.main.object(forInfoDictionaryKey: "LOCAL_AUDIO_EPISODES_PATH") as? String,
            !root.isEmpty,
            let fileName,
            !fileName.isEmpty
        else {
            return nil
        }

        let fullPath = (root as NSString).appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fullPath) {
            return URL(fileURLWithPath: fullPath)
        }

        let withM4A = fullPath.hasSuffix(".m4a") ? fullPath : "\(fullPath).m4a"
        if FileManager.default.fileExists(atPath: withM4A) {
            return URL(fileURLWithPath: withM4A)
        }

        return nil
    }

    var videoURL: URL? {
        guard let videoUrl else { return nil }
        return URL(string: videoUrl)
    }

    var thumbnailURL: URL? {
        guard let thumbnailUrl else { return nil }
        return URL(string: thumbnailUrl)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Episode, rhs: Episode) -> Bool {
        lhs.id == rhs.id
    }
}

struct EpisodesResponse: Codable {
    let data: [Episode]
    let meta: PaginationMeta
}

struct PaginationMeta: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

struct BookSummary: Codable, Identifiable {
    let bookName: String
    let testament: String?
    let episodeCount: Int

    var id: String { bookName }
}

struct BooksResponse: Codable {
    let data: [BookSummary]
}

struct SearchResult: Codable, Identifiable {
    let id: String
    let episodeNumber: Int
    let title: String
    let description: String?
    let publishDate: String?
    let audioUrl: String?
    let videoUrl: String?
    let thumbnailUrl: String?
    let scriptureReference: String?
    let bookName: String?
    let chapterNumber: Int?
    let testament: String?
    let premium: Bool
    let processed: Bool
    let locked: Bool?
    let highlight: String?

    func toEpisode() -> Episode {
        Episode(
            id: id,
            episodeNumber: episodeNumber,
            title: title,
            description: description,
            publishDate: publishDate,
            fileName: nil,
            audioUrl: audioUrl,
            videoUrl: videoUrl,
            youtubeUrl: nil,
            thumbnailUrl: thumbnailUrl,
            scriptureReference: scriptureReference,
            bookName: bookName,
            chapterNumber: chapterNumber,
            testament: testament,
            transcript: nil,
            premium: premium,
            processed: processed,
            locked: locked,
            createdAt: nil,
            updatedAt: nil
        )
    }
}

struct SearchResponse: Codable {
    let data: [SearchResult]
    let meta: PaginationMeta
}
