import SwiftUI
import Auth

private enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case development = "Development"
    case profile = "Profile"
    case account = "Account"
    case app = "App"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush.pointed"
        case .development: return "hammer"
        case .profile: return "person.crop.circle"
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
            ZStack {
                LinearGradient(
                    colors: [appState.backgroundTopColor, appState.backgroundBottomColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    profileBadge
                        .padding(.top, 8)

                    List(SettingsSection.allCases, selection: $selectedSection) { section in
                        Label(section.rawValue, systemImage: section.icon)
                            .font(.system(size: appState.bodyFontSize, weight: .medium, design: .rounded))
                            .tag(section)
                    }
                    .scrollContentBackground(.hidden)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } detail: {
            ZStack {
                LinearGradient(
                    colors: [appState.backgroundTopColor, appState.backgroundBottomColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch selectedSection {
                        case .appearance:
                            appearanceSection
                        case .development:
                            developmentSection
                        case .profile:
                            profileSection
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
            }
            .navigationTitle(selectedSection?.rawValue ?? "Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var profileBadge: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(appState.accentColor.opacity(0.22))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(initials)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                )

            VStack(alignment: .leading, spacing: 1) {
                    Text(displayName)
                    .font(.system(size: appState.bodyFontSize, weight: .semibold, design: .rounded))
                Text("Phoebe Account")
                    .font(.system(size: max(10, appState.bodyFontSize - 2), weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(surfacePanel(cornerRadius: appState.cardCornerRadius))
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
            .disabled(appState.designLocked)

            settingsCard("Surface Style") {
                Picker("Material", selection: $appState.surfaceMaterial) {
                    ForEach(SurfaceMaterialMode.allCases) { material in
                        Text(material.label).tag(material)
                    }
                }
                .pickerStyle(.segmented)

                if appState.surfaceMaterial == .liquidGlass {
                    Picker("Glass Profile", selection: $appState.liquidMaterialProfile) {
                        ForEach(LiquidMaterialProfile.allCases) { material in
                            Text(material.label).tag(material)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    if appState.surfaceMaterial == .liquidGlass {
                        row(title: "Glass Intensity", value: String(format: "%.2f", appState.glassIntensity))
                        Slider(value: $appState.glassIntensity, in: 0.55...1.0, step: 0.01)
                    } else {
                        row(title: "Flat Depth", value: String(format: "%.2f", appState.flatSurfaceDepth))
                        Slider(value: $appState.flatSurfaceDepth, in: 0.70...1.0, step: 0.01)
                    }

                    row(title: "Border Strength", value: String(format: "%.2f", appState.borderOpacity))
                    Slider(value: $appState.borderOpacity, in: 0.10...0.80, step: 0.01)

                    row(title: "Shadow Strength", value: String(format: "%.2f", appState.shadowStrength))
                    Slider(value: $appState.shadowStrength, in: 0.0...1.0, step: 0.01)
                }
            }
            .disabled(appState.designLocked)

            settingsCard("Geometry") {
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
                    row(title: "Corner Radius", value: "\(Int(appState.surfaceCornerRadius))")
                    Slider(value: $appState.surfaceCornerRadius, in: 0...40, step: 1)
                }
            }
            .disabled(appState.designLocked)

            settingsCard("Typography & Density") {
                Picker("Density", selection: $appState.densityMode) {
                    ForEach(UIDensityMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    row(title: "UI Scale", value: String(format: "%.2f", appState.uiScale))
                    Slider(value: $appState.uiScale, in: 0.85...1.3, step: 0.01)
                }
            }
            .disabled(appState.designLocked)

            settingsCard("Background") {
                Picker("Wallpaper Style", selection: $appState.wallpaperStyle) {
                    ForEach(WallpaperStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    row(title: "Accent Blend", value: String(format: "%.2f", appState.backgroundBlend))
                    Slider(value: $appState.backgroundBlend, in: 0.0...1.0, step: 0.01)

                    row(title: "Wallpaper Intensity", value: String(format: "%.2f", appState.wallpaperIntensity))
                    Slider(value: $appState.wallpaperIntensity, in: 0.0...1.0, step: 0.01)

                    row(title: "Wallpaper Blur", value: String(format: "%.1f", appState.wallpaperBlur))
                    Slider(value: $appState.wallpaperBlur, in: 0...8, step: 0.5)
                }
            }
            .disabled(appState.designLocked)

            settingsCard("Springboard") {
                Toggle("Show app labels", isOn: $appState.showAppLabels)
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 8) {
                    row(title: "Icon Scale", value: String(format: "%.2f", appState.iconScale))
                    Slider(value: $appState.iconScale, in: 0.8...1.4, step: 0.01)
                }
            }
            .disabled(appState.designLocked)

            settingsCard("Dock") {
                Toggle("Show dock", isOn: $appState.showDock)
                    .toggleStyle(.switch)

                Picker("Dock Style", selection: $appState.dockStyle) {
                    ForEach(DockStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    row(title: "Dock Scale", value: String(format: "%.2f", appState.dockScale))
                    Slider(value: $appState.dockScale, in: 0.8...1.4, step: 0.01)

                    row(title: "Dock Opacity", value: String(format: "%.2f", appState.dockOpacity))
                    Slider(value: $appState.dockOpacity, in: 0.2...1.0, step: 0.01)
                }
            }
            .disabled(appState.designLocked)

            settingsCard("Accent") {
                ColorPicker("Accent Color", selection: accentBinding, supportsOpacity: false)

                HStack(spacing: 10) {
                    ForEach(accentPresets, id: \.self) { color in
                        Button {
                            appState.setAccentColor(color)
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: appState.surfaceStrokeWidth))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .disabled(appState.designLocked)

            settingsCard("Preview") {
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: appState.cardCornerRadius, style: .continuous)
                        .fill(appState.surfaceFillStyle)
                        .opacity(appState.surfaceFillOpacity)
                        .frame(height: 92)
                        .shadow(color: .black.opacity(0.12 * appState.shadowStrength), radius: appState.surfaceShadowRadius, x: 0, y: 2)
                        .overlay(
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Surface")
                                    .font(.system(size: appState.bodyFontSize + 1, weight: .semibold, design: .rounded))
                                Text("Minimal, layered, and adaptive.")
                                    .font(.system(size: max(11, appState.bodyFontSize - 1), weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: appState.cardCornerRadius, style: .continuous)
                                .stroke(appState.surfaceStrokeColor.opacity(appState.borderOpacity), lineWidth: appState.surfaceStrokeWidth)
                        )

                    HStack(spacing: 10) {
                        Text("Primary")
                            .font(.system(size: max(11, appState.bodyFontSize - 1), weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(appState.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: appState.buttonCornerRadius, style: .continuous))

                        Text("Secondary")
                            .font(.system(size: max(11, appState.bodyFontSize - 1), weight: .medium, design: .rounded))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: appState.buttonCornerRadius, style: .continuous)
                                    .fill(appState.surfaceFillStyle)
                                    .opacity(appState.surfaceFillOpacity)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: appState.buttonCornerRadius, style: .continuous)
                                    .stroke(appState.surfaceStrokeColor.opacity(appState.borderOpacity), lineWidth: appState.surfaceStrokeWidth)
                            )
                    }
                }
            }

            if appState.designLocked {
                settingsCard("Design Lock") {
                    Text("Design is locked. Open Development to unlock editing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var developmentSection: some View {
        VStack(spacing: 16) {
            settingsCard("Design Language") {
                Toggle("Lock appearance controls", isOn: $appState.designLocked)

                Picker("Preset", selection: $appState.selectedPreset) {
                    ForEach(DesignLanguagePreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }

                HStack(spacing: 10) {
                    Button("Apply Preset") {
                        appState.applySelectedPreset()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.designLocked)

                    Button("Reset Defaults") {
                        appState.resetAppearanceDefaults()
                    }
                    .buttonStyle(.bordered)
                    .disabled(appState.designLocked)
                }
            }

            settingsCard("Material Lab") {
                Toggle("Enable experimental glass rendering", isOn: $appState.enableExperimentalGlass)
                Toggle("Show design debug badges", isOn: $appState.showDesignDebugBadges)
                Toggle("Enable motion effects", isOn: $appState.enableMotionEffects)
            }

            settingsCard("Current Tokens") {
                row(title: "Material", value: appState.surfaceMaterial.label)
                row(title: "Material Profile", value: appState.liquidMaterialProfile.label)
                row(title: "Wallpaper", value: appState.wallpaperStyle.label)
                row(title: "Dock", value: appState.dockStyle.label)
                row(title: "Density", value: appState.densityMode.label)
                row(title: "Card Radius", value: "\(Int(appState.cardCornerRadius))")
                row(title: "Button Radius", value: "\(Int(appState.buttonCornerRadius))")
                row(title: "Scale", value: String(format: "%.2f", appState.uiScale))
            }
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
                        .font(.system(size: appState.bodyFontSize, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigningOut)
            .clipShape(RoundedRectangle(cornerRadius: appState.buttonCornerRadius, style: .continuous))

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
            row(title: "Surface", value: appState.surfaceMaterial.label)
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: appState.bodyFontSize + 1, weight: .semibold, design: .rounded))

            content()
        }
        .padding(16 * appState.spacingScale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surfacePanel(cornerRadius: appState.cardCornerRadius))
    }

    @ViewBuilder
    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .font(.system(size: appState.bodyFontSize, weight: .medium, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(size: appState.bodyFontSize, weight: .medium, design: .rounded))
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func surfacePanel(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if appState.surfaceMaterial == .liquidGlass {
            if #available(iOS 26, macOS 26, *), appState.enableExperimentalGlass {
                shape
                    .fill(Color.clear)
                    .glassEffect(.regular.interactive(), in: shape)
                    .overlay(shape.stroke(appState.surfaceStrokeColor.opacity(appState.borderOpacity), lineWidth: appState.surfaceStrokeWidth))
            } else {
                shape
                    .fill(appState.surfaceFillStyle)
                    .opacity(appState.surfaceFillOpacity)
                    .overlay(shape.stroke(appState.surfaceStrokeColor.opacity(appState.borderOpacity), lineWidth: appState.surfaceStrokeWidth))
            }
        } else {
            shape
                .fill(appState.surfaceFillStyle)
                .opacity(appState.surfaceFillOpacity)
                .overlay(shape.stroke(appState.surfaceStrokeColor.opacity(appState.borderOpacity), lineWidth: appState.surfaceStrokeWidth))
        }
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { appState.accentColor },
            set: { appState.setAccentColor($0) }
        )
    }

    private var accentPresets: [Color] {
        [
            Color(hex: "#0A84FF"),
            Color(hex: "#30D158"),
            Color(hex: "#FF9F0A"),
            Color(hex: "#FF375F"),
            Color(hex: "#BF5AF2"),
            Color(hex: "#64D2FF"),
            Color(hex: "#8E8E93")
        ]
    }

    private var displayName: String {
        if let email = supabaseManager.session?.user.email, let first = email.split(separator: "@").first {
            return String(first)
        }
        return "Phoebe User"
    }

    private var initials: String {
        let source = displayName
            .split(separator: " ")
            .map { String($0.prefix(1)).uppercased() }
            .joined()
        return source.isEmpty ? "P" : String(source.prefix(2))
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
