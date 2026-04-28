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

    var audioURL: URL? {
        guard let audioUrl else { return nil }
        return URL(string: audioUrl)
    }

    var thumbnailURL: URL? {
        guard let thumbnailUrl else { return nil }
        return URL(string: thumbnailUrl)
    }

    var isLocked: Bool {
        locked ?? false
    }

    var formattedDate: String {
        guard let publishDate, !publishDate.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: publishDate) {
            let output = DateFormatter()
            output.dateStyle = .medium
            return output.string(from: date)
        }
        return publishDate
    }
}

struct BookSummary: Codable, Identifiable {
    let bookName: String
    let testament: String?
    let episodeCount: Int

    var id: String { bookName }
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

struct BooksResponse: Codable {
    let data: [BookSummary]
}
