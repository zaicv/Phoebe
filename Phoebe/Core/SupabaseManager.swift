import Foundation
import Combine
import Supabase

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    let client: SupabaseClient
    @Published var session: Session? = nil

    init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "YOUR_SUPABASE_URL")!,
            supabaseKey: "YOUR_SUPABASE_ANON_KEY"
        )

        Task {
            await restoreSession()
        }
    }

    @MainActor
    func restoreSession() async {
        do {
            let session = try await client.auth.session
            self.session = session
        } catch {
            self.session = nil
        }
    }

    @MainActor
    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        self.session = session
    }

    @MainActor
    func signOut() async throws {
        try await client.auth.signOut()
        self.session = nil
    }
}
