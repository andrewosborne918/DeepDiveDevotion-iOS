import SwiftUI

struct ContentView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var planStore = PlanStore.shared
    @State private var selectedTab = 0
    @State private var showNowPlaying = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(onBrowseAll: { selectedTab = 1 })
                    .environmentObject(planStore)
                    .tabItem { Label("Today", systemImage: "sun.max") }
                    .tag(0)

                ChaptersView()
                    .tabItem { Label("Browse", systemImage: "books.vertical") }
                    .tag(1)

                PlansView()
                    .environmentObject(planStore)
                    .tabItem { Label("Journey", systemImage: "map") }
                    .tag(2)

                ProfileView()
                    .environmentObject(planStore)
                    .environmentObject(player)
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(3)
            }
            .tint(.dddGold)

            if let nowPlaying = player.currentEpisode {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nowPlaying.title)
                            .lineLimit(1)
                            .font(.subheadline)
                            .foregroundStyle(Color.dddIvory)
                        Text(nowPlaying.scriptureReference ?? "Deep Dive Devotions")
                            .font(.caption)
                            .foregroundStyle(Color.dddGoldLight)
                    }
                    Spacer()
                    Button {
                        player.toggle()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundStyle(Color.dddGold)
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dddSurfaceNavy.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dddGold.opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12)
                .padding(.bottom, 64)
                .onTapGesture {
                    showNowPlaying = true
                }
                .sheet(isPresented: $showNowPlaying) {
                    NavigationStack {
                        EpisodeDetailView(episode: nowPlaying)
                    }
                    .environmentObject(player)
                }
            }
        }
        .environmentObject(player)
    }
}
