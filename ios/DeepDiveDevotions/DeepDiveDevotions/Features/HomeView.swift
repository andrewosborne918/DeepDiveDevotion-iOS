import SwiftUI

struct HomeView: View {
    var onBrowseAll: (() -> Void)? = nil

    @State private var latest: [Episode] = []
    @State private var todaysEpisode: Episode?
    @State private var selectedEpisode: Episode?
    @State private var error: String?
    @State private var isLoading = false
    @State private var planEpisodeLoading = false
    @State private var pendingPlanStep: PlanStep?
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var planStore: PlanStore

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.dddSurfaceBlack.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Full-bleed hero ──
                        heroSection

                        // ── Content below image ──
                        VStack(spacing: 0) {
                            taglineRow

                            Divider().background(Color.dddGold.opacity(0.2))

                            // Primary CTA
                            if let plan = planStore.activePlan, let step = planStore.nextStep, !planStore.isCompleted {
                                resumePlanCTA(plan: plan, step: step)
                            } else if let today = todaysEpisode ?? latest.first {
                                primaryCTA(episode: today)
                            } else if isLoading {
                                loadingCTA
                            }

                            // Streak chip
                            if planStore.currentStreak > 0 {
                                streakChip
                            }

                            Divider().background(Color.dddGold.opacity(0.12))

                            // Plan progress
                            if let plan = planStore.activePlan {
                                planProgressModule(plan: plan)
                                Divider().background(Color.dddGold.opacity(0.12))
                            }

                            // Continue listening
                            if let nowPlaying = player.currentEpisode {
                                continueListeningRow(episode: nowPlaying)
                                Divider().background(Color.dddGold.opacity(0.12))
                            }

                            // Browse all
                            browseRow

                            Divider().background(Color.dddGold.opacity(0.12))

                            // Recent episodes
                            if !latest.isEmpty {
                                recentSection
                            }

                            // Error
                            if let error {
                                errorView(message: error)
                            }

                            // Bottom tagline
                            bottomTagline

                            Spacer(minLength: 100)
                        }
                        .background(Color.dddSurfaceBlack)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedEpisode) { ep in
                EpisodeDetailView(episode: ep)
            }
            .onChange(of: player.finishedEpisodeId) { _, finishedId in
                guard let finishedId, let step = pendingPlanStep,
                      finishedId == selectedEpisode?.id else { return }
                planStore.markStepComplete(step)
                pendingPlanStep = nil
            }
            .task { await load() }
        }
    }

    // MARK: Hero Section

    private var heroSection: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Bible image — full bleed
                Image("DeepDiveHero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.width * 1.15)
                    .clipped()

                // Dark gradient at very top so status bar is readable
                LinearGradient(
                    colors: [Color.black.opacity(0.55), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.35)
                )

                // Title overlaid in upper portion
                VStack(spacing: 6) {
                    Spacer().frame(height: 64)
                    Text("Deep Dive\nDevotions")
                        .font(.system(size: 52, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.dddIvory)
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 2)

                    // Decorative ornament
                    Text("✦")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dddGold)
                        .shadow(color: Color.dddGold.opacity(0.6), radius: 4)

                    Spacer()
                }

                // Bottom fade into black background
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, Color.dddSurfaceBlack],
                        startPoint: UnitPoint(x: 0.5, y: 0.6),
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.width * 0.45)
                }
            }
        }
        .frame(height: UIScreen.main.bounds.width * 1.15)
    }

    // MARK: Tagline

    private var taglineRow: some View {
        Text("One Chapter. Every Day.")
            .font(.system(size: 15, weight: .semibold, design: .default))
            .kerning(2.5)
            .textCase(.uppercase)
            .foregroundColor(Color.dddGoldLight.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
    }

    // MARK: Primary CTA

    private func primaryCTA(episode: Episode) -> some View {
        Button {
            selectedEpisode = episode
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "book.fill")
                    .font(.title3)
                Text("Start Today's Chapter")
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(Color.dddSurfaceBlack)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color.dddGold, Color.dddGoldLight],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(14)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: Resume Plan CTA

    private func resumePlanCTA(plan: ReadingPlan, step: PlanStep) -> some View {
        Button {
            loadPlanEpisode(step: step)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Resume Your Journey")
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                    Text("Day \(planStore.currentDayIndex + 1) · \(step.bookName) \(step.chapterNumber ?? 1)")
                        .font(.caption.weight(.medium))
                        .opacity(0.75)
                }
                Spacer()
                if planEpisodeLoading {
                    ProgressView().tint(Color.dddSurfaceBlack).scaleEffect(0.85)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundColor(Color.dddSurfaceBlack)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color.dddGold, Color.dddGoldLight],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(14)
            )
        }
        .buttonStyle(.plain)
        .disabled(planEpisodeLoading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: Streak Chip

    private var streakChip: some View {
        HStack(spacing: 6) {
            Text("🔥")
                .font(.headline)
            Text("\(planStore.currentStreak)-day streak")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dddGold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.dddGold.opacity(0.1))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.dddGold.opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var loadingCTA: some View {
        HStack {
            ProgressView().tint(.dddGold)
            Text("Loading today's chapter…")
                .font(.subheadline)
                .foregroundColor(.dddGoldLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: Plan Progress Module

    @ViewBuilder
    private func planProgressModule(plan: ReadingPlan) -> some View {
        Button {
            // Tapping the row navigates to the next plan episode
            if let next = planStore.nextStep, !planStore.isCompleted {
                loadPlanEpisode(step: next)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.dddGold.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "map.fill")
                        .foregroundColor(.dddGold)
                        .font(.callout)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundColor(.dddIvory)
                    if let next = planStore.nextStep, !planStore.isCompleted {
                        Text("Day \(planStore.currentDayIndex + 1) · \(next.bookName) \(next.chapterNumber ?? 1)")
                            .font(.caption)
                            .foregroundColor(.dddGoldLight.opacity(0.75))
                    } else {
                        Text("Plan complete 🎉")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                if planEpisodeLoading {
                    ProgressView().tint(.dddGold).scaleEffect(0.85)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.dddGold.opacity(0.6))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .disabled(planEpisodeLoading || planStore.isCompleted)
    }

    // MARK: Continue Listening Row

    private func continueListeningRow(episode: Episode) -> some View {
        Button {
            player.play(episode: episode)
            selectedEpisode = episode
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 40, height: 40)
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.dddGoldLight)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Continue Listening")
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundColor(.dddIvory)
                    Text(episode.scriptureReference ?? episode.title)
                        .font(.caption)
                        .foregroundColor(.dddGoldLight.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.dddIvory.opacity(0.3))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: Browse Row

    private var browseRow: some View {
        Button {
            onBrowseAll?()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 40, height: 40)
                    Image(systemName: "books.vertical.fill")
                        .foregroundColor(.dddGoldLight)
                        .font(.callout)
                }
                Text("Browse All Chapters")
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundColor(.dddIvory)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.dddIvory.opacity(0.3))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: Recent Episodes

    private var recentSection: some View {
        let episodes = player.recentlyPlayed.isEmpty
            ? Array(latest.prefix(3))
            : Array(player.recentlyPlayed.prefix(3))
        let sectionTitle = player.recentlyPlayed.isEmpty ? "Recent Episodes" : "Recently Played"

        return VStack(alignment: .leading, spacing: 0) {
            Text(sectionTitle)
                .font(.system(size: 13, weight: .semibold))
                .kerning(1.5)
                .textCase(.uppercase)
                .foregroundColor(.dddIvory.opacity(0.35))
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 10)

            ForEach(Array(episodes)) { episode in
                Button {
                    selectedEpisode = episode
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(episode.scriptureReference ?? episode.title)
                                .font(.system(size: 17, weight: .medium, design: .serif))
                                .foregroundColor(.dddIvory)
                            Text(episode.formattedDate)
                                .font(.caption)
                                .foregroundColor(.dddGoldLight.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: "play.circle")
                            .foregroundColor(.dddGold.opacity(0.7))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 10) {
            Text("Couldn't load content")
                .foregroundColor(.dddGoldLight)
                .font(.subheadline)
            Button("Retry") { Task { await load() } }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.dddGold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: Bottom Tagline

    private var bottomTagline: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart")
                .font(.caption2)
                .foregroundColor(.dddGold.opacity(0.5))
            Text("Draw closer. Grow daily. Live His Word.")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(.dddIvory.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    // MARK: Helpers

    private func loadPlanEpisode(step: PlanStep) {
        planEpisodeLoading = true
        Task {
            do {
                let episode = try await APIClient.shared.fetchEpisode(book: step.bookName, chapter: step.chapterNumber ?? 1)
                await MainActor.run {
                    planEpisodeLoading = false
                    pendingPlanStep = step
                    selectedEpisode = episode
                }
            } catch {
                await MainActor.run { planEpisodeLoading = false }
            }
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let todayFetch   = APIClient.shared.fetchTodaysEpisode()
            async let latestFetch  = APIClient.shared.fetchLatestEpisodes(limit: 20)
            let (today, latestList) = try await (todayFetch, latestFetch)
            todaysEpisode = today
            latest = latestList
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
