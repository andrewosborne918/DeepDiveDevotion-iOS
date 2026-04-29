import SwiftUI

@main
struct DeepDiveDevotionsApp: App {
    init() {
        configureAppearance()
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
