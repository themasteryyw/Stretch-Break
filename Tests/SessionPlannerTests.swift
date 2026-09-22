import XCTest
@testable import StretchBreak

final class SessionPlannerTests: XCTestCase {

    private func vid(_ id: String, durationSec: Int = 240, areas: [BodyArea] = [.lowerBack]) -> StretchVideo {
        StretchVideo(id: id, title: id, channel: "c", durationSec: durationSec,
                    areas: areas, intensity: .gentle)
    }

    func testFiltersToVideoBand() {
        let pool = [vid("a", durationSec: 120), vid("b", durationSec: 300),
                    vid("c", durationSec: 450), vid("d", durationSec: 900)]
        let filtered = SessionPlanner.lengthFiltered(pool, band: StretchConfig.videoDurationBand)
        XCTAssertEqual(Set(filtered.map(\.id)), ["b", "c"])
    }

    func testFallsBackToFullPoolWhenBandTooThin() {
        let pool = [vid("a", durationSec: 120), vid("b", durationSec: 300), vid("c", durationSec: 90)]
        let filtered = SessionPlanner.lengthFiltered(pool, band: StretchConfig.videoDurationBand)
        XCTAssertEqual(filtered.count, pool.count)
    }

    func testStretchConfigDefaults() {
        XCTAssertEqual(StretchConfig.videoTargetSec, 300)
        XCTAssertEqual(StretchConfig.defaultTimerMinutes, 5)
        XCTAssertTrue(StretchConfig.timerMinutesRange.contains(3))
        XCTAssertTrue(StretchConfig.timerMinutesRange.contains(5))
    }

    func testExactlyTwoStretchModes() {
        XCTAssertEqual(Set(StretchMode.allCases), [.video, .timer])
    }

    func testAreaFilteredKeepsOnlyVideosMatchingTheAskedArea() {
        let pool = [vid("neck", areas: [.neck]), vid("shoulders", areas: [.shoulders]),
                    vid("chest", areas: [.chest]), vid("hip", areas: [.hipFlexors])]
        let filtered = SessionPlanner.areaFiltered(pool, targeting: FocusArea.neckShoulders.relatedBodyAreas)
        XCTAssertEqual(Set(filtered.map(\.id)), ["neck", "shoulders"])
    }

    func testAreaFilteredFallsBackWhenTooThin() {
        let pool = [vid("a", areas: [.chest]), vid("b", areas: [.chest])]
        let filtered = SessionPlanner.areaFiltered(pool, targeting: FocusArea.calvesAnkles.relatedBodyAreas)
        XCTAssertEqual(filtered.count, pool.count)
    }

    func testTargetedPoolSkipsAreaFilterWhenAskPainIsOff() {
        let pool = [vid("neck", areas: [.neck]), vid("chest", areas: [.chest]), vid("hip", areas: [.hipFlexors])]
        let result = SessionPlanner.targetedPool(pool, askPain: false, targeting: FocusArea.neckShoulders.relatedBodyAreas)
        XCTAssertEqual(result.count, pool.count)
    }

    func testTargetedPoolAppliesAreaFilterWhenAskPainIsOn() {
        let pool = [vid("neck", areas: [.neck]), vid("shoulders", areas: [.shoulders]), vid("chest", areas: [.chest])]
        let result = SessionPlanner.targetedPool(pool, askPain: true, targeting: FocusArea.neckShoulders.relatedBodyAreas)
        XCTAssertEqual(Set(result.map(\.id)), ["neck", "shoulders"])
    }

    func testEveryFocusAreaMapsToAtLeastOneBodyArea() {
        for area in FocusArea.allCases {
            XCTAssertFalse(area.relatedBodyAreas.isEmpty, "\(area) has no related BodyArea to target videos with")
        }
    }

    func testTimerTickIncrementsByOne() {
        let r = SessionPlanner.timerTick(elapsed: 0, target: 180)
        XCTAssertEqual(r.elapsed, 1)
        XCTAssertFalse(r.done)
    }

    func testTimerDoesNotCompleteBeforeTarget() {
        var elapsed = 0
        for _ in 0..<179 {
            let r = SessionPlanner.timerTick(elapsed: elapsed, target: 180)
            XCTAssertFalse(r.done, "must not complete before the 180th tick")
            elapsed = r.elapsed
        }
        XCTAssertEqual(elapsed, 179)
    }

    func testTimerCompletesExactlyAtTarget() {
        let r = SessionPlanner.timerTick(elapsed: 179, target: 180)
        XCTAssertEqual(r.elapsed, 180)
        XCTAssertTrue(r.done)
    }

    func testTimerDoesNotReFireOnceAlreadyDone() {
        let r = SessionPlanner.timerTick(elapsed: 180, target: 180)
        XCTAssertEqual(r.elapsed, 180)
        XCTAssertFalse(r.done)
    }

    func testFullTimerRunsForExactlyTheTargetNumberOfTicksAndCompletesOnce() {
        var elapsed = 0
        var completions = 0
        for _ in 0..<200 {
            let r = SessionPlanner.timerTick(elapsed: elapsed, target: 180)
            elapsed = r.elapsed
            if r.done { completions += 1 }
        }
        XCTAssertEqual(elapsed, 180, "should settle at exactly the target, never overshoot")
        XCTAssertEqual(completions, 1, "must signal completion exactly once, not immediately and not repeatedly")
    }

    func testEveryStretchModeHasALocalizedLabelInBothLanguages() {
        for mode in StretchMode.allCases {
            UserDefaults.standard.set(AppLanguage.en.rawValue, forKey: "appLanguage")
            XCTAssertFalse(mode.label.isEmpty)
            UserDefaults.standard.set(AppLanguage.zh.rawValue, forKey: "appLanguage")
            XCTAssertFalse(mode.label.isEmpty)
        }
        UserDefaults.standard.removeObject(forKey: "appLanguage")
    }

    func testSearchURLRelevanceLanguageIsConfigurable() throws {
        let en = try XCTUnwrap(YouTubeProvider.searchURL(query: "test", apiKey: "key", relevanceLanguage: "en"))
        let zh = try XCTUnwrap(YouTubeProvider.searchURL(query: "test", apiKey: "key", relevanceLanguage: "zh-Hant"))
        func lang(_ url: URL) -> String? {
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "relevanceLanguage" }?.value
        }
        XCTAssertEqual(lang(en), "en")
        XCTAssertEqual(lang(zh), "zh-Hant")
    }

    func testSearchURLDefaultsToEnglishWhenUnspecified() throws {
        let url = try XCTUnwrap(YouTubeProvider.searchURL(query: "test", apiKey: "key"))
        let lang = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "relevanceLanguage" }?.value
        XCTAssertEqual(lang, "en")
    }
}
