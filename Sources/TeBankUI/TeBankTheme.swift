import SwiftUI
import TeBankCore
import VaneKit

public extension View {
    /// Applies the TeBank palette to descendant VaneKit components.
    func teBankTheme() -> some View {
        let standard = VaneTheme.standard
        return vaneTheme(VaneTheme(
            light: VaneThemePalette(.light, defaults: standard.light),
            dark: VaneThemePalette(.dark, defaults: standard.dark)
        ))
    }
}

private extension VaneThemePalette {
    init(_ palette: BrandPalette, defaults: VaneThemePalette) {
        self.init(
            background: Color(palette.canvas),
            surface: Color(palette.surface),
            textPrimary: Color(palette.primaryText),
            textSecondary: Color(palette.secondaryText),
            accent: Color(palette.accent),
            onAccent: Color(palette.onAccent),
            critical: defaults.critical,
            onCritical: defaults.onCritical
        )
    }
}

private extension Color {
    init(_ token: TeBankCore.SRGBColor) {
        self.init(.sRGB,
                  red: Double(token.red) / 255,
                  green: Double(token.green) / 255,
                  blue: Double(token.blue) / 255,
                  opacity: 1)
    }
}
