import SwiftUI

// MARK: - Bible.com USFM book abbreviations
private let usfmAbbreviations: [String: String] = [
    "genesis": "GEN", "exodus": "EXO", "leviticus": "LEV", "numbers": "NUM",
    "deuteronomy": "DEU", "joshua": "JOS", "judges": "JDG", "ruth": "RUT",
    "1 samuel": "1SA", "2 samuel": "2SA", "1 kings": "1KI", "2 kings": "2KI",
    "1 chronicles": "1CH", "2 chronicles": "2CH", "ezra": "EZR", "nehemiah": "NEH",
    "esther": "EST", "job": "JOB", "psalms": "PSA", "psalm": "PSA",
    "proverbs": "PRO", "ecclesiastes": "ECC", "song of solomon": "SNG",
    "song of songs": "SNG", "isaiah": "ISA", "jeremiah": "JER",
    "lamentations": "LAM", "ezekiel": "EZK", "daniel": "DAN", "hosea": "HOS",
    "joel": "JOL", "amos": "AMO", "obadiah": "OBA", "jonah": "JON",
    "micah": "MIC", "nahum": "NAH", "habakkuk": "HAB", "zephaniah": "ZEP",
    "haggai": "HAG", "zechariah": "ZEC", "malachi": "MAL",
    "matthew": "MAT", "mark": "MRK", "luke": "LUK", "john": "JHN",
    "acts": "ACT", "romans": "ROM", "1 corinthians": "1CO", "2 corinthians": "2CO",
    "galatians": "GAL", "ephesians": "EPH", "philippians": "PHP", "colossians": "COL",
    "1 thessalonians": "1TH", "2 thessalonians": "2TH", "1 timothy": "1TI",
    "2 timothy": "2TI", "titus": "TIT", "philemon": "PHM", "hebrews": "HEB",
    "james": "JAS", "1 peter": "1PE", "2 peter": "2PE", "1 john": "1JN",
    "2 john": "2JN", "3 john": "3JN", "jude": "JUD", "revelation": "REV"
]

struct EpisodeDetailView: View {
    let episode: Episode

    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @State private var fullEpisode: Episode?
    @State private var selectedTab = 0
    @State private var error: String?
    @State private var showPaywall = false
    @State private var isDownloaded = false
    @State private var isDownloading = false

    private var displayEpisode: Episode { fullEpisode ?? episode }

