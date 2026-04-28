import Foundation

@MainActor
class BrowseViewModel: ObservableObject {
    @Published var books: [BookSummary] = []
    @Published var selectedBook: String?
    @Published var selectedTestament: String?
    @Published var bookSearchText: String = ""
    @Published var chapterNumbers: [Int] = []
    @Published var selectedChapter: Int?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var episodesByChapter: [Int: Episode] = [:]

    private let otBookOrder: [String] = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
        "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
        "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles",
        "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
        "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
        "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
        "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah",
        "Haggai", "Zechariah", "Malachi",
    ]

    private let ntBookOrder: [String] = [
        "Matthew", "Mark", "Luke", "John", "Acts",
        "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
        "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
        "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
        "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation",
    ]

    func loadBooks() async {
        isLoading = true
        defer { isLoading = false }

        do {
            books = try await APIClient.shared.fetchBooks()
            if selectedTestament == nil {
                selectedTestament = "OT"
            }

            if selectedBook == nil, let first = filteredBooks.first {
                await selectBook(first)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func selectBook(_ book: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        selectedBook = book
        selectedChapter = nil
        chapterNumbers = []
        episodesByChapter = [:]

        do {
            let episodes = try await APIClient.shared.fetchEpisodesByBook(book)
            for episode in episodes {
                if let chapter = episode.chapterNumber {
                    episodesByChapter[chapter] = episode
                }
            }

            chapterNumbers = episodesByChapter.keys.sorted()
            selectedChapter = chapterNumbers.first
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyTestament(_ testament: String) async {
        selectedTestament = testament
        selectedBook = nil
        selectedChapter = nil
        chapterNumbers = []
        episodesByChapter = [:]

        if let first = filteredBooks.first {
            await selectBook(first)
        }
    }

    func chapterEpisode(_ chapter: Int) -> Episode? {
        episodesByChapter[chapter]
    }

    var filteredBooks: [String] {
        let scoped = books.filter { summary in
            guard let selectedTestament else { return true }
            return summary.testament == selectedTestament
        }

        let searched = scoped.filter { summary in
            guard !bookSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
            return summary.bookName.localizedCaseInsensitiveContains(bookSearchText)
        }

        let lookup = Dictionary(uniqueKeysWithValues: searched.map { ($0.bookName, $0) })
        let order = (selectedTestament == "NT") ? ntBookOrder : otBookOrder

        var ordered = order.filter { lookup[$0] != nil }
        let leftovers = searched
            .map(\.bookName)
            .filter { !ordered.contains($0) }
            .sorted()

        ordered.append(contentsOf: leftovers)
        return ordered
    }
}
