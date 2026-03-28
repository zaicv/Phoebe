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
    case vault
    case setpoint // placeholder
    case chat // placeholder — not built yet
    case settings
}

private let tiles: [AppTile] = [
    AppTile(label: "Rays", icon: "checklist", color: Color(hex: "#34C759"), destination: .rays),
    AppTile(label: "Vault", icon: "film.stack", color: Color(hex: "#5AC8FA"), destination: .vault),
    AppTile(label: "SetPoint", icon: "waveform.path.ecg", color: Color(hex: "#FF2D55"), destination: .setpoint),
    AppTile(label: "Phoebe", icon: "bubble.left", color: Color(hex: "#007AFF"), destination: .chat),
    AppTile(label: "Settings", icon: "gearshape", color: Color(hex: "#8E8E93"), destination: .settings),
]

struct HomeGrid: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDestination: AppDestination? = nil

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let metrics = layoutMetrics(for: geo.size)
                ZStack(alignment: .bottom) {
                    wallpaper

                    VStack(spacing: 0) {
                        Spacer(minLength: geo.size.height * metrics.topSpacerRatio)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: metrics.tileSlotWidth, maximum: metrics.tileSlotWidth), spacing: metrics.gridSpacing)],
                            alignment: .leading,
                            spacing: metrics.gridSpacing
                        ) {
                            ForEach(tiles) { tile in
                                springboardIcon(for: tile, metrics: metrics)
                            }
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: metrics.bottomGap)
                        dock(metrics: metrics)
                    }
                }
                .ignoresSafeArea()
                .animation(appState.enableMotionEffects ? .spring(response: 0.35, dampingFraction: 0.85) : nil, value: appState.iconScale)
                .animation(appState.enableMotionEffects ? .spring(response: 0.35, dampingFraction: 0.85) : nil, value: appState.dockScale)
                .animation(appState.enableMotionEffects ? .easeInOut(duration: 0.22) : nil, value: appState.showDock)
                .animation(appState.enableMotionEffects ? .easeInOut(duration: 0.22) : nil, value: appState.showAppLabels)
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(item: $selectedDestination) { destination in
                switch destination {
                case .rays:
                    RaysView()
                case .vault:
                    VaultView()
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

    private var wallpaper: some View {
        ZStack {
            switch appState.wallpaperStyle {
            case .aurora:
                LinearGradient(
                    colors: [Color(hex: "#4CB0F7"), Color(hex: "#4D4BD6")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(hex: "#6BD6FF").opacity(0.35 * appState.wallpaperIntensity))
                    .frame(width: 540, height: 540)
                    .offset(x: -210, y: 230)
                    .blur(radius: 2 + appState.wallpaperBlur)

                Circle()
                    .fill(Color(hex: "#6AA3FF").opacity(0.36 * appState.wallpaperIntensity))
                    .frame(width: 620, height: 620)
                    .offset(x: 230, y: -120)
                    .blur(radius: 2 + appState.wallpaperBlur)
            case .gradient:
                LinearGradient(
                    colors: [
                        appState.accentColor.opacity(0.65 * appState.wallpaperIntensity),
                        Color(hex: "#151A2D")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: appState.wallpaperBlur)
            case .minimal:
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.16 + (0.14 * appState.wallpaperIntensity)),
                        Color.black.opacity(0.3 + (0.12 * appState.wallpaperIntensity))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private func springboardIcon(for tile: AppTile, metrics: HomeMetrics) -> some View {
        Button {
            selectedDestination = tile.destination
        } label: {
            VStack(spacing: metrics.labelGap) {
                ZStack {
                    RoundedRectangle(cornerRadius: metrics.iconCornerRadius, style: .continuous)
                        .fill(tile.color.gradient)
                        .frame(width: metrics.iconSize, height: metrics.iconSize)
                        .shadow(color: .black.opacity(0.18), radius: metrics.iconShadowRadius, x: 0, y: metrics.iconShadowY)

                    Image(systemName: tile.icon)
                        .font(.system(size: metrics.symbolSize, weight: .medium))
                        .foregroundColor(.white)
                }

                Text(tile.label)
                    .font(.system(size: metrics.labelSize * appState.spacingScale, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
                    .opacity(appState.showAppLabels ? 1 : 0)
            }
            .frame(width: metrics.tileSlotWidth)
            .overlay(alignment: .topTrailing) {
                if appState.showDesignDebugBadges {
                    Text("APP")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func dock(metrics: HomeMetrics) -> some View {
        HStack(spacing: 14 * appState.spacingScale) {
            ForEach(tiles) { tile in
                Button {
                    selectedDestination = tile.destination
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: metrics.dockIconCornerRadius, style: .continuous)
                            .fill(tile.color.gradient)
                            .frame(width: metrics.dockIconSize, height: metrics.dockIconSize)
                        Image(systemName: tile.icon)
                            .font(.system(size: metrics.dockSymbolSize, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, metrics.dockHorizontalPadding)
        .padding(.vertical, metrics.dockVerticalPadding)
        .background(
            dockBackground(cornerRadius: metrics.iconCornerRadius)
        )
        .padding(.bottom, metrics.dockBottomPadding)
        .opacity(appState.showDock ? 1 : 0)
        .allowsHitTesting(appState.showDock)
    }

    @ViewBuilder
    private func dockBackground(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch appState.dockStyle {
        case .liquid:
            if #available(iOS 26, macOS 26, *), appState.enableExperimentalGlass {
                shape
                    .fill(Color.clear)
                    .glassEffect(.regular.interactive(), in: shape)
                    .opacity(appState.dockOpacity)
                    .overlay(shape.stroke(appState.surfaceStrokeColor.opacity(appState.borderOpacity), lineWidth: appState.surfaceStrokeWidth))
            } else {
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(appState.dockOpacity)
                    .overlay(shape.stroke(appState.surfaceStrokeColor.opacity(appState.borderOpacity), lineWidth: appState.surfaceStrokeWidth))
            }
        case .flat:
            shape
                .fill(Color.black.opacity(0.18 + (0.2 * appState.dockOpacity)))
                .overlay(shape.stroke(appState.surfaceStrokeColor.opacity(appState.borderOpacity), lineWidth: appState.surfaceStrokeWidth))
        case .accent:
            shape
                .fill(appState.accentColor.opacity(0.2 + (0.35 * appState.dockOpacity)))
                .overlay(shape.stroke(appState.accentColor.opacity(0.35), lineWidth: appState.surfaceStrokeWidth))
        }
    }

    private func layoutMetrics(for size: CGSize) -> HomeMetrics {
        let minSide = min(size.width, size.height)
        let isCompact = minSide < 700
        let isLarge = minSide > 1050

        if isCompact {
            return scaledMetrics(HomeMetrics(
                iconSize: 56,
                symbolSize: 24,
                iconCornerRadius: 16,
                labelSize: 11,
                labelGap: 6,
                tileSlotWidth: 76,
                gridSpacing: 20,
                horizontalPadding: 24,
                topSpacerRatio: 0.06,
                bottomGap: 12,
                dockIconSize: 46,
                dockSymbolSize: 18,
                dockIconCornerRadius: 14,
                dockHorizontalPadding: 14,
                dockVerticalPadding: 10,
                dockBottomPadding: 18,
                iconShadowRadius: 5,
                iconShadowY: 3
            ))
        }

        if isLarge {
            return scaledMetrics(HomeMetrics(
                iconSize: 72,
                symbolSize: 31,
                iconCornerRadius: 22,
                labelSize: 13,
                labelGap: 9,
                tileSlotWidth: 96,
                gridSpacing: 28,
                horizontalPadding: 42,
                topSpacerRatio: 0.09,
                bottomGap: 26,
                dockIconSize: 56,
                dockSymbolSize: 22,
                dockIconCornerRadius: 17,
                dockHorizontalPadding: 24,
                dockVerticalPadding: 13,
                dockBottomPadding: 30,
                iconShadowRadius: 7,
                iconShadowY: 4
            ))
        }

        return scaledMetrics(HomeMetrics(
            iconSize: 64,
            symbolSize: 27,
            iconCornerRadius: 20,
            labelSize: 12,
            labelGap: 8,
            tileSlotWidth: 88,
            gridSpacing: 24,
            horizontalPadding: 36,
            topSpacerRatio: 0.08,
            bottomGap: 20,
            dockIconSize: 52,
            dockSymbolSize: 21,
            dockIconCornerRadius: 16,
            dockHorizontalPadding: 20,
            dockVerticalPadding: 12,
            dockBottomPadding: 26,
            iconShadowRadius: 6,
            iconShadowY: 4
        ))
    }

    private func scaledMetrics(_ metrics: HomeMetrics) -> HomeMetrics {
        let iconScale = appState.effectiveIconScale
        let dockScale = appState.effectiveDockScale

        return HomeMetrics(
            iconSize: metrics.iconSize * iconScale,
            symbolSize: metrics.symbolSize * iconScale,
            iconCornerRadius: metrics.iconCornerRadius * iconScale,
            labelSize: metrics.labelSize * CGFloat(appState.uiScale),
            labelGap: metrics.labelGap * appState.spacingScale,
            tileSlotWidth: metrics.tileSlotWidth * iconScale,
            gridSpacing: metrics.gridSpacing * appState.spacingScale,
            horizontalPadding: metrics.horizontalPadding * appState.spacingScale,
            topSpacerRatio: metrics.topSpacerRatio,
            bottomGap: metrics.bottomGap * appState.spacingScale,
            dockIconSize: metrics.dockIconSize * dockScale,
            dockSymbolSize: metrics.dockSymbolSize * dockScale,
            dockIconCornerRadius: metrics.dockIconCornerRadius * dockScale,
            dockHorizontalPadding: metrics.dockHorizontalPadding * dockScale,
            dockVerticalPadding: metrics.dockVerticalPadding * dockScale,
            dockBottomPadding: metrics.dockBottomPadding * dockScale,
            iconShadowRadius: metrics.iconShadowRadius * iconScale,
            iconShadowY: metrics.iconShadowY * iconScale
        )
    }
}

private struct HomeMetrics {
    let iconSize: CGFloat
    let symbolSize: CGFloat
    let iconCornerRadius: CGFloat
    let labelSize: CGFloat
    let labelGap: CGFloat
    let tileSlotWidth: CGFloat
    let gridSpacing: CGFloat
    let horizontalPadding: CGFloat
    let topSpacerRatio: CGFloat
    let bottomGap: CGFloat
    let dockIconSize: CGFloat
    let dockSymbolSize: CGFloat
    let dockIconCornerRadius: CGFloat
    let dockHorizontalPadding: CGFloat
    let dockVerticalPadding: CGFloat
    let dockBottomPadding: CGFloat
    let iconShadowRadius: CGFloat
    let iconShadowY: CGFloat
}
