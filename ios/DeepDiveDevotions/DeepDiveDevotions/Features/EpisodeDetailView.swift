import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode

    @EnvironmentObject private var player: AudioPlayerManager
    @State private var fullEpisode: Episode?
    @State private var selectedTab = 0
    @State private var error: String?

    private var displayEpisode: Episode { fullEpisode ?? episode }

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

                    HStack(spacing: 0) {
                        tabButton("Transcript", index: 0)
                        tabButton("About", index: 1)
                    }
                    .background(Color.black.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if selectedTab == 0 {
                        transcriptView
                    } else {
                        Text(displayEpisode.description ?? "No description available")
                            .foregroundStyle(Color.dddIvory)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .task {
            await loadEpisode()
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
