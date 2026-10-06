import XCTest
import SwiftData
@testable import StretchBreak

@MainActor
final class RewardConsistencyTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([VideoStat.self, SessionLog.self, UserVideo.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testRewardTodayCountMatchesHomesFreshFetchWhenQueryHasNotYetRefreshed() throws {
        let ctx = try makeContext()

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        ctx.insert(SessionLog(date: yesterday, videoID: "a", videoTitle: "a", completedSec: 200))
        try ctx.save()

        let staleSnapshot = try ctx.fetch(FetchDescriptor<SessionLog>(sortBy: [.init(\.date, order: .reverse)]))
        let newLog = SessionLog(videoID: "b", videoTitle: "b", completedSec: 200)
        ctx.insert(newLog)
        try ctx.save()

        let logsForReward = SessionPlanner.logsIncludingSession(staleSnapshot, newLog: newLog)
        let rewardToday = StatsService.todayCount(logsForReward)
        let rewardStreak = StatsService.streak(logsForReward)

        let freshFetch = try ctx.fetch(FetchDescriptor<SessionLog>(sortBy: [.init(\.date, order: .reverse)]))
        let homeToday = StatsService.todayCount(freshFetch)
        let homeStreak = StatsService.streak(freshFetch)

        XCTAssertEqual(rewardToday, homeToday)
        XCTAssertEqual(rewardStreak, homeStreak)
        XCTAssertEqual(homeToday, 1)
        XCTAssertEqual(homeStreak, 2)
    }

    /// Regression for a 2026-09-22 report — Reward showed "2" for today while Home's real
    /// count was "1". The earlier fix (`logs + [newLog]`) assumed the @Query snapshot never
    /// refreshes before this code runs, but it sometimes does, so blindly appending double-
    /// counted the just-saved session. `logsIncludingSession` checks first.
    func testRewardTodayCountDoesNotDoubleCountWhenQueryHasAlreadyRefreshed() throws {
        let ctx = try makeContext()
        let newLog = SessionLog(videoID: "a", videoTitle: "a", completedSec: 200)
        ctx.insert(newLog)
        try ctx.save()

        let freshSnapshot = try ctx.fetch(FetchDescriptor<SessionLog>())
        XCTAssertTrue(freshSnapshot.contains { $0.persistentModelID == newLog.persistentModelID })

        let logsForReward = SessionPlanner.logsIncludingSession(freshSnapshot, newLog: newLog)
        XCTAssertEqual(logsForReward.count, 1, "must not append a session the query already includes")
        XCTAssertEqual(StatsService.todayCount(logsForReward), 1)
    }

    func testLogsIncludingSessionAppendsWhenMissing() throws {
        let ctx = try makeContext()
        let existing = SessionLog(videoID: "a", videoTitle: "a", completedSec: 200)
        ctx.insert(existing)
        try ctx.save()
        let staleSnapshot = try ctx.fetch(FetchDescriptor<SessionLog>())

        let newLog = SessionLog(videoID: "b", videoTitle: "b", completedSec: 200)
        let result = SessionPlanner.logsIncludingSession(staleSnapshot, newLog: newLog)
        XCTAssertEqual(result.count, 2)
    }
}
