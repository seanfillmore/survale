import SwiftUI
import MapKit

struct MainTabsView: View {
    @State private var selectedTab = 0
    @State private var mapNavigationTarget: MapNavigationTarget?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            OperationsView()
                .tabItem { Label("Ops", systemImage: "target") }
                .tag(0)
            
            MapOperationView(navigationTarget: $mapNavigationTarget)
                .tabItem { Label("Map", systemImage: "map") }
                .tag(1)
            
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(2)
            
            ReplayView()
                .tabItem { Label("Replay", systemImage: "clock.arrow.circlepath") }
                .tag(3)
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        .environment(\.navigateToMap, { target in
            mapNavigationTarget = target
            selectedTab = 1
        })
    }
}

// MARK: - Map Navigation Support

struct MapNavigationTarget: Equatable {
    let coordinate: CLLocationCoordinate2D
    let label: String
    
    static func == (lhs: MapNavigationTarget, rhs: MapNavigationTarget) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.label == rhs.label
    }
}

private struct NavigateToMapKey: EnvironmentKey {
    static let defaultValue: (MapNavigationTarget) -> Void = { _ in }
}

extension EnvironmentValues {
    var navigateToMap: (MapNavigationTarget) -> Void {
        get { self[NavigateToMapKey.self] }
        set { self[NavigateToMapKey.self] = newValue }
    }
}
