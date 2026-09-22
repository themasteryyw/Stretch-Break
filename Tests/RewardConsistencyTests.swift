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

    func testRewardTodayCountMatchesHomesFreshFetchAfterSave() throws {
        let ctx = try makeContext()

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        ctx.insert(SessionLog(date: yesterday, videoID: "a", videoTitle: "a", completedSec: 200))
        try ctx.save()

        let queriedBeforeInsert = try ctx.fetch(FetchDescriptor<SessionLog>(sortBy: [.init(\.date, order: .reverse)]))
        let newLog = SessionLog(videoID: "b", videoTitle: "b", completedSec: 200)
        ctx.insert(newLog)
        try ctx.save()
        let rewardToday = StatsService.todayCount(queriedBeforeInsert + [newLog])
        let rewardStreak = StatsService.streak(queriedBeforeInsert + [newLog])

        let freshFetch = try ctx.fetch(FetchDescriptor<SessionLog>(sortBy: [.init(\.date, order: .reverse)]))
        let homeToday = StatsService.todayCount(freshFetch)
        let homeStreak = StatsService.streak(freshFetch)

        XCTAssertEqual(rewardToday, homeToday,
            "Reward's today count (\(rewardToday)) must match Home's after the save settles (\(homeToday))")
        XCTAssertEqual(rewardStreak, homeStreak,
            "Reward's streak (\(rewardStreak)) must match Home's after the save settles (\(homeStreak))")
        XCTAssertEqual(homeToday, 1)
        XCTAssertEqual(homeStreak, 2)
        XCTAssertEqual(freshFetch.count, 2, "exactly two rows — no duplicate/missing insert")
    }

    func testAppendingAnAlreadyPersistedLogDoesNotDoubleCount() throws {
        let ctx = try makeContext()
        let log = SessionLog(videoID: "a", videoTitle: "a", completedSec: 200)
        ctx.insert(log)
        try ctx.save()

        let alreadyIncludes = try ctx.fetch(FetchDescriptor<SessionLog>())
        XCTAssertEqual(StatsService.todayCount(alreadyIncludes), 1)
    }
}
