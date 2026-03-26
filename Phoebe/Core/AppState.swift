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
            return AnyShapeStyle(.regularMaterial)
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
            return accentColor.opacity(preferredColorScheme == .dark ? 0.22 : 0.14)
        case .flat:
            return accentColor.opacity(preferredColorScheme == .dark ? 0.08 : 0.05)
        }
    }

    var backgroundBottomColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
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
    static let cardCornerMode = "app.surface.cardCornerMode"
    static let buttonCornerMode = "app.surface.buttonCornerMode"
    static let surfaceCornerRadius = "app.surface.cornerRadius"
    static let glassIntensity = "app.surface.glassIntensity"
    static let flatSurfaceDepth = "app.surface.flatSurfaceDepth"
    static let borderOpacity = "app.surface.borderOpacity"
    static let accentRed = "app.accent.red"
    static let accentGreen = "app.accent.green"
    static let accentBlue = "app.accent.blue"
}
