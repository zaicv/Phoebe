import SwiftUI
import Auth

private enum SettingsSection: String, CaseIterable, Identifiable {
    case profile = "Profile"
    case appearance = "Appearance"
    case account = "Account"
    case app = "App"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle"
        case .appearance: return "paintbrush"
        case .account: return "person.badge.key"
        case .app: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var appState: AppState

    @State private var selectedSection: SettingsSection? = .appearance
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
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedSection {
                    case .profile:
                        profileSection
                    case .appearance:
                        appearanceSection
                    case .account:
                        accountSection
                    case .app:
                        appSection
                    case .none:
                        appearanceSection
                    }
                }
                .padding(20)
            }
            .navigationTitle(selectedSection?.rawValue ?? "Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var profileSection: some View {
        VStack(spacing: 16) {
            settingsCard("Profile") {
                row(title: "Email", value: supabaseManager.session?.user.email ?? "Unknown")
                row(title: "User ID", value: supabaseManager.session?.user.id.uuidString ?? "Unknown")
            }

            settingsCard("Status") {
                row(title: "Session", value: supabaseManager.session == nil ? "None" : "Active")
                row(title: "Provider", value: "Email & Password")
            }
        }
    }

    private var appearanceSection: some View {
        VStack(spacing: 16) {
            settingsCard("Theme") {
                Picker("Mode", selection: $appState.themeMode) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            settingsCard("Surfaces") {
                Picker("Material", selection: $appState.surfaceMaterial) {
                    ForEach(SurfaceMaterialMode.allCases) { material in
                        Text(material.label).tag(material)
                    }
                }

                Picker("Card Edges", selection: $appState.cardCornerMode) {
                    ForEach(SurfaceCornerMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                Picker("Button Edges", selection: $appState.buttonCornerMode) {
                    ForEach(SurfaceCornerMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Corner Radius")
                        Spacer()
                        Text("\(Int(appState.surfaceCornerRadius))")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $appState.surfaceCornerRadius, in: 0...36, step: 1)
                }
            }

            settingsCard("Accent") {
                ColorPicker("Accent Color", selection: accentBinding, supportsOpacity: false)
            }

            settingsCard("Preview") {
                RoundedRectangle(cornerRadius: appState.cardCornerRadius)
                    .fill(appState.surfaceFillStyle)
                    .frame(height: 120)
                    .overlay(
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Surface Preview")
                                .font(.headline)
                            HStack(spacing: 10) {
                                Text("Primary")
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(appState.accentColor)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: appState.buttonCornerRadius))

                                Text("Secondary")
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(appState.surfaceStrokeColor.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: appState.buttonCornerRadius))
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    )
            }
        }
    }

    private var accountSection: some View {
        settingsCard("Account") {
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
            .clipShape(RoundedRectangle(cornerRadius: appState.buttonCornerRadius))

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var appSection: some View {
        settingsCard("About") {
            row(title: "App", value: "Phoebe")
            row(title: "Mode", value: "Multiplatform")
            row(title: "Surface Material", value: appState.surfaceMaterial.label)
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: appState.cardCornerRadius)
                .fill(appState.surfaceFillStyle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: appState.cardCornerRadius)
                .stroke(appState.surfaceStrokeColor.opacity(0.35), lineWidth: 0.5)
        )
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

    private var accentBinding: Binding<Color> {
        Binding(
            get: { appState.accentColor },
            set: { appState.setAccentColor($0) }
        )
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
