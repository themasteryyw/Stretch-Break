import XCTest
@testable import StretchBreak

/// Guards the i18n system: every key must be translated in both supported
/// languages, switching languages must actually change what `t()` returns,
/// and full-body coverage must hold in both English and Traditional Chinese.
final class LocalizationTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        super.tearDown()
    }

    private func setLanguage(_ lang: AppLanguage) {
        UserDefaults.standard.set(lang.rawValue, forKey: "appLanguage")
    }

    // MARK: Every key is translated

    func testEveryLocalizationKeyHasEnglishAndChineseText() {
        // Iterates through every declared key; `t()` falling back to the raw
        // rawValue (or the English string) would mean a translation is missing.
        for key in allLKeys() {
            setLanguage(.en)
            let en = t(key)
            XCTAssertFalse(en.isEmpty, "\(key) has no English translation")
            XCTAssertNotEqual(en, key.rawValue, "\(key) is missing an English translation (falling back to the raw key)")

            setLanguage(.zh)
            let zh = t(key)
            XCTAssertFalse(zh.isEmpty, "\(key) has no Chinese translation")
            XCTAssertNotEqual(zh, key.rawValue, "\(key) is missing a Chinese translation (falling back to the raw key)")
        }
    }

    // MARK: Switching actually changes output

    func testSwitchingLanguageChangesText() {
        setLanguage(.en)
        let en = t(.stretchNowButton)
        setLanguage(.zh)
        let zh = t(.stretchNowButton)
        XCTAssertNotEqual(en, zh, "switching AppLanguage should change t() output")
    }

    func testTemplateFormattingWorksInBothLanguages() {
        setLanguage(.en)
        XCTAssertEqual(t(.moveCounter, 2, 11), "Move 2 / 11")
        setLanguage(.zh)
        XCTAssertEqual(t(.moveCounter, 2, 11), "第 2／11 組")
    }

    // MARK: Whole-body coverage

    func testBodyAreaCoversWholeBodyNotJustLowerBack() {
        // Lower body, core/back, and upper body must each be represented —
        // not only the original sciatic / lower-back focus.
        XCTAssertTrue(BodyArea.allCases.contains(.lowerBack))
        XCTAssertTrue(BodyArea.allCases.contains(.neck))
        XCTAssertTrue(BodyArea.allCases.contains(.shoulders))
        XCTAssertTrue(BodyArea.allCases.contains(.chest))
        XCTAssertTrue(BodyArea.allCases.contains(.wristsForearms))
        XCTAssertTrue(BodyArea.allCases.contains(.quads))
        XCTAssertTrue(BodyArea.allCases.contains(.calvesAnkles))
        XCTAssertGreaterThanOrEqual(BodyArea.allCases.count, 12)
    }

    func testFocusAreaCoversWholeBodyNotJustLowerBack() {
        XCTAssertTrue(FocusArea.allCases.contains(.upperBack))
        XCTAssertTrue(FocusArea.allCases.contains(.chest))
        XCTAssertTrue(FocusArea.allCases.contains(.wristsForearms))
        XCTAssertTrue(FocusArea.allCases.contains(.quads))
        XCTAssertTrue(FocusArea.allCases.contains(.calvesAnkles))
        XCTAssertGreaterThanOrEqual(FocusArea.allCases.count, 11)
    }

    func testAllBodyAreaLabelsAreLocalizedInBothLanguages() {
        for area in BodyArea.allCases {
            setLanguage(.en)
            XCTAssertFalse(area.label.isEmpty)
            setLanguage(.zh)
            XCTAssertFalse(area.label.isEmpty)
        }
    }

    func testAllFocusAreaLabelsAreLocalizedInBothLanguages() {
        for area in FocusArea.allCases {
            setLanguage(.en)
            XCTAssertFalse(area.label.isEmpty)
            setLanguage(.zh)
            XCTAssertFalse(area.label.isEmpty)
        }
    }

    // MARK: Notification prompt bank

    func testNotificationPromptBankHasAtLeast20MessagesPerLanguage() {
        XCTAssertGreaterThanOrEqual(NotificationScheduler.promptsEN.count, 20)
        XCTAssertGreaterThanOrEqual(NotificationScheduler.promptsZH.count, 20)
    }

    func testNotificationPromptBankHasNoDuplicates() {
        XCTAssertEqual(Set(NotificationScheduler.promptsEN).count, NotificationScheduler.promptsEN.count,
                       "English prompt list has duplicate messages")
        XCTAssertEqual(Set(NotificationScheduler.promptsZH).count, NotificationScheduler.promptsZH.count,
                       "Chinese prompt list has duplicate messages")
    }

    // MARK: Offline routine bilingual content

    func testOfflineRoutineMovesHaveBothLanguages() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "routine", withExtension: "json")
            ?? Bundle.main.url(forResource: "routine", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let moves = try JSONDecoder().decode([RoutineMove].self, from: data)
        XCTAssertGreaterThanOrEqual(moves.count, 8)
        for move in moves {
            XCTAssertFalse((move.name["en"] ?? "").isEmpty, "\(move.key) missing English name")
            XCTAssertFalse((move.name["zh"] ?? "").isEmpty, "\(move.key) missing Chinese name")
            XCTAssertFalse((move.cue["en"] ?? "").isEmpty, "\(move.key) missing English cue")
            XCTAssertFalse((move.cue["zh"] ?? "").isEmpty, "\(move.key) missing Chinese cue")
        }
        // Full-body: not just the original hip/hamstring/neck set.
        let keys = Set(moves.map(\.key))
        XCTAssertTrue(keys.contains("chest_opener"))
        XCTAssertTrue(keys.contains("wrist_forearm"))
        XCTAssertTrue(keys.contains("calf_ankle"))
    }

    // MARK: - Helpers

    /// Every `L` case, so a newly added key without a matching translation
    /// fails this suite instead of silently falling back at runtime.
    private func allLKeys() -> [L] { L.allCases }
}
