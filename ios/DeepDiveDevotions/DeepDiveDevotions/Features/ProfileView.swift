import SwiftUI
import UserNotifications

struct ProfileView: View {
    @EnvironmentObject private var planStore: PlanStore

    @AppStorage("notifications_enabled") private var notificationsEnabled = false
    @AppStorage("reminder_hour")         private var reminderHour         = 7
    @AppStorage("reminder_minute")       private var reminderMinute        = 0

    @State private var showTimePicker      = false
    @State private var notifPermDenied     = false
    @State private var selectedPlan: ReadingPlan?

    private var reminderTimeLabel: String {
        let h = reminderHour
        let m = reminderMinute
        let suffix = h >= 12 ? "PM" : "AM"
        let displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", displayH, m, suffix)
    }

    // App version from bundle
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dddSurfaceNavy.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        profileHeader

                        // ── Stats row ──
                        statsRow
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)

                        // ── Active Journey card ──
                        if let plan = planStore.activePlan {
                            sectionHeader("Active Journey")
                            activePlanCard(plan: plan)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 28)
                        }

                        // ── Daily reminder ──
                        sectionHeader("Daily Reminder")
                        reminderSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)

                        // ── About ──
                        sectionHeader("About")
                        aboutSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 60)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedPlan) { plan in
                PlanDetailView(plan: plan)
                    .environmentObject(planStore)
            }
            .alert("Notifications Blocked", isPresented: $notifPermDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications in Settings to receive daily reminders.")
            }
        }
    }

    // MARK: Header

    private var profileHeader: some View {
        VStack(spacing: 6) {
            Text("✦")
                .font(.system(size: 13))
                .foregroundColor(.dddGold)
                .padding(.top, 60)

            ZStack {
                Circle()
                    .fill(Color.dddGold.opacity(0.12))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().strokeBorder(Color.dddGold.opacity(0.35), lineWidth: 1.5))
                Image(systemName: "person.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.dddGoldLight)
            }

            Text("Deep Dive Reader")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(.dddIvory)

            if planStore.currentStreak > 0 {
                HStack(spacing: 5) {
                    Text("🔥")
                        .font(.subheadline)
                    Text("\(planStore.currentStreak)-day streak")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.dddGold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.dddGold.opacity(0.1))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.dddGold.opacity(0.3), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }

    // MARK: Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                icon:  "flame.fill",
                value: "\(planStore.currentStreak)",
                label: "Day Streak",
                color: .orange
            )
            statCard(
                icon:  "checkmark.circle.fill",
                value: "\(planStore.completedCount)",
                label: "Completed",
                color: .dddGold
            )
            statCard(
                icon:  "percent",
                value: planStore.activePlan != nil ? "\(Int(planStore.percentComplete * 100))%" : "—",
                label: "Progress",
                color: .green
            )
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.dddIvory)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.dddIvory.opacity(0.5))
                .textCase(.uppercase)
                .kerning(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: Active Plan Card

    private func activePlanCard(plan: ReadingPlan) -> some View {
        Button { selectedPlan = plan } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.dddGold.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: plan.category.icon)
                        .foregroundColor(.dddGold)
                        .font(.callout)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
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

                    ProgressView(value: planStore.percentComplete)
                        .tint(.dddGold)
                        .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.dddGold.opacity(0.6))
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.dddGold.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Daily Reminder

    private var reminderSection: some View {
        VStack(spacing: 0) {
            // Toggle row
            settingsRow {
                Toggle(isOn: Binding(
                    get: { notificationsEnabled },
                    set: { newVal in toggleNotifications(newVal) }
                )) {
                    Label("Daily Reminder", systemImage: "bell.fill")
                        .foregroundColor(.dddIvory)
                }
                .tint(.dddGold)
            }

            if notificationsEnabled {
                Divider().background(Color.white.opacity(0.08))

                // Time row
                settingsRow {
                    Button {
                        showTimePicker.toggle()
                    } label: {
                        HStack {
                            Label("Reminder Time", systemImage: "clock")
                                .foregroundColor(.dddIvory)
                            Spacer()
                            Text(reminderTimeLabel)
                                .font(.subheadline)
                                .foregroundColor(.dddGold)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.dddIvory.opacity(0.3))
                        }
                    }
                    .buttonStyle(.plain)
                }

                if showTimePicker {
                    Divider().background(Color.white.opacity(0.08))
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                var comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
                                comps.hour = reminderHour
                                comps.minute = reminderMinute
                                return Calendar.current.date(from: comps) ?? Date()
                            },
                            set: { date in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                                reminderHour   = comps.hour   ?? 7
                                reminderMinute = comps.minute ?? 0
                                scheduleNotification()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                }
            }
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: About

    private var aboutSection: some View {
        VStack(spacing: 0) {
            aboutRow(icon: "book.fill", label: "Deep Dive Devotions") {
                Text("One Chapter. Every Day.")
                    .font(.caption)
                    .foregroundColor(.dddIvory.opacity(0.45))
            }

            Divider().background(Color.white.opacity(0.08))

            aboutRow(icon: "info.circle", label: "Version") {
                Text(appVersion)
                    .font(.subheadline)
                    .foregroundColor(.dddIvory.opacity(0.5))
            }

            Divider().background(Color.white.opacity(0.08))

            aboutRow(icon: "star.fill", label: "Rate the App") {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.dddIvory.opacity(0.3))
            }

            Divider().background(Color.white.opacity(0.08))

            aboutRow(icon: "square.and.arrow.up", label: "Share with a Friend") {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.dddIvory.opacity(0.3))
            }
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.5)
            .textCase(.uppercase)
            .foregroundColor(.dddIvory.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    private func aboutRow<Trailing: View>(icon: String, label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.dddIvory)
                .font(.subheadline)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Notification Logic

    private func toggleNotifications(_ enabled: Bool) {
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        notificationsEnabled = true
                        scheduleNotification()
                    } else {
                        notificationsEnabled = false
                        notifPermDenied = true
                    }
                }
            }
        } else {
            notificationsEnabled = false
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["ddd.daily.reminder"])
        }
    }

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["ddd.daily.reminder"])

        let content = UNMutableNotificationContent()
        content.title  = "Time to Dive In 📖"
        content.body   = "Your daily chapter is waiting. One reading at a time."
        content.sound  = .default

        var comps = DateComponents()
        comps.hour   = reminderHour
        comps.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "ddd.daily.reminder", content: content, trigger: trigger)
        center.add(request)
    }
}