    // Step in the active plan that matches this episode's book/chapter (complete or not)
    private var matchingPlanStep: PlanStep? {
        guard let book = displayEpisode.bookName,
              let chapter = displayEpisode.chapterNumber,
              let plan = planStore.activePlan else { return nil }
        return plan.steps.first {
            $0.bookName.lowercased() == book.lowercased() && $0.chapterNumber == chapter
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.dddSurfaceBlack, Color.dddSurfaceNavy, Color.dddSurfaceBlack], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    AsyncImage(url: displayEpisode.thumbnailURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.25))
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dddGold.opacity(0.45), lineWidth: 1))

                    Text(displayEpisode.scriptureReference ?? displayEpisode.title)
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundStyle(Color.dddIvory)
                        .multilineTextAlignment(.center)

                    Text(displayEpisode.title)
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.dddGoldLight)
                        .multilineTextAlignment(.center)

                    playbackBlock

                    downloadButton

                    // Plan completion button — shown when this episode is part of the active plan
                    if let step = matchingPlanStep {
                        planMarkCompleteButton(step: step)
                    }

                    HStack(spacing: 0) {
                        tabButton("Transcript", index: 0)
                        tabButton("About", index: 1)
                        tabButton("Bible", index: 2)
                    }
                    .background(Color.black.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if selectedTab == 0 {
                        transcriptView
                    } else if selectedTab == 1 {
                        Text(displayEpisode.description ?? "No description available")
                            .foregroundStyle(Color.dddIvory)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        bibleView
                    }

                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }
                .padding(20)
                .padding(.bottom, 120)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: player.finishedEpisodeId) { _, finishedId in
            guard let finishedId, finishedId == displayEpisode.id,
                  let step = matchingPlanStep,
                  !planStore.isStepComplete(step) else { return }
            planStore.markStepComplete(step)
        }
        .task {
            await loadEpisode()
            checkIfDownloaded()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .offlineDownload)
                .environmentObject(subscriptions)
        }
    }

    private var playbackBlock: some View {
        VStack(spacing: 10) {
            Slider(value: Binding(
                get: { player.currentEpisode?.id == displayEpisode.id ? player.currentTime : 0 },
                set: { player.seek(to: $0) }
            ), in: 0...max(player.currentEpisode?.id == displayEpisode.id ? player.duration : 1, 1))
            .tint(.dddGold)

            HStack {
                Text(format(player.currentEpisode?.id == displayEpisode.id ? player.currentTime : 0))
                Spacer()
                Text(format(player.currentEpisode?.id == displayEpisode.id ? player.duration : 0))
            }
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.dddGoldLight)

            HStack(spacing: 30) {
                Button { player.skip(-15) } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.dddGoldLight)
                }

                Button {
                    if player.currentEpisode?.id == displayEpisode.id {
                        player.toggle()
                    } else {
                        player.play(episode: displayEpisode)
                    }
                } label: {
                    Circle()
                        .fill(Color.dddGoldLight)
                        .frame(width: 90, height: 90)
                        .overlay(
                            Image(systemName: player.currentEpisode?.id == displayEpisode.id && player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.dddSurfaceBlack)
                        )
                }

                Button { player.skip(15) } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.dddGoldLight)
                }
            }

            HStack(spacing: 20) {
                Button {
                    let steps: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
                    if let idx = steps.firstIndex(where: { abs($0 - player.playbackRate) < 0.01 }), idx > 0 {
                        player.setRate(steps[idx - 1])
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.dddGoldLight)
                }
                .buttonStyle(.plain)

                let rate = Double(player.playbackRate)
                Text(rate == 1.0 ? "1x" : String(format: "%.2gx", rate))
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.dddSurfaceBlack)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.dddGoldLight))

                Button {
                    let steps: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
                    if let idx = steps.firstIndex(where: { abs($0 - player.playbackRate) < 0.01 }), idx < steps.count - 1 {
                        player.setRate(steps[idx + 1])
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.dddGoldLight)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Plan Mark Complete Button

    @ViewBuilder
    private func planMarkCompleteButton(step: PlanStep) -> some View {
        let isComplete = planStore.isStepComplete(step)
        Button {
            if !isComplete {
                planStore.markStepComplete(step)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.title3)
                Text(isComplete ? "Chapter Complete" : "Mark Complete")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(isComplete ? .green : .dddSurfaceBlack)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                if isComplete {
                    RoundedRectangle(cornerRadius: 14).fill(Color.green.opacity(0.15))
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(
                        LinearGradient(colors: [Color.dddGold, Color.dddGoldLight], startPoint: .leading, endPoint: .trailing)
                    )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isComplete ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .disabled(isComplete)
        .animation(.easeInOut(duration: 0.2), value: isComplete)
    }

    // MARK: Bible View

    private var bibleView: some View {
        let book    = displayEpisode.bookName ?? ""
        let chapter = displayEpisode.chapterNumber ?? 1
        let abbr    = usfmAbbreviations[book.lowercased()] ?? book.uppercased()
        let urlStr  = "https://www.bible.com/bible/1/\(abbr).\(chapter)"
        let url     = URL(string: urlStr)!

        return VStack(spacing: 16) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 40))
                .foregroundColor(.dddGoldLight)

            VStack(spacing: 4) {
                Text("Read \(book) \(chapter)")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.dddIvory)
                Text("Open in Bible.com")
                    .font(.subheadline)
                    .foregroundColor(.dddIvory.opacity(0.5))
            }

            Link(destination: url) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open Bible.com")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.dddSurfaceBlack)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.dddGold, Color.dddGoldLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .cornerRadius(14)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(14)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var transcriptView: some View {
        Group {
            if let transcript = displayEpisode.transcript, !transcript.isEmpty {
                Text(transcript)
                    .foregroundStyle(Color.dddIvory)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(14)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Transcript not available.")
                    .foregroundStyle(Color.dddGoldLight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .foregroundStyle(selectedTab == index ? Color.dddGold : Color.dddIvory.opacity(0.7))
                Rectangle().fill(selectedTab == index ? Color.dddGold : .clear).frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Download Button

    private var downloadButton: some View {
        Button {
            if subscriptions.isSubscribed {
                if isDownloaded {
                    deleteDownload()
                } else {
                    Task { await downloadEpisode() }
                }
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 10) {
                if isDownloading {
                    ProgressView().tint(.dddSurfaceBlack).scaleEffect(0.85)
                } else {
                    Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 18))
                }
                Text(isDownloaded ? "Downloaded" : (subscriptions.isSubscribed ? "Download for Offline" : "Download for Offline  🔒"))
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(isDownloaded ? .green : .dddSurfaceBlack)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDownloaded ? Color.green.opacity(0.15) : Color.dddGoldLight.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isDownloaded ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
    }

    // MARK: Download Helpers

    private static func downloadedFileURL(for episode: Episode) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("episode_\(episode.id).m4a")
    }

    private func checkIfDownloaded() {
        isDownloaded = FileManager.default.fileExists(
            atPath: Self.downloadedFileURL(for: displayEpisode).path
        )
    }

    private func downloadEpisode() async {
        guard let audioURL = displayEpisode.audioURL else { return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: audioURL)
            let dest = Self.downloadedFileURL(for: displayEpisode)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)
            isDownloaded = true
        } catch {
            self.error = "Download failed: \(error.localizedDescription)"
        }
    }

    private func deleteDownload() {
        let url = Self.downloadedFileURL(for: displayEpisode)
        try? FileManager.default.removeItem(at: url)
        isDownloaded = false
    }

    private func loadEpisode() async {
        do {
            fullEpisode = try await APIClient.shared.fetchEpisode(id: episode.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func format(_ sec: Double) -> String {
        guard sec.isFinite else { return "0:00" }
        let total = Int(sec)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
