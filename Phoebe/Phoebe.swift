import SwiftUI

@main
struct Phoebe: App {
    @StateObject private var supabaseManager = SupabaseManager()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AuthGate()
                .environmentObject(supabaseManager)
                .environmentObject(appState)
                .tint(appState.accentColor)
                .preferredColorScheme(appState.preferredColorScheme)
        }
    }
}
