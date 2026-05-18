import SwiftUI

@main
struct TracqerApp: App {

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.api != nil {
            CollectionView()
        } else {
            LoginView()
        }
    }
}
