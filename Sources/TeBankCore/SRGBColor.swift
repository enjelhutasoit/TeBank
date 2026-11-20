import Foundation

/// An opaque color expressed as 8-bit sRGB channels.
public struct SRGBColor: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Returns the unrounded WCAG contrast ratio in the closed range `1...21`.
    public func contrastRatio(with other: Self) -> Double {
        let lighterLuminance = max(relativeLuminance, other.relativeLuminance)
        let darkerLuminance = min(relativeLuminance, other.relativeLuminance)

        return (lighterLuminance + 0.05) / (darkerLuminance + 0.05)
    }

    private var relativeLuminance: Double {
        0.2126 * Self.linearized(red)
            + 0.7152 * Self.linearized(green)
            + 0.0722 * Self.linearized(blue)
    }

    private static func linearized(_ channel: UInt8) -> Double {
        let encodedValue = Double(channel) / 255.0

        if encodedValue <= 0.04045 {
            return encodedValue / 12.92
        }

        return pow((encodedValue + 0.055) / 1.055, 2.4)
    }
}
