import XCTest
@testable import StretchBreak

final class StatsTests: XCTestCase {

    private func log(daysAgo: Int, sec: Int = 180) -> SessionLog {
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return SessionLog(date: d, videoID: "v", videoTitle: "v", completedSec: sec)
    }

    func testTodayCount() {
        XCTAssertEqual(StatsService.todayCount([log(daysAgo: 0), log(daysAgo: 0), log(daysAgo: 1)]), 2)
        XCTAssertEqual(StatsService.todayCount([]), 0)
    }

    func testMinutesThisWeek() {
        let logs = [log(daysAgo: 0, sec: 300), log(daysAgo: 2, sec: 300), log(daysAgo: 10, sec: 600)]
        XCTAssertEqual(StatsService.minutesThisWeek(logs), 10)   // only the two within 7 days: 600s
    }

    func testStreakConsecutiveDays() {
        XCTAssertEqual(StatsService.streak([log(daysAgo: 0), log(daysAgo: 1), log(daysAgo: 2)]), 3)
    }

    func testStreakEmpty() {
        XCTAssertEqual(StatsService.streak([]), 0)
    }

    func testStreakTodayMissingCountsFromYesterday() {
        XCTAssertEqual(StatsService.streak([log(daysAgo: 1), log(daysAgo: 2)]), 2)
    }

    func testStreakSingleFreezeBridgesOneDayGap() {
        // today, (gap), day-2, day-3
        XCTAssertEqual(StatsService.streak([log(daysAgo: 0), log(daysAgo: 2), log(daysAgo: 3)]), 3)
    }

    func testStreakTwoDayGapBreaks() {
        XCTAssertEqual(StatsService.streak([log(daysAgo: 0), log(daysAgo: 3)]), 1)
    }

    func testStreakCountsMultipleSessionsOnSameDayOnce() {
        XCTAssertEqual(StatsService.streak([log(daysAgo: 0), log(daysAgo: 0), log(daysAgo: 1)]), 2)
    }
}
