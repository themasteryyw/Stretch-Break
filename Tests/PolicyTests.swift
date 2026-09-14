import XCTest
@testable import StretchBreak

final class PolicyTests: XCTestCase {

    // MARK: FocusArea rotation

    func testConsecutiveCheckInsAskAboutDifferentAreas() {
        let n = FocusArea.allCases.count
        for c in -3 ..< (n * 3) {
            XCTAssertNotEqual(FocusArea.at(c).label, FocusArea.at(c + 1).label,
                              "two check-ins in a row asked about the same body area")
        }
    }

    func testRotationCoversEveryAreaWithinOneCycle() {
        let seen = Set((0 ..< FocusArea.allCases.count).map { FocusArea.at($0).label })
        XCTAssertEqual(seen.count, FocusArea.allCases.count)
    }

    func testRotationHandlesNegativeCursor() {
        XCTAssertEqual(FocusArea.at(-1), FocusArea.at(FocusArea.allCases.count - 1))
        XCTAssertEqual(FocusArea.at(-FocusArea.allCases.count), FocusArea.at(0))
    }

    // MARK: RepeatPolicy

    func testRepeatOfferedWhenScoreHighRecentAndNotDisliked() {
        XCTAssertTrue(RepeatPolicy.shouldOffer(lastScore: 8, feelingRaw: Feeling.good.rawValue,
                                               age: 3600, isOffline: false))
        XCTAssertTrue(RepeatPolicy.shouldOffer(lastScore: 7, feelingRaw: nil,
                                               age: 0, isOffline: false))
    }

    func testRepeatNotOfferedBelowThreshold() {
        XCTAssertFalse(RepeatPolicy.shouldOffer(lastScore: 6, feelingRaw: nil, age: 3600, isOffline: false))
    }

    func testRepeatNotOfferedWhenDisliked() {
        XCTAssertFalse(RepeatPolicy.shouldOffer(lastScore: 9, feelingRaw: Feeling.bad.rawValue,
                                                age: 3600, isOffline: false))
    }

    func testRepeatNotOfferedWhenStale() {
        XCTAssertFalse(RepeatPolicy.shouldOffer(lastScore: 9, feelingRaw: nil,
                                                age: 25 * 3600, isOffline: false))
    }

    func testRepeatNotOfferedForOfflineRoutine() {
        XCTAssertFalse(RepeatPolicy.shouldOffer(lastScore: 9, feelingRaw: nil,
                                                age: 3600, isOffline: true))
    }
}
