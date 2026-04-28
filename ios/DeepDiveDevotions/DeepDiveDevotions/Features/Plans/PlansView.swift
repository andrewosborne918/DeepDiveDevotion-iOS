import SwiftUI

// MARK: - Path Filter

enum PathFilter: String, CaseIterable, Identifiable {
    case peace      = "Find Peace"
    case growth     = "Grow Spiritually"
    case discipline = "Build Discipline"
    case bible      = "Read the Bible"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .peace:      return "heart.fill"
        case .growth:     return "leaf.fill"
        case .discipline: return "flame.fill"
        case .bible:      return "book.fill"
        }
    }

    var planIds: [String] {
        switch self {
        case .peace:      return ["anxiety-peace", "faith-hard-times", "forgiveness", "7day-prayer", "7day-start"]
        case .growth:     return ["purpose-calling", "identity-christ", "life-of-jesus", "7day-start", "30day-nt"]
        case .discipline: return ["21day-discipline", "daily-wisdom", "7day-prayer", "30day-nt"]
        case .bible:      return ["full-bible", "full-ot", "full-nt", "30day-nt", "life-of-jesus", "early-church", "7day-start"]
        }
    }
}

// MARK: - Card Press Style

private struct PlanCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Plans Tab Root View

struct PlansView: View {
    @EnvironmentObject var planStore: PlanStore
    @EnvironmentObject var player: AudioPlayerManager
    @State private var selectedPlan: ReadingPlan?
    @State private var activeFilter: PathFilter?

    // Priority order: Topics near top since they're highest engagement
    private let categoryOrder: [PlanCategory] = [
        .quickStart, .fullBible, .topics, .narrative, .timeBased, .challenges, .habits
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dddSurfaceNavy.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {

                        // ── Styled header ──
                        journeyHeader

                        // ── Active Journey Block ──
                        if let plan = planStore.activePlan {
                            ActiveJourneyBlock(plan: plan, selectedPlan: $selectedPlan)
                                .padding(.horizontal)
                        }

                        // ── Choose Your Path chips ──
                        chooseYourPathSection

                        if let filter = activeFilter {
                            // Filtered results
                            filteredSection(filter: filter)
                        } else {
                            // ── Recommended (only when no active plan) ──
                            if planStore.activePlan == nil {
                                recommendedSection
                            }

                            // ── Category sections ──
                            ForEach(categoryOrder) { category in
                                let plans = planStore.plans(for: category)
                                if !plans.isEmpty {
                                    PlanCategorySection(
                                        category: category,
                                        plans: plans,
                                        selectedPlan: $selectedPlan
                                    )
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedPlan) { plan in
                PlanDetailView(plan: plan)
                    .environmentObject(planStore)
                    .environmentObject(player)
            }
        }
    }

    // MARK: Journey Header

    private var journeyHeader: some View {
        VStack(spacing: 4) {
            Text("✦")
                .font(.system(size: 13))
                .foregroundColor(Color.dddGold)
            Text("Your Journey")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundColor(Color.dddIvory)
            Text("Choose a path. Go deeper every day.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(Color.dddIvory.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: Choose Your Path

    private var chooseYourPathSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What are you looking for?")
                .font(.caption.weight(.semibold))
                .foregroundColor(.dddIvory.opacity(0.5))
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PathFilter.allCases) { filter in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                activeFilter = activeFilter == filter ? nil : filter
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: filter.icon)
                                    .font(.caption2)
                                Text(filter.rawValue)
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(activeFilter == filter ? .dddSurfaceBlack : .dddIvory)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(activeFilter == filter ? Color.dddGold : Color.white.opacity(0.1))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(activeFilter == filter ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: Recommended Section

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.dddGold)
                Text("Start Here")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.dddIvory)
            }
            .padding(.horizontal)

            if let startPlan = planStore.catalog.first(where: { $0.id == "7day-start" }) {
                Button { selectedPlan = startPlan } label: {
                    FeaturedPlanCard(plan: startPlan)
                }
                .buttonStyle(PlanCardButtonStyle())
                .padding(.horizontal)
            }
        }
    }

    // MARK: Filtered Section

