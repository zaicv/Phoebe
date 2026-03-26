import SwiftUI
import Auth

private enum SettingsSection: String, CaseIterable, Identifiable {
    case profile = "Profile"
    case account = "Account"
    case app = "App"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle"
        case .account: return "person.badge.key"
        case .app: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager

    @State private var selectedSection: SettingsSection? = .profile
    @State private var isSigningOut = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileCard
                    sectionCard
                    accountCard
                }
                .padding(20)
            }
            .navigationTitle(selectedSection?.rawValue ?? "Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                row(title: "Email", value: supabaseManager.session?.user.email ?? "Unknown")
                row(title: "User ID", value: supabaseManager.session?.user.id.uuidString ?? "Unknown")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var sectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedSection?.rawValue ?? "Section")
                .font(.headline)

            switch selectedSection {
            case .profile:
                row(title: "Status", value: "Signed in")
                row(title: "Data", value: "Synced with Supabase")
            case .account:
                row(title: "Session", value: supabaseManager.session == nil ? "None" : "Active")
                row(title: "Provider", value: "Email & Password")
            case .app:
                row(title: "App", value: "Phoebe")
                row(title: "Mode", value: "Multiplatform")
            case .none:
                EmptyView()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)

            Button(role: .destructive) {
                Task { await signOut() }
            } label: {
                if isSigningOut {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigningOut)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var cardBackground: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    private func signOut() async {
        isSigningOut = true
        errorMessage = nil
        do {
            try await supabaseManager.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningOut = false
    }
}
