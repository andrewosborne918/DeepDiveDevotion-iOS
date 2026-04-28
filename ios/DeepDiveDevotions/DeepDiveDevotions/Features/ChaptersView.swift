import SwiftUI

struct ChaptersView: View {
    @EnvironmentObject private var player: AudioPlayerManager
    @State private var books: [BookSummary] = []
    @State private var selectedTestament: String = "OT"
    @State private var selectedBook: String?
    @State private var bookWheelSelection: String = ""
    @State private var selectedChapter: Int?
    @State private var episodesByChapter: [Int: Episode] = [:]
    @State private var navigationEpisode: Episode?
    @State private var error: String?
    @State private var isLoadingBooks = false
    @State private var isLoadingBookEpisodes = false
    @AppStorage("recent_chapter_keys") private var recentChapterKeysRaw: String = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)
    private let commonOT = ["Genesis", "Psalms", "Proverbs", "Isaiah"]
    private let commonNT = ["Matthew", "John", "Romans", "Revelation"]
    private let canonicalOTOrder = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
        "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah",
        "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
        "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah",
        "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
    ]
    private let canonicalNTOrder = [
        "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians",
        "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy",
        "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude",
        "Revelation",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Browse")
                            .font(.system(size: 40, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.dddIvory)

                        Text("Find and jump into any chapter devotion fast.")
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(Color.dddGoldLight)

                        if !recentChapters.isEmpty {
                            Text("Recent")
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.dddGoldLight)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recentChapters, id: \.self) { key in
                                        Button(key) {
                                            Task { await jumpToRecent(key) }
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.22)))
                                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.dddGold.opacity(0.3), lineWidth: 1))
                                        .foregroundStyle(Color.dddIvory)
                                    }
                                }
                            }
                        }

                        Text("1. Select Testament")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.dddGoldLight)

                        HStack(spacing: 12) {
                            testamentCard("Old Testament", selected: selectedTestament == "OT") {
                                Task {
                                    selectedTestament = "OT"
                                    await selectFirstBook()
                                }
                            }
                            testamentCard("New Testament", selected: selectedTestament == "NT") {
                                Task {
                                    selectedTestament = "NT"
                                    await selectFirstBook()
                                }
                            }
                        }

                        Text("Quick Picks")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.dddGoldLight)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach((selectedTestament == "OT" ? commonOT : commonNT), id: \.self) { book in
                                    Button(book) {
                                        Task { await loadBook(book) }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.22)))
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.dddGold.opacity(0.3), lineWidth: 1))
                                    .foregroundStyle(Color.dddIvory)
                                }
                            }
                        }

                        Text("2. Select Book")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.dddGoldLight)

                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.22))
                            BookWheelPicker(
                                books: filteredBooks.map(\.bookName),
                                selection: $bookWheelSelection
                            )
                            .padding(.horizontal, 6)
                        }
                        .frame(height: 170)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dddGold.opacity(0.28), lineWidth: 1))
                        .onChange(of: bookWheelSelection) { _, newValue in
                            guard !newValue.isEmpty else { return }
                            Task { await loadBook(newValue) }
                        }

                        if isLoadingBooks || isLoadingBookEpisodes {
                            ProgressView("Loading content...")
                                .foregroundStyle(Color.dddGoldLight)
                                .tint(.dddGold)
                        }

                        Text("3. Select Chapter")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.dddGoldLight)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(chapters, id: \.self) { chapter in
                                NavigationLink(destination: episodesByChapter[chapter].map { EpisodeDetailView(episode: $0) }) {
                                    Text("\(chapter)")
                                        .font(.system(size: 26, weight: .medium, design: .serif))
                                        .foregroundStyle(Color.dddIvory)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.2)))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dddGold.opacity(0.25), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(episodesByChapter[chapter] == nil)
                                .simultaneousGesture(TapGesture().onEnded {
                                    if let episode = episodesByChapter[chapter] {
                                        pushRecent(book: episode.bookName ?? selectedBook ?? "Unknown", chapter: chapter)
                                    }
                                })
                            }
                        }

                        if let error {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Having trouble loading content. Try again.")
                                    .foregroundStyle(Color.dddGoldLight)
                                Text(error).font(.caption).foregroundStyle(.red)
                                Button("Retry") {
                                    Task {
                                        if books.isEmpty {
                                            await loadBooks()
                                            await selectFirstBook()
                                        } else if let selectedBook {
                                            await loadBook(selectedBook)
                                        }
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.dddGold.opacity(0.18)))
                            }
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(20)
                }
            }
            .task {
                await loadBooks()
                await selectFirstBook()
            }
        }
    }

    private var background: some View {
        LinearGradient(colors: [Color.dddSurfaceBlack, Color.dddSurfaceNavy, Color.dddSurfaceBlack], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(RadialGradient(colors: [Color.dddGold.opacity(0.2), .clear], center: .topLeading, startRadius: 5, endRadius: 300))
            .ignoresSafeArea()
    }

    private var filteredBooks: [BookSummary] {
        let scoped = books.filter { ($0.testament ?? "OT") == selectedTestament }
        let canonicalOrder = selectedTestament == "OT" ? canonicalOTOrder : canonicalNTOrder
        let rank = Dictionary(uniqueKeysWithValues: canonicalOrder.enumerated().map { ($1, $0) })

        return scoped.sorted { lhs, rhs in
            let leftRank = rank[lhs.bookName] ?? Int.max
            let rightRank = rank[rhs.bookName] ?? Int.max
            if leftRank == rightRank {
                return lhs.bookName < rhs.bookName
            }
            return leftRank < rightRank
        }
    }

    private var recentChapters: [String] {
        recentChapterKeysRaw
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private var chapters: [Int] {
        episodesByChapter.keys.sorted()
    }

    private func testamentCard(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "book.fill").font(.title2)
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
            }
            .foregroundStyle(Color.dddGoldLight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(selected ? Color.dddGold.opacity(0.15) : Color.black.opacity(0.2)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.dddGold : Color.dddGold.opacity(0.3), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func loadBooks() async {
        isLoadingBooks = true
        error = nil
        defer { isLoadingBooks = false }
        do {
            books = try await APIClient.shared.fetchBooks()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func selectFirstBook() async {
        guard let first = filteredBooks.first else { return }
        bookWheelSelection = first.bookName
        await loadBook(first.bookName)
    }

    private func loadBook(_ book: String) async {
        selectedBook = book
        bookWheelSelection = book
        selectedChapter = nil
        isLoadingBookEpisodes = true
        error = nil
        defer { isLoadingBookEpisodes = false }
        do {
            let episodes = try await APIClient.shared.fetchEpisodes(book: book)
            var map: [Int: Episode] = [:]
            for ep in episodes {
                if let chapter = ep.chapterNumber {
                    map[chapter] = ep
                }
            }
            episodesByChapter = map
            } catch {
            self.error = error.localizedDescription
        }
    }

    private func pushRecent(book: String, chapter: Int) {
        let key = "\(book) \(chapter)"
        var current = recentChapters
        current.removeAll { $0 == key }
        current.insert(key, at: 0)
        if current.count > 10 {
            current = Array(current.prefix(10))
        }
        recentChapterKeysRaw = current.joined(separator: "\n")
    }

    private func jumpToRecent(_ key: String) async {
        guard let chapterToken = key.split(separator: " ").last,
              let chapter = Int(chapterToken) else {
            return
        }

        let book = String(key.dropLast(chapterToken.count + 1))
        selectedTestament = (books.first(where: { $0.bookName == book })?.testament) ?? "OT"
        await loadBook(book)
        selectedChapter = chapter
        if let episode = episodesByChapter[chapter] {
            navigationEpisode = episode
        }
    }
}
