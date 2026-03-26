import Foundation
import Combine
import Supabase

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    let client: SupabaseClient
    @Published var session: Session? = nil

    init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://mhdzzfhtvvlnkitnbqqr.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1oZHp6Zmh0dnZsbmtpdG5icXFyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwMzM2MjYsImV4cCI6MjA2NzYwOTYyNn0.ZFPdwDLxR8QuHoCXu8-uFJh9ECJ_jOVyQ5fCzph_eMo"
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
