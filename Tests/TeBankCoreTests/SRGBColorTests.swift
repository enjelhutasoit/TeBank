import TeBankCore
import XCTest

final class SRGBColorTests: XCTestCase {
    func testBlackAndWhiteHaveMaximumContrastInEitherOrder() {
        let black = SRGBColor(red: 0, green: 0, blue: 0)
        let white = SRGBColor(red: 255, green: 255, blue: 255)

        XCTAssertEqual(black.contrastRatio(with: white), 21.0, accuracy: 1e-9)
        XCTAssertEqual(white.contrastRatio(with: black), 21.0, accuracy: 1e-9)
    }

    func testIdenticalColorsHaveMinimumContrast() {
        let color = SRGBColor(red: 128, green: 128, blue: 128)

        XCTAssertEqual(color.contrastRatio(with: color), 1.0, accuracy: 1e-9)
    }

    func testMixedChannelsMatchWCAGReferenceCalculation() {
        let black = SRGBColor(red: 0, green: 0, blue: 0)
        let color = SRGBColor(red: 10, green: 11, blue: 128)

        XCTAssertEqual(
            color.contrastRatio(with: black),
            1.3724773770717806,
            accuracy: 1e-9
        )
    }
}
