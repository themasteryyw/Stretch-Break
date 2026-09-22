import XCTest
@testable import StretchBreak

final class LocalizationTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        super.tearDown()
    }

    private func setLanguage(_ lang: AppLanguage) {
        UserDefaults.standard.set(lang.rawValue, forKey: "appLanguage")
    }

    func testEveryLocalizationKeyHasEnglishAndChineseText() {
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

    func testBodyAreaCoversWholeBodyNotJustLowerBack() {
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

    func testTimerOnlyHintIsNonEmptyInBothLanguages() {
        for i in 0..<20 {
            setLanguage(.en)
            XCTAssertFalse(timerOnlyHint(at: i).isEmpty)
            setLanguage(.zh)
            XCTAssertFalse(timerOnlyHint(at: i).isEmpty)
        }
    }

    func testTimerOnlyHintChangesAcrossIndices() {
        setLanguage(.en)
        let hints = Set((0..<10).map { timerOnlyHint(at: $0) })
        XCTAssertGreaterThan(hints.count, 1, "hint bank should actually rotate, not repeat one string")
    }

    func testTimerOnlyHintHandlesNegativeIndexSafely() {
        XCTAssertFalse(timerOnlyHint(at: -1).isEmpty)
    }

    func testNotificationPromptBankHasAtLeast20MessagesPerLanguage() {
        XCTAssertGreaterThanOrEqual(NotificationScheduler.promptsEN.count, 20)
        XCTAssertGreaterThanOrEqual(NotificationScheduler.promptsZH.count, 20)
    }

    func testNotificationPromptsMentionEveryMajorBodyRegion() {
        let regionsEN = ["neck", "shoulder", "chest", "wrist", "hip", "hamstring", "quad", "calv", "ankle", "back", "spine"]
        let regionsZH = ["脖子", "肩", "胸", "手腕", "髖", "大腿後側", "大腿前側", "小腿", "腳踝", "背", "脊"]
        let allEN = NotificationScheduler.promptsEN.joined(separator: " ").lowercased()
        let allZH = NotificationScheduler.promptsZH.joined(separator: " ")
        for region in regionsEN {
            XCTAssertTrue(allEN.contains(region), "no English prompt mentions '\(region)'")
        }
        for region in regionsZH {
            XCTAssertTrue(allZH.contains(region), "no Chinese prompt mentions '\(region)'")
        }
    }

    func testNotificationPromptBankStillHasNoDurationPromise() {
        let digitMinuteEN = try! NSRegularExpression(pattern: #"\d+\s*-?\s*min(ute)?s?\b"#, options: .caseInsensitive)
        let digitMinuteZH = try! NSRegularExpression(pattern: #"\d+\s*分鐘"#)
        for prompt in NotificationScheduler.promptsEN {
            let range = NSRange(prompt.startIndex..., in: prompt)
            XCTAssertNil(digitMinuteEN.firstMatch(in: prompt, range: range), "'\(prompt)' still promises a specific duration")
        }
        for prompt in NotificationScheduler.promptsZH {
            let range = NSRange(prompt.startIndex..., in: prompt)
            XCTAssertNil(digitMinuteZH.firstMatch(in: prompt, range: range), "'\(prompt)' still promises a specific duration")
        }
    }

    func testNotificationPromptBankHasNoDuplicates() {
        XCTAssertEqual(Set(NotificationScheduler.promptsEN).count, NotificationScheduler.promptsEN.count,
                       "English prompt list has duplicate messages")
        XCTAssertEqual(Set(NotificationScheduler.promptsZH).count, NotificationScheduler.promptsZH.count,
                       "Chinese prompt list has duplicate messages")
    }

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
        let keys = Set(moves.map(\.key))
        XCTAssertTrue(keys.contains("chest_opener"))
        XCTAssertTrue(keys.contains("wrist_forearm"))
        XCTAssertTrue(keys.contains("calf_ankle"))
    }

    private func allLKeys() -> [L] { L.allCases }
}
