import SwiftUI
import AVFoundation

@main
struct DeepDiveDevotionsApp: App {
    init() {
        configureAppearance()
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func configureAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.dddSurfaceBlack)
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.dddGoldLight.opacity(0.65))
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.dddGoldLight.opacity(0.65))]
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.dddGold)
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.dddGold)]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
