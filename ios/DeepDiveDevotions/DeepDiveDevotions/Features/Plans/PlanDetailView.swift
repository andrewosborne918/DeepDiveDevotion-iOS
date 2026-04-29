import SwiftUI

// MARK: - Plan Detail View

struct PlanDetailView: View {
    let plan: ReadingPlan

    @EnvironmentObject var planStore: PlanStore
    @EnvironmentObject var player: AudioPlayerManager
    @Environment(\.dismiss) private var dismiss

    @State private var expandedDayId: String?
    @State private var navigateToEpisode: Episode?
    @State private var loadingStepId: String?
    @State private var errorMessage: String?
    @State private var pendingStep: PlanStep?
    @State private var pendingEpisodeId: String?
    @State private var hideCompleted: Bool = false

    private var isActivePlan: Bool { planStore.activePlanId == plan.id }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.dddSurfaceBlack, Color.dddSurfaceNavy, Color.dddSurfaceBlack],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection
                        divider
                        stepsSection
                        Spacer(minLength: 100)
                    }
                }

                // Fixed bottom CTA
                VStack {
                    Spacer()
                    bottomBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.dddGold)
                }
            }
            .navigationDestination(item: $navigateToEpisode) { episode in
                EpisodeDetailView(episode: episode)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: player.finishedEpisodeId) { _, finishedId in
                guard let finishedId, let step = pendingStep,
                      finishedId == pendingEpisodeId else { return }
                planStore.markStepComplete(step)
                pendingStep = nil
                pendingEpisodeId = nil
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: plan.category.icon)
                    .foregroundColor(.dddGold)
                Text(plan.category.rawValue.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.dddGold)
                Spacer()
                DifficultyBadge(difficulty: plan.difficulty)
            }

            Text(plan.title)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(.dddIvory)

            Text(plan.description)
                .font(.subheadline)
                .foregroundColor(.dddIvory.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                statPill(icon: "calendar", label: plan.durationLabel)
                statPill(icon: "clock", label: plan.dailyTimeLabel)
                statPill(icon: "book.pages", label: "\(plan.totalDays) readings")
            }

            // Progress bar (if active)
            if isActivePlan {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: planStore.percentComplete)
                        .tint(.dddGold)
                    Text("\(planStore.completedCount) of \(plan.totalDays) complete")
                        .font(.caption2)
                        .foregroundColor(.dddIvory.opacity(0.5))
                }
            }
        }
        .padding(20)
    }

    private func statPill(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.dddGold)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(.dddIvory.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
    }

    private var divider: some View {
        Divider()
            .background(Color.white.opacity(0.1))
            .padding(.horizontal)
    }

    // MARK: Steps List

    private var stepsSection: some View {
        let visibleSteps = hideCompleted
            ? plan.steps.filter { !planStore.isStepComplete($0) }
            : plan.steps

        let completedCount = plan.steps.filter { planStore.isStepComplete($0) }.count

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Readings")
                    .font(.headline)
                    .foregroundColor(.dddIvory)
                Spacer()
                if completedCount > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hideCompleted.toggle()
                        }
                    } label: {
                        Text(hideCompleted ? "Show Completed" : "Hide Completed")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.dddGold)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ForEach(visibleSteps) { step in
                PlanStepRow(
                    step: step,
                    isComplete: planStore.isStepComplete(step),
                    isNext: planStore.nextStep?.id == step.id && isActivePlan,
                    isLoading: loadingStepId == step.id
                )
                .onTapGesture {
                    if isActivePlan {
                        loadAndNavigate(to: step)
                    }
                }
                Divider().background(Color.white.opacity(0.06)).padding(.leading, 56)
            }
        }
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.1))
            HStack(spacing: 14) {
                if isActivePlan {
                    if let step = pendingStep {
                        // Episode loaded — waiting for manual completion or audio finish
                        Button {
                            planStore.markStepComplete(step)
                            pendingStep = nil
                            pendingEpisodeId = nil
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark Complete")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.dddGold)
                            .foregroundColor(.dddSurfaceBlack)
                            .cornerRadius(12)
                        }
                    } else if let next = planStore.nextStep {
                        Button {
                            loadAndNavigate(to: next)
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Continue — Day \(planStore.currentDayIndex + 1)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.dddGold)
                            .foregroundColor(.dddSurfaceBlack)
                            .cornerRadius(12)
                        }
                    } else {
                        // All done
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Plan Complete!")
                                .fontWeight(.semibold)
                                .foregroundColor(.dddIvory)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                    }
                } else {
                    Button {
                        planStore.startPlan(plan)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start This Plan")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.dddGold)
                        .foregroundColor(.dddSurfaceBlack)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.dddSurfaceBlack.opacity(0.95))
        }
    }

    // MARK: Navigation

    private func loadAndNavigate(to step: PlanStep) {
        loadingStepId = step.id
        Task {
            do {
                let episode = try await APIClient.shared.fetchEpisode(book: step.bookName, chapter: step.chapterNumber ?? 1)
                await MainActor.run {
                    loadingStepId = nil
                    navigateToEpisode = episode
                    if isActivePlan {
                        pendingStep = step
                        pendingEpisodeId = episode.id
                    }
                }
            } catch {
                await MainActor.run {
                    loadingStepId = nil
                    errorMessage = "Couldn't load \(step.title). Make sure the server is running."
                }
            }
        }
    }
}

// MARK: - Step Row

private struct PlanStepRow: View {
    let step: PlanStep
    let isComplete: Bool
    let isNext: Bool
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(isComplete ? Color.dddGold : (isNext ? Color.dddGold.opacity(0.2) : Color.white.opacity(0.06)))
                    .frame(width: 32, height: 32)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(isNext ? .dddGold : .white)
                } else if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.dddSurfaceBlack)
                } else {
                    Text("\(step.dayNumber)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(isNext ? .dddGold : .dddIvory.opacity(0.4))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.subheadline.weight(isNext ? .semibold : .regular))
                    .foregroundColor(isComplete ? .dddIvory.opacity(0.5) : .dddIvory)
                    .strikethrough(isComplete, color: .dddIvory.opacity(0.4))

                if isNext {
                    Text("Up next")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.dddGold)
                }
            }

            Spacer()

            if isNext, !isLoading {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.dddGold.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    PlanDetailView(plan: .sevenDayStart)
        .environmentObject(PlanStore.shared)
}