    @ViewBuilder
    private func filteredSection(filter: PathFilter) -> some View {
        let filtered = planStore.catalog.filter { filter.planIds.contains($0.id) }
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: filter.icon)
                    .foregroundColor(.dddGold)
                Text(filter.rawValue)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.dddIvory)
                Text("· \(filtered.count) plans")
                    .font(.subheadline)
                    .foregroundColor(.dddIvory.opacity(0.4))
            }
            .padding(.horizontal)

            ForEach(filtered) { plan in
                Button { selectedPlan = plan } label: {
                    FilteredPlanRow(plan: plan)
                }
                .buttonStyle(PlanCardButtonStyle())
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Active Journey Block

private struct ActiveJourneyBlock: View {
    @EnvironmentObject var planStore: PlanStore
    let plan: ReadingPlan
    @Binding var selectedPlan: ReadingPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text("Your Active Journey")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.dddGold)
                        .textCase(.uppercase)
                }
                Spacer()
                Button("Change") {
                    planStore.abandonPlan()
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.dddIvory.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().background(Color.dddGold.opacity(0.2))

            VStack(alignment: .leading, spacing: 12) {
                Text(plan.title)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(.dddIvory)

                if planStore.isCompleted {
                    Label("Plan complete!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                } else if let next = planStore.nextStep {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day \(planStore.currentDayIndex + 1) of \(plan.totalDays)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.dddGold)
                        Text(next.title)
                            .font(.subheadline)
                            .foregroundColor(.dddIvory.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                // Progress
                VStack(spacing: 6) {
                    ProgressView(value: planStore.percentComplete)
                        .tint(.dddGold)
                    HStack {
                        Text("\(planStore.completedCount) of \(plan.totalDays) complete")
                            .font(.caption2)
                            .foregroundColor(.dddIvory.opacity(0.45))
                        Spacer()
                        Text("\(Int(planStore.percentComplete * 100))%")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.dddGold.opacity(0.8))
                    }
                }

                // CTA
                Button {
                    selectedPlan = plan
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text(planStore.isCompleted ? "View Plan" : "Continue")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.dddSurfaceBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.dddGold)
                    .cornerRadius(12)
                }
                .buttonStyle(PlanCardButtonStyle())
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.dddSurfaceBlack.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.dddGold.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

// MARK: - Featured Plan Card (full-width, for Recommended)

private struct FeaturedPlanCard: View {
    @EnvironmentObject var planStore: PlanStore
    let plan: ReadingPlan

    var body: some View {
        HStack(spacing: 16) {
            // Left: icon circle
            ZStack {
                Circle()
                    .fill(Color.dddGold.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: plan.category.icon)
                    .font(.title2)
                    .foregroundColor(.dddGold)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(plan.title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.dddIvory)

                Text(plan.hook)
                    .font(.subheadline)
                    .foregroundColor(.dddIvory.opacity(0.65))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    TimePill(label: plan.durationLabel)
                    TimePill(label: plan.dailyTimeLabel)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.dddGold.opacity(0.6))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dddSurfaceBlack.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.dddGold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Filtered Plan Row (full-width, in filter results)

private struct FilteredPlanRow: View {
    @EnvironmentObject var planStore: PlanStore
    let plan: ReadingPlan

    private var isActive: Bool { planStore.activePlanId == plan.id }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? Color.dddGold.opacity(0.2) : Color.white.opacity(0.06))
                    .frame(width: 44, height: 44)
                Image(systemName: plan.category.icon)
                    .font(.callout)
                    .foregroundColor(isActive ? .dddGold : .dddIvory.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(plan.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.dddIvory)
                    if isActive {
                        ActiveDot()
                    }
                }
                Text(plan.hook)
                    .font(.caption)
                    .foregroundColor(.dddIvory.opacity(0.55))
                    .lineLimit(1)
                HStack(spacing: 10) {
                    TimePill(label: plan.durationLabel)
                    TimePill(label: plan.dailyTimeLabel)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.dddIvory.opacity(0.3))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.dddSurfaceBlack.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isActive ? Color.dddGold.opacity(0.5) : Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

// MARK: - Category Section

private struct PlanCategorySection: View {
    let category: PlanCategory
    let plans: [ReadingPlan]
    @Binding var selectedPlan: ReadingPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .foregroundColor(.dddGold)
                Text(category.rawValue)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.dddIvory)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(plans) { plan in
                        Button { selectedPlan = plan } label: {
                            PlanCard(plan: plan)
                        }
                        .buttonStyle(PlanCardButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: - Plan Card (horizontal scroll tile)

struct PlanCard: View {
    @EnvironmentObject var planStore: PlanStore
    let plan: ReadingPlan

    private var isActive: Bool { planStore.activePlanId == plan.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: plan.category.icon)
                    .font(.caption)
                    .foregroundColor(.dddGold)
                Spacer()
                DifficultyBadge(difficulty: plan.difficulty)
            }

            Spacer()

            Text(plan.title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.dddIvory)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(plan.hook)
                .font(.caption)
                .foregroundColor(.dddIvory.opacity(0.6))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                TimePill(label: plan.durationLabel)
                TimePill(label: plan.dailyTimeLabel)
            }

            if isActive {
                ActiveDot(label: "In Progress")
            }
        }
        .padding(14)
        .frame(width: 186, height: 176)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isActive ? 0.12 : 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isActive ? Color.dddGold.opacity(0.65) : Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: PlanDifficulty

    private var color: Color {
        switch difficulty {
        case .light:    return .green
        case .moderate: return .orange
        case .deep:     return .red
        }
    }

    private var timeLabel: String {
        switch difficulty {
        case .light:    return "~5–10 min"
        case .moderate: return "~10–15 min"
        case .deep:     return "~15–20 min"
        }
    }

    var body: some View {
        Text(timeLabel)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

// MARK: - Shared Small Components

struct TimePill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.dddIvory.opacity(0.8))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.13))
            .cornerRadius(6)
    }
}

struct ActiveDot: View {
    var label: String = ""

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.green).frame(width: 6, height: 6)
            if !label.isEmpty {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.green)
            }
        }
    }
}

#Preview {
    PlansView()
        .environmentObject(PlanStore.shared)
}
