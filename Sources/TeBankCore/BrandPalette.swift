/// Semantic brand colors shared by TeBank presentation layers.
public struct BrandPalette: Equatable, Sendable {
    public let canvas: SRGBColor
    public let surface: SRGBColor
    public let primaryText: SRGBColor
    public let secondaryText: SRGBColor
    public let accent: SRGBColor
    public let onAccent: SRGBColor

    public init(
        canvas: SRGBColor,
        surface: SRGBColor,
        primaryText: SRGBColor,
        secondaryText: SRGBColor,
        accent: SRGBColor,
        onAccent: SRGBColor
    ) {
        self.canvas = canvas
        self.surface = surface
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accent = accent
        self.onAccent = onAccent
    }

    public static let light = Self(
        canvas: SRGBColor(red: 0xF6, green: 0xF5, blue: 0xF2),
        surface: SRGBColor(red: 0xFF, green: 0xFF, blue: 0xFF),
        primaryText: SRGBColor(red: 0x17, green: 0x19, blue: 0x1C),
        secondaryText: SRGBColor(red: 0x51, green: 0x58, blue: 0x61),
        accent: SRGBColor(red: 0x78, green: 0x55, blue: 0x00),
        onAccent: SRGBColor(red: 0xFF, green: 0xFF, blue: 0xFF)
    )

    public static let dark = Self(
        canvas: SRGBColor(red: 0x10, green: 0x12, blue: 0x15),
        surface: SRGBColor(red: 0x1B, green: 0x1E, blue: 0x23),
        primaryText: SRGBColor(red: 0xF7, green: 0xF7, blue: 0xF5),
        secondaryText: SRGBColor(red: 0xB8, green: 0xBF, blue: 0xC8),
        accent: SRGBColor(red: 0xE6, green: 0xBF, blue: 0x69),
        onAccent: SRGBColor(red: 0x17, green: 0x19, blue: 0x1C)
    )
}
