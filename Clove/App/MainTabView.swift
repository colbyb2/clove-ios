import SwiftUI

struct MainTabView: View {
    @State private var navigationCoordinator = NavigationCoordinator.shared
    
    var body: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            NavigationStack {
                TodayView()
                    .environment(navigationCoordinator)
            }
            .tabItem {
                Label("Today", systemImage: "calendar")
            }
            .tag(0)

            NavigationStack {
               InsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(1)

            NavigationStack {
               HistoryCalendarView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(2)

            NavigationStack {
               SearchView()
                    .environment(navigationCoordinator)
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(3)

            NavigationStack {
               SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(4)
        }
        .tint(Theme.shared.accent)
        .onAppear {
            // Customize TabBar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            
            // Add subtle shadow
            appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
            appearance.shadowImage = UIImage()
            
            // Customize background
            appearance.backgroundColor = UIColor.systemBackground
            
            // Customize normal tab appearance
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular)
            ]
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            
            // Customize selected tab appearance
            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
            ]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
            
            // Apply appearance to both standard and scrollEdge appearances
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}
