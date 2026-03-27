import Foundation
import Combine
import SwiftUI

#if os(iOS)
import UIKit
private typealias PlatformColor = UIColor
#else
import AppKit
private typealias PlatformColor = NSColor
#endif

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum SurfaceMaterialMode: String, CaseIterable, Identifiable {
    case liquidGlass
    case flat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .liquidGlass: return "Liquid Glass"
        case .flat: return "Flat"
        }
    }
}

enum LiquidMaterialProfile: String, CaseIterable, Identifiable {
    case ultraThin
    case thin
    case regular
    case thick

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ultraThin: return "Ultra Thin"
        case .thin: return "Thin"
        case .regular: return "Regular"
        case .thick: return "Thick"
        }
    }
}

enum UIDensityMode: String, CaseIterable, Identifiable {
    case compact
    case comfortable
    case spacious

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: return "Compact"
        case .comfortable: return "Comfortable"
        case .spacious: return "Spacious"
        }
    }
}

enum DesignLanguagePreset: String, CaseIterable, Identifiable {
    case glassy
    case notion
    case obsidian
    case chat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .glassy: return "Liquid Glass"
        case .notion: return "Notion Flat"
        case .obsidian: return "Obsidian"
        case .chat: return "Chat Minimal"
        }
    }
}

enum SurfaceCornerMode: String, CaseIterable, Identifiable {
    case sharp
    case rounded
    case pill

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sharp: return "Sharp"
        case .rounded: return "Rounded"
        case .pill: return "Pill"
        }
    }
}

class AppState: ObservableObject {
    @Published var isLoading: Bool = false

