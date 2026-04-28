import SwiftUI
import AVFoundation

@main
struct DeepDiveDevotionsApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var storeManager = StoreKitManager.shared

    init() {
        setupAudioSession()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(audioPlayer)
                .environmentObject(storeManager)
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowAirPlay, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AVAudioSession error: \(error)")
        }
    }

    private func configureAppearance() {
        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.dddSurfaceBlack)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.dddIvory)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.dddIvory)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        // Tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.dddSurfaceBlack)
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.dddGoldLight.opacity(0.62))
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.dddGoldLight.opacity(0.62)),
        ]
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.dddGold)
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.dddGold),
        ]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(Color.dddGold)
    }
}
