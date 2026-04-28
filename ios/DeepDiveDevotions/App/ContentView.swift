import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer

    var body: some View {
        ZStack(alignment: .bottom) {
            MainTabView()

            // Persistent mini player above tab bar
            MiniPlayerView()
                .zIndex(100)
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView {
                selectedTab = 1
            }
                .tag(0)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            NavigationStack {
                BrowseView()
            }
            .tag(1)
            .tabItem {
                Label("Chapters", systemImage: "book")
            }

            LibraryView()
                .tag(2)
                .tabItem {
                    Label("Library", systemImage: "headphones")
                }

            NavigationStack {
                AccountView()
            }
            .tag(3)
            .tabItem {
                Label("Profile", systemImage: "person")
                }
        }
        .accentColor(.dddGold)
    }
}
