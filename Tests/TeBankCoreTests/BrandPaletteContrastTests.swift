import TeBankCore
import XCTest

final class BrandPaletteContrastTests: XCTestCase {
    func testLightPaletteMeetsMinimumTextContrast() {
        assertMinimumTextContrast(for: .light, appearance: "light")
    }

    func testDarkPaletteMeetsMinimumTextContrast() {
        assertMinimumTextContrast(for: .dark, appearance: "dark")
    }

    private func assertMinimumTextContrast(
        for palette: BrandPalette,
        appearance: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let minimumRatio = 4.5
        let pairs: [(name: String, foreground: SRGBColor, background: SRGBColor)] = [
            ("primaryText on canvas", palette.primaryText, palette.canvas),
            ("primaryText on surface", palette.primaryText, palette.surface),
            ("secondaryText on canvas", palette.secondaryText, palette.canvas),
            ("secondaryText on surface", palette.secondaryText, palette.surface),
            ("accent on canvas", palette.accent, palette.canvas),
            ("accent on surface", palette.accent, palette.surface),
            ("onAccent on accent", palette.onAccent, palette.accent)
        ]

        for pair in pairs {
            let ratio = pair.foreground.contrastRatio(with: pair.background)

            XCTAssertGreaterThanOrEqual(
                ratio,
                minimumRatio,
                "\(appearance): \(pair.name) measured \(ratio):1; expected at least \(minimumRatio):1",
                file: file,
                line: line
            )
        }
    }
}
