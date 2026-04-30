import SwiftUI
import AVFoundation

@main
struct DeepDiveDevotionsApp: App {
    init() {
        configureAudioSession()
        configureAppearance()
    }

    /// Configure the AVAudioSession at launch — must happen before any playback
    /// so the system knows this is a background-audio app from the very start.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("[Audio] session init failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
