import XCTest
@testable import StretchBreak

final class SessionPlannerTests: XCTestCase {

    private func vid(_ id: String, durationSec: Int = 240, areas: [BodyArea] = [.lowerBack]) -> StretchVideo {
        StretchVideo(id: id, title: id, channel: "c", durationSec: durationSec,
                    areas: areas, intensity: .gentle)
    }

    func testFiltersToVideoBand() {
        let pool = [vid("a", durationSec: 120), vid("b", durationSec: 300),
                    vid("c", durationSec: 350), vid("d", durationSec: 900)]
        let filtered = SessionPlanner.lengthFiltered(pool, band: .standard)
        XCTAssertEqual(Set(filtered.map(\.id)), ["b", "c"])
    }

    func testThinBandAddsShorterPaddableVideosButNeverLongerOnes() {
        let pool = [vid("short", durationSec: 200), vid("deep", durationSec: 400), vid("long", durationSec: 470)]
        let filtered = SessionPlanner.lengthFiltered(pool, band: .standard)
        XCTAssertEqual(filtered.map(\.id), ["short"], "standard band must not fall back to longer videos")

        let standard = SessionPlanner.lengthFiltered([vid("a", durationSec: 120), vid("b", durationSec: 300), vid("x", durationSec: 470)],
                                                     band: .standard)
        XCTAssertEqual(Set(standard.map(\.id)), ["a", "b"])
    }

    func testShorterVideoIsSkippedWhenRoutineCannotFillTheGap() {
        let filtered = SessionPlanner.lengthFiltered([vid("a", durationSec: 90)], band: .deep, maxPadSec: 100)
        XCTAssertTrue(filtered.isEmpty)
    }

    func testPadSecondsBringsShortVideoIntoBand() {
        for band in StretchBand.allCases {
            let short = vid("s", durationSec: 90)
            let pad = SessionPlanner.padSeconds(for: short, band: band)
            if band.range.contains(90) {
                XCTAssertEqual(pad, 0)
            } else {
                XCTAssertTrue(band.range.contains(90 + pad), "\(band) padded total \(90 + pad) is outside \(band.range)")
            }
            let fitting = vid("f", durationSec: band.range.upperBound)
            XCTAssertEqual(SessionPlanner.padSeconds(for: fitting, band: band), 0)
        }
    }

    func testBandsAreContiguousAndInsidePoolRange() {
        let bands = StretchBand.allCases
        XCTAssertGreaterThanOrEqual(bands.first!.range.lowerBound, StretchConfig.poolDurationRange.lowerBound)
        XCTAssertEqual(bands.last?.range.upperBound, StretchConfig.poolDurationRange.upperBound)
        for (a, b) in zip(bands, bands.dropFirst()) {
            XCTAssertEqual(a.range.upperBound + 1, b.range.lowerBound)
        }
        for band in bands { XCTAssertTrue(band.range.contains(band.targetSec)) }
    }

    func testBandTargetsAreFixedMinutes() {
        XCTAssertEqual(StretchBand.standard.targetSec, 5 * 60)
        XCTAssertEqual(StretchBand.deep.targetSec, 8 * 60)
        XCTAssertGreaterThan(RoutineMove.totalSeconds, 0, "the routine loops to fill any gap, so it only needs moves")
    }

    func testStretchConfigDefaults() {
        XCTAssertEqual(StretchConfig.defaultTimerMinutes, 5)
        XCTAssertTrue(StretchConfig.timerMinutesRange.contains(3))
        XCTAssertTrue(StretchConfig.timerMinutesRange.contains(5))
        XCTAssertEqual(StretchBand.allCases, [.standard, .deep])
    }

    func testOldMinuteSettingMigratesToBand() {
        let d = UserDefaults.standard
        let saved = d.object(forKey: "videoTargetMinutes")
        defer { d.set(saved, forKey: "videoTargetMinutes") }
        d.removeObject(forKey: "videoTargetMinutes"); XCTAssertEqual(StretchBand.migratedDefault, .standard)
        d.set(5, forKey: "videoTargetMinutes");  XCTAssertEqual(StretchBand.migratedDefault, .standard)
        d.set(10, forKey: "videoTargetMinutes"); XCTAssertEqual(StretchBand.migratedDefault, .deep)
        d.set(20, forKey: "videoTargetMinutes"); XCTAssertEqual(StretchBand.migratedDefault, .deep)
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

    func testSessionPoolKeepsRotationWhenAreaMatchesAreFew() {
        let pool = [vid("hip1", durationSec: 250, areas: [.piriformis]), vid("hip2", durationSec: 300, areas: [.piriformis]),
                    vid("neck1", durationSec: 200, areas: [.neck]), vid("neck2", durationSec: 320, areas: [.neck]),
                    vid("wrist", durationSec: 340, areas: [.wristsForearms]), vid("long", durationSec: 470, areas: [.piriformis])]
        let result = SessionPlanner.sessionPool(pool, band: .standard, askPain: true, targeting: [.piriformis])
        XCTAssertEqual(Set(result.map(\.id)), ["hip1", "hip2", "neck1", "neck2", "wrist"],
                       "two area matches is too few to rotate; fall back to every in-band video")
    }

    func testSessionPoolPrefersAreaWhenEnoughMatch() {
        let pool = (1...4).map { vid("hip\($0)", durationSec: 200 + $0 * 10, areas: [.piriformis]) }
            + [vid("neck", durationSec: 250, areas: [.neck])]
        let result = SessionPlanner.sessionPool(pool, band: .standard, askPain: true, targeting: [.piriformis])
        XCTAssertEqual(result.count, 4)
        XCTAssertFalse(result.contains { $0.id == "neck" })
    }
}
