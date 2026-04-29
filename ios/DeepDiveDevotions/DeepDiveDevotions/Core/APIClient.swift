import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case serverError(String)
    case decodeError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .serverError(let message): return message
        case .decodeError: return "Failed to parse response"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let decoder: JSONDecoder
    private let baseURL: String

    private init() {
        self.baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
            ?? "http://localhost:3100/v1"
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    private func request<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError("No HTTP response")
        }

        guard 200..<300 ~= http.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.serverError(body)
        }

        guard let decoded = try? decoder.decode(T.self, from: data) else {
            throw APIError.decodeError
        }
        return decoded
    }

    func fetchLatestEpisodes(limit: Int = 30) async throws -> [Episode] {
        let response: EpisodesResponse = try await request("/episodes?page=1&limit=\(limit)&sort=episode_number&order=desc")
        return response.data
    }

    func fetchTodaysEpisode() async throws -> Episode? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let response: EpisodesResponse = try await request("/episodes?page=1&limit=1&date=\(today)")
        return response.data.first
    }

    func fetchBooks() async throws -> [BookSummary] {
        let response: BooksResponse = try await request("/episodes/books")
        return response.data
    }

    func fetchEpisodes(book: String) async throws -> [Episode] {
        let encoded = book.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? book
        struct BookEpisodesResponse: Codable {
            let episodes: [Episode]
        }
        let response: BookEpisodesResponse = try await request("/episodes/book/\(encoded)")
        return response.episodes
    }

    func fetchEpisode(id: String) async throws -> Episode {
        try await request("/episodes/\(id)")
    }

    func fetchEpisode(book: String, chapter: Int) async throws -> Episode {
        let encodedBook = book.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? book
        return try await request("/episodes/book/\(encodedBook)/chapter/\(chapter)")
    }
}
