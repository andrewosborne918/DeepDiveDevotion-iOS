import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case serverError(String)
    case decodeError
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .serverError(let message): return message
        case .decodeError: return "Failed to parse response"
        case .notFound: return "Not found"
        }
    }
}

// Calls Supabase PostgREST directly — no backend server required.
actor APIClient {
    static let shared = APIClient()

    private let restURL: String
    private let anonKey: String
    private let decoder: JSONDecoder

    private init() {
        let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
            ?? "https://peqykopvhgksroncqziu.supabase.co"
        self.restURL = "\(supabaseURL)/rest/v1"
        self.anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
            ?? "sb_publishable_l1Welt-lD6INjphDkLmp_Q_wEjSzNOP"
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    private func request<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(restURL)\(path)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError("No HTTP response")
        }
        guard 200..<300 ~= http.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError("HTTP \(http.statusCode): \(body)")
        }
        guard let decoded = try? decoder.decode(T.self, from: data) else {
            throw APIError.decodeError
        }
        return decoded
    }

    func fetchLatestEpisodes(limit: Int = 30) async throws -> [Episode] {
        try await request("/episodes?processed=eq.true&order=episode_number.desc&limit=\(limit)")
    }

    func fetchTodaysEpisode() async throws -> Episode? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let episodes: [Episode] = try await request("/episodes?publish_date=eq.\(today)&processed=eq.true&limit=1")
        return episodes.first
    }

    func fetchBooks() async throws -> [BookSummary] {
        try await request("/books_summary")
    }

    func fetchEpisodes(book: String) async throws -> [Episode] {
        let encoded = book.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? book
        return try await request("/episodes?book_name=eq.\(encoded)&processed=eq.true&order=episode_number.asc")
    }

    func fetchEpisode(id: String) async throws -> Episode {
        let episodes: [Episode] = try await request("/episodes?id=eq.\(id)&limit=1")
        guard let episode = episodes.first else { throw APIError.notFound }
        return episode
    }

    func fetchEpisode(book: String, chapter: Int) async throws -> Episode {
        let encoded = book.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? book
        let episodes: [Episode] = try await request("/episodes?book_name=eq.\(encoded)&chapter_number=eq.\(chapter)&processed=eq.true&limit=1")
        guard let episode = episodes.first else { throw APIError.notFound }
        return episode
    }

    /// Fetches the Book Overview episode (chapter_number=0) for a given book.
    func fetchOverviewEpisode(book: String) async throws -> Episode? {
        let encoded = book.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? book
        let episodes: [Episode] = try await request("/episodes?book_name=eq.\(encoded)&chapter_number=eq.0&limit=1")
        return episodes.first
    }
}
