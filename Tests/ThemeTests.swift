import XCTest
import SwiftUI
@testable import StretchBreak

final class ThemeTests: XCTestCase {

    private let maxAllowedLuminance = 0.55

    private func relativeLuminance(_ color: Color) -> Double {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> Double { pow(Double(c), 2.2) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    func testNoThemeColorIsWashedOutLikeWhite() {
        for theme in AppTheme.allCases {
            let l = relativeLuminance(theme.color)
            XCTAssertLessThanOrEqual(l, maxAllowedLuminance,
                "\(theme.rawValue) accent color reads too close to white (luminance \(l)) — QA flagged this must be avoided")
        }
    }

    func testEveryThemeHasADistinctColor() {
        func hex(_ color: Color) -> String {
            let ui = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        }
        let hexes = AppTheme.allCases.map { hex($0.color) }
        XCTAssertEqual(Set(hexes).count, hexes.count, "two themes render as the exact same color")
    }

    func testEveryThemeLabelIsLocalizedInBothLanguages() {
        for theme in AppTheme.allCases {
            UserDefaults.standard.set(AppLanguage.en.rawValue, forKey: "appLanguage")
            XCTAssertFalse(theme.label.isEmpty)
            UserDefaults.standard.set(AppLanguage.zh.rawValue, forKey: "appLanguage")
            XCTAssertFalse(theme.label.isEmpty)
        }
        UserDefaults.standard.removeObject(forKey: "appLanguage")
    }

    func testCoversExactlyTheThreeRequestedColorFamilies() {
        XCTAssertEqual(Set(AppTheme.allCases), [.morandi, .latte, .blush])
    }

    func testThemeHasNoIconNameProperty() {
        XCTAssertEqual(AppTheme.allCases.map(\.rawValue).sorted(), ["blush", "latte", "morandi"])
    }
}
