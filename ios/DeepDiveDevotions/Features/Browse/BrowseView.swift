import SwiftUI

struct BrowseView: View {
    var initialBook: String? = nil

    @StateObject private var viewModel = BrowseViewModel()
    @State private var selectedEpisode: Episode?
    private let chapterColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        titleSection
                        testamentSection
                        bookSection
                        chapterSection
                        Spacer().frame(height: 90)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.dddGold)
                        .scaleEffect(1.15)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Deep Dive Devotions")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.dddSurfaceBlack, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(item: $selectedEpisode) { ep in
                EpisodeDetailView(episode: ep)
            }
            .task {
                await viewModel.loadBooks()
                if let book = initialBook {
                    viewModel.selectedTestament = nil
                    await viewModel.selectBook(book)
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.dddSurfaceBlack, Color.dddSurfaceNavy, Color.dddSurfaceBlack],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [Color.dddGold.opacity(0.25), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 260
            )
            .blur(radius: 8)
        )
        .ignoresSafeArea()
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose a Chapter to Study")
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundStyle(Color.dddIvory)
            Text("Explore God's Word one chapter at a time.")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(Color.dddGoldLight)
        }
        .padding(.top, 6)
    }

    private var testamentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1. Select Testament")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Color.dddGoldLight)

            HStack(spacing: 12) {
                testamentCard(
                    title: "Old Testament",
                    count: "39 Books",
                    selected: viewModel.selectedTestament == "OT"
                ) {
                    Task { await viewModel.applyTestament("OT") }
                }

                testamentCard(
                    title: "New Testament",
                    count: "27 Books",
                    selected: viewModel.selectedTestament == "NT"
                ) {
                    Task { await viewModel.applyTestament("NT") }
                }
            }
        }
    }

    private func testamentCard(title: String, count: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "book.fill")
                    .font(.title2)
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                Text(count)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .opacity(0.85)
            }
            .foregroundStyle(Color.dddGoldLight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? Color.dddGold.opacity(0.14) : Color.black.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.dddGold : Color.dddGold.opacity(0.3), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var bookSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2. Select Book")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Color.dddGoldLight)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.dddGold.opacity(0.8))
                TextField("Search books...", text: $viewModel.bookSearchText)
                    .foregroundStyle(Color.dddIvory)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.black.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.dddGold.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.filteredBooks, id: \.self) { book in
                        Button {
                            Task { await viewModel.selectBook(book) }
                        } label: {
                            HStack {
                                Text(book)
                                    .font(.system(size: 20, weight: .medium, design: .serif))
                                    .foregroundStyle(Color.dddIvory)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.dddGold)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.selectedBook == book ? Color.dddGold.opacity(0.2) : Color.black.opacity(0.22))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        viewModel.selectedBook == book ? Color.dddGold : Color.dddGold.opacity(0.26),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 230)
        }
    }

    private var chapterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("3. Select Chapter")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Color.dddGoldLight)

            if let error = viewModel.error {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            LazyVGrid(columns: chapterColumns, spacing: 10) {
                ForEach(viewModel.chapterNumbers, id: \.self) { chapter in
                    Button {
                        viewModel.selectedChapter = chapter
                        if let episode = viewModel.chapterEpisode(chapter) {
                            selectedEpisode = episode
                        }
                    } label: {
                        Text("\(chapter)")
                            .font(.system(size: 26, weight: .medium, design: .serif))
                            .foregroundStyle(Color.dddIvory)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.selectedChapter == chapter ? Color.dddGold.opacity(0.24) : Color.black.opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        viewModel.selectedChapter == chapter ? Color.dddGold : Color.dddGold.opacity(0.25),
                                        lineWidth: 1.1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
