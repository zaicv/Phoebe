import SwiftUI

struct AppTile: Identifiable {
    let id = UUID()
    let label: String
    let icon: String // SF Symbol name
    let color: Color
    let destination: AppDestination
}

enum AppDestination {
    case rays
    case setpoint // placeholder
    case chat // placeholder — not built yet
    case settings
}

private let tiles: [AppTile] = [
    AppTile(label: "Rays", icon: "checklist", color: Color(hex: "#34C759"), destination: .rays),
    AppTile(label: "SetPoint", icon: "waveform.path.ecg", color: Color(hex: "#FF2D55"), destination: .setpoint),
    AppTile(label: "Phoebe", icon: "bubble.left", color: Color(hex: "#007AFF"), destination: .chat),
    AppTile(label: "Settings", icon: "gearshape", color: Color(hex: "#8E8E93"), destination: .settings),
]

struct HomeGrid: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var appState: AppState
    @State private var selectedDestination: AppDestination? = nil

    let columns = [GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 18)]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [appState.backgroundTopColor, appState.backgroundBottomColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Glow")
                            .font(.system(size: 34, weight: .light, design: .rounded))

                        Text("Your workspace")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(tiles) { tile in
                            Button {
                                selectedDestination = tile.destination
                            } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: appState.cardCornerRadius, style: .continuous)
                                            .fill(appState.surfaceFillStyle)
                                            .opacity(appState.surfaceFillOpacity)
                                            .frame(height: 84)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: appState.cardCornerRadius, style: .continuous)
                                                    .stroke(appState.surfaceStrokeColor.opacity(appState.borderOpacity), lineWidth: 0.6)
                                            )

                                        Image(systemName: tile.icon)
                                            .font(.system(size: 24, weight: .regular))
                                            .foregroundColor(tile.label == "Settings" ? appState.accentColor : tile.color)
                                    }

                                    Text(tile.label)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("Glow")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(item: $selectedDestination) { destination in
                switch destination {
                case .rays:
                    RaysView()
                case .setpoint:
                    Text("SetPoint — coming soon")
                case .chat:
                    Text("Phoebe — coming soon")
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}
