import SwiftUI

struct AuthGate: View {
    @EnvironmentObject var supabaseManager: SupabaseManager

    var body: some View {
        if supabaseManager.session != nil {
            HomeGrid()
        } else {
            LoginView()
        }
    }
}
