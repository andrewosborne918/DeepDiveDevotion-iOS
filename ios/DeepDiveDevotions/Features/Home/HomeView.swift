import SwiftUI

struct HomeView: View {
    var onBrowseAll: (() -> Void)? = nil

    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedEpisode: Episode?

    var body: some View {
        NavigationStack {
            ZStack {
                background

                if viewModel.isLoading && viewModel.recentEpisodes.isEmpty {
                    ProgressView()
                        .tint(.dddGold)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            hero
                            actionButtons

                            if let current = viewModel.continueListening.first {
                                continueListeningButton(current)
                            }

                            bottomTagline
                            Spacer().frame(height: 110)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 24)
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedEpisode) { ep in
                EpisodeDetailView(episode: ep)
            }
        }
        .task { await viewModel.load() }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.dddSurfaceBlack, Color.dddSurfaceNavy, Color.dddSurfaceBlack],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [Color.dddGold.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 4,
                endRadius: 380
            )
        )
        .ignoresSafeArea()
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Text("Deep Dive\nDevotions")
                .font(.system(size: 64, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.dddIvory)
                .lineSpacing(-4)

            Rectangle()
                .fill(Color.dddGold.opacity(0.7))
                .frame(height: 1)
                .overlay(Image(systemName: "sparkle").foregroundStyle(Color.dddGold))
                .padding(.horizontal, 40)

            if let featured = viewModel.featuredEpisode {
                Button {
                    handleTap(featured)
                } label: {
                    AsyncThumbnailView(url: featured.thumbnailURL, cornerRadius: 16)
                        .frame(height: 260)
                        .overlay(
                            LinearGradient(
                                colors: [.clear, Color.black.opacity(0.45)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        )
                }
                .buttonStyle(.plain)
            }

            Text("One Chapter. Every Day.")
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundStyle(Color.dddIvory.opacity(0.92))
                .padding(.top, 8)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let featured = viewModel.featuredEpisode {
                Button { handleTap(featured) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .font(.title3)
                        Text("Start Today's Chapter")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(Color.dddSurfaceBlack)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.dddGoldLight)
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                if let onBrowseAll {
                    onBrowseAll()
                }
            } label: {
                rowButton(title: "Browse All Chapters", icon: "books.vertical.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private func continueListeningButton(_ episode: Episode) -> some View {
        Button {
            handleTap(episode)
        } label: {
            rowButton(title: "Continue Listening", icon: "play.circle")
        }
        .buttonStyle(.plain)
    }

    private var bottomTagline: some View {
        Text("Draw closer. Grow daily. Live His Word.")
            .font(.system(size: 28, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(Color.dddGold.opacity(0.9))
            .padding(.top, 8)
    }

    private func rowButton(title: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.dddGoldLight)
            Text(title)
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(Color.dddIvory)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.dddGold)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.dddGold.opacity(0.35))
                .frame(height: 1)
        }
    }

    private func handleTap(_ episode: Episode) {
        selectedEpisode = episode
    }
}
