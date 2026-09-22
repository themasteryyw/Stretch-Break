import XCTest
@testable import StretchBreak

final class StatsTests: XCTestCase {

    private func log(daysAgo: Int, sec: Int = 180) -> SessionLog {
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return SessionLog(date: d, videoID: "v", videoTitle: "v", completedSec: sec)
    }

    func testComputedDailyGoalMatchesScheduleWindow() {
        XCTAssertEqual(Cfg.computedDailyGoal(startHour: 9, endHour: 18, intervalMin: 60), 10)
        XCTAssertEqual(Cfg.computedDailyGoal(startHour: 9, endHour: 18, intervalMin: 120), 5)
        XCTAssertEqual(Cfg.computedDailyGoal(startHour: 9, endHour: 10, intervalMin: 60), 2)
    }

    func testComputedDailyGoalNeverGoesBelowOne() {
        XCTAssertGreaterThanOrEqual(Cfg.computedDailyGoal(startHour: 9, endHour: 9, intervalMin: 60), 1)
        XCTAssertGreaterThanOrEqual(Cfg.computedDailyGoal(startHour: 18, endHour: 9, intervalMin: 60), 1)
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

    func testAppendingTodaysSessionExtendsStreakConsistentlyWithTodayCount() {
        let priorLogs = [log(daysAgo: 1), log(daysAgo: 2)]
        let allLogs = priorLogs + [log(daysAgo: 0)]
        XCTAssertEqual(StatsService.todayCount(allLogs), 1)
        XCTAssertEqual(StatsService.streak(allLogs), 3, "today's session should extend the streak to 3")
    }
}