    @Published var themeMode: AppThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: Keys.themeMode) }
    }

    @Published var surfaceMaterial: SurfaceMaterialMode {
        didSet { defaults.set(surfaceMaterial.rawValue, forKey: Keys.surfaceMaterial) }
    }

    @Published var liquidMaterialProfile: LiquidMaterialProfile {
        didSet { defaults.set(liquidMaterialProfile.rawValue, forKey: Keys.liquidMaterialProfile) }
    }

    @Published var cardCornerMode: SurfaceCornerMode {
        didSet { defaults.set(cardCornerMode.rawValue, forKey: Keys.cardCornerMode) }
    }

    @Published var buttonCornerMode: SurfaceCornerMode {
        didSet { defaults.set(buttonCornerMode.rawValue, forKey: Keys.buttonCornerMode) }
    }

    @Published var surfaceCornerRadius: Double {
        didSet { defaults.set(surfaceCornerRadius, forKey: Keys.surfaceCornerRadius) }
    }

    @Published var glassIntensity: Double {
        didSet { defaults.set(glassIntensity, forKey: Keys.glassIntensity) }
    }

    @Published var flatSurfaceDepth: Double {
        didSet { defaults.set(flatSurfaceDepth, forKey: Keys.flatSurfaceDepth) }
    }

    @Published var borderOpacity: Double {
        didSet { defaults.set(borderOpacity, forKey: Keys.borderOpacity) }
    }

    @Published var shadowStrength: Double {
        didSet { defaults.set(shadowStrength, forKey: Keys.shadowStrength) }
    }

    @Published var uiScale: Double {
        didSet { defaults.set(uiScale, forKey: Keys.uiScale) }
    }

    @Published var backgroundBlend: Double {
        didSet { defaults.set(backgroundBlend, forKey: Keys.backgroundBlend) }
    }

    @Published var densityMode: UIDensityMode {
        didSet { defaults.set(densityMode.rawValue, forKey: Keys.densityMode) }
    }

    @Published var selectedPreset: DesignLanguagePreset {
        didSet { defaults.set(selectedPreset.rawValue, forKey: Keys.selectedPreset) }
    }

    @Published var designLocked: Bool {
        didSet { defaults.set(designLocked, forKey: Keys.designLocked) }
    }

    @Published var showDesignDebugBadges: Bool {
        didSet { defaults.set(showDesignDebugBadges, forKey: Keys.showDesignDebugBadges) }
    }

    @Published var enableExperimentalGlass: Bool {
        didSet { defaults.set(enableExperimentalGlass, forKey: Keys.enableExperimentalGlass) }
    }

    @Published private var accentRed: Double {
        didSet { defaults.set(accentRed, forKey: Keys.accentRed) }
    }

    @Published private var accentGreen: Double {
        didSet { defaults.set(accentGreen, forKey: Keys.accentGreen) }
    }

    @Published private var accentBlue: Double {
        didSet { defaults.set(accentBlue, forKey: Keys.accentBlue) }
    }

    private let defaults = UserDefaults.standard

    init() {
        themeMode = AppThemeMode(rawValue: defaults.string(forKey: Keys.themeMode) ?? "") ?? .system
        surfaceMaterial = SurfaceMaterialMode(rawValue: defaults.string(forKey: Keys.surfaceMaterial) ?? "") ?? .liquidGlass
        liquidMaterialProfile = LiquidMaterialProfile(rawValue: defaults.string(forKey: Keys.liquidMaterialProfile) ?? "") ?? .regular
        cardCornerMode = SurfaceCornerMode(rawValue: defaults.string(forKey: Keys.cardCornerMode) ?? "") ?? .rounded
        buttonCornerMode = SurfaceCornerMode(rawValue: defaults.string(forKey: Keys.buttonCornerMode) ?? "") ?? .rounded

        let storedRadius = defaults.object(forKey: Keys.surfaceCornerRadius) as? Double
        surfaceCornerRadius = storedRadius ?? 16

        let storedGlass = defaults.object(forKey: Keys.glassIntensity) as? Double
        glassIntensity = storedGlass ?? 0.92

        let storedDepth = defaults.object(forKey: Keys.flatSurfaceDepth) as? Double
        flatSurfaceDepth = storedDepth ?? 0.95

        let storedBorder = defaults.object(forKey: Keys.borderOpacity) as? Double
        borderOpacity = storedBorder ?? 0.35

        let storedShadow = defaults.object(forKey: Keys.shadowStrength) as? Double
        shadowStrength = storedShadow ?? 0.55

        let storedScale = defaults.object(forKey: Keys.uiScale) as? Double
        uiScale = storedScale ?? 1.0

        let storedBlend = defaults.object(forKey: Keys.backgroundBlend) as? Double
        backgroundBlend = storedBlend ?? 0.5

        densityMode = UIDensityMode(rawValue: defaults.string(forKey: Keys.densityMode) ?? "") ?? .comfortable
        selectedPreset = DesignLanguagePreset(rawValue: defaults.string(forKey: Keys.selectedPreset) ?? "") ?? .glassy
        designLocked = defaults.bool(forKey: Keys.designLocked)
        showDesignDebugBadges = defaults.bool(forKey: Keys.showDesignDebugBadges)
        enableExperimentalGlass = defaults.object(forKey: Keys.enableExperimentalGlass) as? Bool ?? true

        let red = defaults.object(forKey: Keys.accentRed) as? Double
        let green = defaults.object(forKey: Keys.accentGreen) as? Double
        let blue = defaults.object(forKey: Keys.accentBlue) as? Double
        accentRed = red ?? 0.0
        accentGreen = green ?? 0.478
        accentBlue = blue ?? 1.0
    }

    var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var accentColor: Color {
        Color(red: accentRed, green: accentGreen, blue: accentBlue)
    }

    func setAccentColor(_ color: Color) {
        #if os(iOS)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        PlatformColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        guard let converted = PlatformColor(color).usingColorSpace(.deviceRGB) else { return }
        let r = converted.redComponent
        let g = converted.greenComponent
        let b = converted.blueComponent
        #endif
        accentRed = Double(r)
        accentGreen = Double(g)
        accentBlue = Double(b)
    }

    var cardCornerRadius: CGFloat {
        resolveCornerRadius(for: cardCornerMode)
    }

    var buttonCornerRadius: CGFloat {
        resolveCornerRadius(for: buttonCornerMode)
    }

    var surfaceFillStyle: AnyShapeStyle {
        switch surfaceMaterial {
        case .liquidGlass:
            switch liquidMaterialProfile {
            case .ultraThin: return AnyShapeStyle(.ultraThinMaterial)
            case .thin: return AnyShapeStyle(.thinMaterial)
            case .regular: return AnyShapeStyle(.regularMaterial)
            case .thick: return AnyShapeStyle(.thickMaterial)
            }
        case .flat:
            return AnyShapeStyle(flatSurfaceColor)
        }
    }

    var surfaceFillOpacity: Double {
        switch surfaceMaterial {
        case .liquidGlass:
            return glassIntensity
        case .flat:
            return flatSurfaceDepth
        }
    }

    var surfaceStrokeColor: Color {
        #if os(iOS)
        Color(.separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }

    var fieldBackgroundColor: Color {
        switch surfaceMaterial {
        case .liquidGlass:
            return Color.white.opacity(0.06)
        case .flat:
            #if os(iOS)
            return Color(.secondarySystemBackground)
            #else
            return Color(nsColor: .textBackgroundColor)
            #endif
        }
    }

    private var flatSurfaceColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }

    var backgroundTopColor: Color {
        switch surfaceMaterial {
        case .liquidGlass:
            return accentColor.opacity((preferredColorScheme == .dark ? 0.22 : 0.14) + (backgroundBlend * 0.08))
        case .flat:
            return accentColor.opacity((preferredColorScheme == .dark ? 0.08 : 0.05) + (backgroundBlend * 0.05))
        }
    }

    var backgroundBottomColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }

    var surfaceStrokeWidth: CGFloat {
        densityMode == .compact ? 0.5 : (densityMode == .spacious ? 0.8 : 0.6)
    }

    var spacingScale: CGFloat {
        switch densityMode {
        case .compact: return 0.88
        case .comfortable: return 1.0
        case .spacious: return 1.14
        }
    }

    var titleFontSize: CGFloat {
        34 * CGFloat(uiScale)
    }

    var bodyFontSize: CGFloat {
        13 * CGFloat(uiScale)
    }

    var surfaceShadowRadius: CGFloat {
        CGFloat(2 + (shadowStrength * 10))
    }

    func applySelectedPreset() {
        guard !designLocked else { return }

        switch selectedPreset {
        case .glassy:
            surfaceMaterial = .liquidGlass
            liquidMaterialProfile = .regular
            glassIntensity = 0.95
            flatSurfaceDepth = 0.95
            borderOpacity = 0.34
            shadowStrength = 0.6
            uiScale = 1.0
            densityMode = .comfortable
            surfaceCornerRadius = 16
            cardCornerMode = .rounded
            buttonCornerMode = .rounded
        case .notion:
            surfaceMaterial = .flat
            liquidMaterialProfile = .thin
            glassIntensity = 0.75
            flatSurfaceDepth = 1.0
            borderOpacity = 0.18
            shadowStrength = 0.1
            uiScale = 0.98
            densityMode = .compact
            surfaceCornerRadius = 8
            cardCornerMode = .rounded
            buttonCornerMode = .rounded
        case .obsidian:
            surfaceMaterial = .flat
            liquidMaterialProfile = .thick
            glassIntensity = 0.72
            flatSurfaceDepth = 0.92
            borderOpacity = 0.28
            shadowStrength = 0.35
            uiScale = 1.02
            densityMode = .comfortable
            surfaceCornerRadius = 10
            cardCornerMode = .rounded
            buttonCornerMode = .rounded
        case .chat:
            surfaceMaterial = .liquidGlass
            liquidMaterialProfile = .thin
            glassIntensity = 0.9
            flatSurfaceDepth = 0.94
            borderOpacity = 0.24
            shadowStrength = 0.22
            uiScale = 1.0
            densityMode = .comfortable
            surfaceCornerRadius = 14
            cardCornerMode = .rounded
            buttonCornerMode = .pill
        }
    }

    func resetAppearanceDefaults() {
        guard !designLocked else { return }
        themeMode = .system
        surfaceMaterial = .liquidGlass
        liquidMaterialProfile = .regular
        cardCornerMode = .rounded
        buttonCornerMode = .rounded
        surfaceCornerRadius = 16
        glassIntensity = 0.92
        flatSurfaceDepth = 0.95
        borderOpacity = 0.35
        shadowStrength = 0.55
        uiScale = 1.0
        backgroundBlend = 0.5
        densityMode = .comfortable
        setAccentColor(Color(red: 0.0, green: 0.478, blue: 1.0))
    }

    private func resolveCornerRadius(for mode: SurfaceCornerMode) -> CGFloat {
        switch mode {
        case .sharp:
            return 0
        case .rounded:
            return CGFloat(surfaceCornerRadius)
        case .pill:
            return 999
        }
    }
}

private enum Keys {
    static let themeMode = "app.theme.mode"
    static let surfaceMaterial = "app.surface.material"
    static let liquidMaterialProfile = "app.surface.materialProfile"
    static let cardCornerMode = "app.surface.cardCornerMode"
    static let buttonCornerMode = "app.surface.buttonCornerMode"
    static let surfaceCornerRadius = "app.surface.cornerRadius"
    static let glassIntensity = "app.surface.glassIntensity"
    static let flatSurfaceDepth = "app.surface.flatSurfaceDepth"
    static let borderOpacity = "app.surface.borderOpacity"
    static let shadowStrength = "app.surface.shadowStrength"
    static let uiScale = "app.ui.scale"
    static let backgroundBlend = "app.background.blend"
    static let densityMode = "app.ui.densityMode"
    static let selectedPreset = "app.design.selectedPreset"
    static let designLocked = "app.design.locked"
    static let showDesignDebugBadges = "app.design.debugBadges"
    static let enableExperimentalGlass = "app.design.experimentalGlass"
    static let accentRed = "app.accent.red"
    static let accentGreen = "app.accent.green"
    static let accentBlue = "app.accent.blue"
}
