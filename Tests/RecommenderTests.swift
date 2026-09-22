import XCTest
@testable import StretchBreak

final class RecommenderTests: XCTestCase {

    private func vid(_ id: String,
                     areas: [BodyArea] = [.lowerBack],
                     intensity: Intensity = .gentle) -> StretchVideo {
        StretchVideo(id: id, title: id, channel: "c", durationSec: 240, areas: areas, intensity: intensity)
    }

    func testEmptyPoolReturnsNil() {
        XCTAssertNil(Recommender.next(from: [], stats: [:], recentIDs: [], recentAreas: []))
    }

    func testNeverRepeatsWithinRecentWindow() {
        let pool = (1...12).map { vid("v\($0)") }
        let recent = ["v1", "v2", "v3", "v4", "v5"]
        for _ in 0..<200 {
            let pick = Recommender.next(from: pool, stats: [:], recentIDs: recent, recentAreas: [])
            XCTAssertNotNil(pick)
            XCTAssertFalse(recent.contains(pick!.id), "picked a video from the recent window")
        }
    }

    func testExcludesBrokenVideos() {
        let pool = [vid("good"), vid("broken")]
        let s = VideoStat(videoID: "broken"); s.isBroken = true
        for _ in 0..<30 {
            XCTAssertEqual(Recommender.next(from: pool, stats: ["broken": s],
                                           recentIDs: [], recentAreas: [])?.id, "good")
        }
    }

    func testExcludesDislikedVideos() {
        let pool = [vid("liked"), vid("disliked")]
        let s = VideoStat(videoID: "disliked"); s.feelingRaw = Feeling.bad.rawValue
        for _ in 0..<30 {
            XCTAssertEqual(Recommender.next(from: pool, stats: ["disliked": s],
                                           recentIDs: [], recentAreas: [])?.id, "liked")
        }
    }

    func testStillReturnsSomethingWhenEveryCandidateIsFilteredOut() {
        let pool = [vid("only")]
        let s = VideoStat(videoID: "only"); s.isBroken = true
        // broken AND recent — must degrade gracefully, never return nil for a non-empty pool
        XCTAssertNotNil(Recommender.next(from: pool, stats: ["only": s],
                                        recentIDs: ["only"], recentAreas: []))
    }

    func testRerollExcludesTheCurrentlyPlayingVideoEvenInANarrowPool() {
        let pool = [vid("current"), vid("alternative")]
        for _ in 0..<50 {
            let pick = Recommender.next(from: pool, stats: [:], recentIDs: ["current"], recentAreas: [])
            XCTAssertEqual(pick?.id, "alternative", "reroll must not silently hand back the video already on screen")
        }
    }

    func testPrefersUnseenOverHeavilyPlayed() {
        let pool = [vid("seen"), vid("fresh")]
        let seen = VideoStat(videoID: "seen"); seen.timesPlayed = 12
        var freshWins = 0
        let trials = 400
        for _ in 0..<trials {
            if Recommender.next(from: pool, stats: ["seen": seen],
                                recentIDs: [], recentAreas: [])?.id == "fresh" {
                freshWins += 1
            }
        }
        XCTAssertGreaterThan(freshWins, trials * 55 / 100, "unseen video should win clearly more often")
    }
}
