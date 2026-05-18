import SwiftUI

@main
struct TracqerApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.api != nil {
            CollectionView()
        } else {
            LoginView()
        }
    }
}
