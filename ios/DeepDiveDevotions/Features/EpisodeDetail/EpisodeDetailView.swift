import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode
    @StateObject private var viewModel: EpisodeDetailViewModel
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss

    init(episode: Episode) {
        self.episode = episode
        _viewModel = StateObject(wrappedValue: EpisodeDetailViewModel(episode: episode))
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 16) {
                    AsyncThumbnailView(url: viewModel.displayEpisode.thumbnailURL, cornerRadius: 18)
                        .frame(height: 210)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.dddGold.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.horizontal, 10)

                    if let reference = viewModel.displayEpisode.scriptureReference {
                        Text(reference)
                            .font(.system(size: 46, weight: .bold, design: .serif))
                            .foregroundStyle(Color.dddIvory)
                            .multilineTextAlignment(.center)
                    }

                    Text(viewModel.displayEpisode.title)
                        .font(.system(size: 38, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.dddIvory)
                        .multilineTextAlignment(.center)

                    if let subtitle = viewModel.displayEpisode.description, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 17, weight: .medium, design: .serif))
                            .foregroundStyle(Color.dddGoldLight)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 20)
                    }

                    metadataRow
                    playbackSection
                    tabSelector
                    tabContent
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.dddSurfaceBlack, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.dddGoldLight)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                shareButton
            }
        }
        .task { await viewModel.loadDetails() }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.dddSurfaceBlack, Color.dddSurfaceNavy, Color.dddSurfaceBlack],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [Color.dddGold.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 300
            )
        )
        .ignoresSafeArea()
    }

    private var metadataRow: some View {
        HStack(spacing: 18) {
            metadataItem(icon: "calendar", value: viewModel.displayEpisode.formattedPublishDate ?? "")
            metadataItem(icon: "book", value: viewModel.displayEpisode.bookName ?? "")
            metadataItem(icon: "clock", value: durationLabel)
            metadataItem(icon: "arrow.down.circle", value: "Download")
        }
        .foregroundStyle(Color.dddGoldLight.opacity(0.95))
        .font(.system(size: 13, weight: .medium, design: .serif))
    }

    private func metadataItem(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(value)
        }
    }

    private var playbackSection: some View {
        VStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { playbackTime },
                    set: { audioPlayer.seek(to: $0) }
                ),
                in: 0...max(playbackDuration, 1)
            )
            .tint(.dddGold)

            HStack {
                Text(formatTime(playbackTime))
                Spacer()
                Text(formatTime(playbackDuration))
            }
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.dddGoldLight.opacity(0.85))

            HStack(spacing: 26) {
                Button { audioPlayer.skip(seconds: -15) } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.dddGoldLight)
                }

                Button { togglePlay() } label: {
                    Circle()
                        .fill(Color.dddGoldLight)
                        .frame(width: 92, height: 92)
                        .overlay {
                            Image(systemName: isCurrentAndPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.dddSurfaceBlack)
                                .padding(.leading, isCurrentAndPlaying ? 0 : 5)
                        }
                }

                Button { audioPlayer.skip(seconds: 15) } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.dddGoldLight)
                }
            }
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "Transcript", index: 0)
            tabButton(title: "Notes", index: 1)
        }
        .background(Color.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dddGold.opacity(0.35), lineWidth: 1)
        )
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(selectedTab == index ? Color.dddGold : Color.dddIvory.opacity(0.7))
                Rectangle()
                    .fill(selectedTab == index ? Color.dddGold : .clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
    }

    private var tabContent: some View {
        Group {
            if selectedTab == 0 {
                transcriptTab
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.dddIvory)
                    Text("Personal notes are coming soon.")
                        .foregroundStyle(Color.dddGoldLight.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var transcriptTab: some View {
        Group {
            if viewModel.isLoadingDetails {
                ProgressView("Loading transcript...")
                    .tint(.dddGold)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if let transcript = viewModel.displayEpisode.transcript {
                TranscriptView(text: transcript)
            } else {
                Text("Transcript not yet available for this episode.")
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(Color.dddGoldLight.opacity(0.8))
            }
        }
    }

    private var shareButton: some View {
        Button {
            let text = "\(viewModel.displayEpisode.title)\n\nDeep Dive Devotions"
            let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let vc = scene.windows.first?.rootViewController {
                vc.present(av, animated: true)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(Color.dddGoldLight)
        }
    }

    private var isCurrentEpisode: Bool {
        audioPlayer.currentEpisode?.id == viewModel.displayEpisode.id
    }

    private var isCurrentAndPlaying: Bool {
        isCurrentEpisode && audioPlayer.isPlaying
    }

    private var playbackTime: Double {
        isCurrentEpisode ? audioPlayer.currentTime : viewModel.savedPosition
    }

    private var playbackDuration: Double {
        if isCurrentEpisode {
            return max(audioPlayer.duration, 0)
        }
        return max(viewModel.savedPosition + 1, 1)
    }

    private var durationLabel: String {
        let seconds = isCurrentEpisode ? audioPlayer.duration : viewModel.savedPosition
        guard seconds > 0 else { return "-- min" }
        return "\(Int(seconds / 60)) min"
    }

    private func togglePlay() {
        if isCurrentEpisode {
            audioPlayer.togglePlayPause()
        } else {
            audioPlayer.play(
                episode: viewModel.displayEpisode,
                startAt: viewModel.savedPosition
            )
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
