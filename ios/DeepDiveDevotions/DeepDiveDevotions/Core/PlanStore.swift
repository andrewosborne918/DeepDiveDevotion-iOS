import Foundation
import Combine

// MARK: - Persisted Progress

struct PlanProgress: Codable {
    let planId: String
    let startDate: Date
    var completedStepIds: Set<String>
    var completionDates: [String: Date]

    init(planId: String) {
        self.planId           = planId
        self.startDate        = Date()
        self.completedStepIds = []
        self.completionDates  = [:]
    }

    // Backward-compat: completionDates may be absent in older saved data
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        planId           = try c.decode(String.self, forKey: .planId)
        startDate        = try c.decode(Date.self, forKey: .startDate)
        completedStepIds = try c.decode(Set<String>.self, forKey: .completedStepIds)
        completionDates  = (try? c.decode([String: Date].self, forKey: .completionDates)) ?? [:]
    }

    var daysSinceStart: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
    }
}

// MARK: - Plan Store

final class PlanStore: ObservableObject {

    static let shared = PlanStore()

    @Published var activePlanId: String? {
        didSet { saveActivePlanId() }
    }

    @Published private(set) var progress: PlanProgress? {
        didSet { saveProgress() }
    }

    // Full catalog
    let catalog: [ReadingPlan] = ReadingPlan.all

    var activePlan: ReadingPlan? {
        guard let id = activePlanId else { return nil }
        return catalog.first { $0.id == id }
    }

    // MARK: Computed helpers

    var completedCount: Int {
        progress?.completedStepIds.count ?? 0
    }

    var currentDayIndex: Int {
        guard let plan = activePlan, let progress else { return 0 }
        // Find the first incomplete step
        for (i, step) in plan.steps.enumerated() {
            if !progress.completedStepIds.contains(step.id) { return i }
        }
        return plan.steps.count   // all done
    }

    var nextStep: PlanStep? {
        guard let plan = activePlan else { return nil }
        let idx = currentDayIndex
        guard idx < plan.steps.count else { return nil }
        return plan.steps[idx]
    }

    var isCompleted: Bool {
        guard let plan = activePlan else { return false }
        return completedCount >= plan.steps.count
    }

    var percentComplete: Double {
        guard let plan = activePlan, plan.totalDays > 0 else { return 0 }
        return Double(completedCount) / Double(plan.totalDays)
    }

    // MARK: Actions

    func startPlan(_ plan: ReadingPlan) {
        progress     = PlanProgress(planId: plan.id)
        activePlanId = plan.id
    }

    func abandonPlan() {
        activePlanId = nil
        progress     = nil
        UserDefaults.standard.removeObject(forKey: Keys.progress)
        UserDefaults.standard.removeObject(forKey: Keys.activePlanId)
    }

    func markStepComplete(_ step: PlanStep) {
        guard progress != nil else { return }
        progress!.completedStepIds.insert(step.id)
        progress!.completionDates[step.id] = Date()
    }

    func isStepComplete(_ step: PlanStep) -> Bool {
        progress?.completedStepIds.contains(step.id) ?? false
    }

    /// Wipe all progress (back to Day 1).
    func resetProgress() {
        guard progress != nil else { return }
        progress!.completedStepIds = []
        progress!.completionDates  = [:]
    }

    /// Mark all steps before `dayIndex` as complete, and clear everything from that day forward.
    func jumpToDay(_ dayIndex: Int) {
        guard let plan = activePlan, progress != nil else { return }
        progress!.completedStepIds = []
        progress!.completionDates  = [:]
        let target = min(max(dayIndex, 0), plan.steps.count)
        for i in 0..<target {
            let step = plan.steps[i]
            progress!.completedStepIds.insert(step.id)
            progress!.completionDates[step.id] = Date()
        }
    }

    /// Called when audio finishes — marks the plan's next step complete if book/chapter match.
    func markNextStepCompleteIfMatches(book: String, chapter: Int) {
        guard let step = nextStep,
              step.bookName.lowercased() == book.lowercased(),
              step.chapterNumber == chapter else { return }
        markStepComplete(step)
    }

    /// Consecutive days (ending today or yesterday) on which at least one step was completed.
    var currentStreak: Int {
        guard let progress, !progress.completionDates.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let days     = Set(progress.completionDates.values.map { calendar.startOfDay(for: $0) })
        // Allow streak to count if last completion was today or yesterday
        var check  = days.contains(today) ? today
                   : calendar.date(byAdding: .day, value: -1, to: today)!
        guard days.contains(check) else { return 0 }
        var streak = 0
        while days.contains(check) {
            streak += 1
            check   = calendar.date(byAdding: .day, value: -1, to: check)!
        }
        return streak
    }

    // MARK: Plans grouped by category

    func plans(for category: PlanCategory) -> [ReadingPlan] {
        catalog.filter { $0.category == category }
    }

    // MARK: Persistence

    private enum Keys {
        static let activePlanId = "plans.activePlanId"
        static let progress     = "plans.progress"
    }

    private init() {
        activePlanId = UserDefaults.standard.string(forKey: Keys.activePlanId)
        if let data = UserDefaults.standard.data(forKey: Keys.progress),
           let saved = try? JSONDecoder().decode(PlanProgress.self, from: data) {
            progress = saved
        }
    }

    private func saveActivePlanId() {
        if let id = activePlanId {
            UserDefaults.standard.set(id, forKey: Keys.activePlanId)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.activePlanId)
        }
    }

    private func saveProgress() {
        if let p = progress,
           let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: Keys.progress)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.progress)
        }
    }
}
