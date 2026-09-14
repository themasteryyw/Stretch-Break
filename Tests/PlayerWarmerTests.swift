import XCTest
import WebKit
@testable import StretchBreak

@MainActor
final class PlayerWarmerTests: XCTestCase {

    private func vid(_ id: String) -> StretchVideo {
        StretchVideo(id: id, title: id, channel: "c", durationSec: 240,
                     areas: [.lowerBack], intensity: .gentle)
    }

    func testWarmPicksSomethingOutsideRecentWindow() {
        let pool = (1...8).map { vid("v\($0)") }
        PlayerWarmer.shared.warm(from: pool, avoiding: ["v1", "v2", "v3"])
        let warmed = try? XCTUnwrap(PlayerWarmer.shared.warmedVideo)
        XCTAssertNotNil(warmed)
        XCTAssertFalse(["v1", "v2", "v3"].contains(warmed?.id ?? ""))
    }

    func testClaimReturnsNilForNonMatchingVideo() {
        PlayerWarmer.shared.warm(from: [vid("match")], avoiding: [])
        XCTAssertEqual(PlayerWarmer.shared.warmedVideo?.id, "match")
        XCTAssertNil(PlayerWarmer.shared.claim(videoID: "other", handler: Dummy()))
        XCTAssertEqual(PlayerWarmer.shared.warmedVideo?.id, "match", "a mismatched claim must not consume the warm view")
    }

    func testClaimHandsOffAndClearsOnMatch() {
        PlayerWarmer.shared.warm(from: [vid("wanted")], avoiding: [])
        let wv = PlayerWarmer.shared.claim(videoID: "wanted", handler: Dummy())
        XCTAssertNotNil(wv)
        XCTAssertNil(PlayerWarmer.shared.warmedVideo, "warm view should be consumed after a matching claim")
        XCTAssertNil(PlayerWarmer.shared.claim(videoID: "wanted", handler: Dummy()), "can't claim twice")
    }

    func testWarmIsNoOpForEmptyPool() {
        // reset by warming a known value, then empty
        PlayerWarmer.shared.warm(from: [vid("x")], avoiding: [])
        let before = PlayerWarmer.shared.warmedVideo?.id
        PlayerWarmer.shared.warm(from: [], avoiding: [])
        XCTAssertEqual(PlayerWarmer.shared.warmedVideo?.id, before)
    }

    private final class Dummy: NSObject, WKScriptMessageHandler {
        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {}
    }
}
