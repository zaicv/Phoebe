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

    let columns = [GridItem(.adaptive(minimum: 80, maximum: 100))]

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(tiles) { tile in
                    Button {
                        selectedDestination = tile.destination
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: appState.cardCornerRadius)
                                    .fill(appState.surfaceFillStyle)
                                    .frame(width: 65, height: 65)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: appState.cardCornerRadius)
                                            .stroke(tile.color.opacity(0.25), lineWidth: 0.5)
                                    )

                                Image(systemName: tile.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(tile.label == "Settings" ? appState.accentColor : tile.color)
                            }

                            Text(tile.label)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .navigationTitle("Glow")
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
