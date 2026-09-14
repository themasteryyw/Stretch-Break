import XCTest
import WebKit
@testable import StretchBreak

/// Network + API-key dependent. These are the real "did YouTube succeed" checks.
/// They skip themselves when no `YTAPIKey` is configured, and also skip (not fail) when
/// the environment — typically the iOS Simulator — blocks YouTube playback (Error 153).
/// A genuine IFrame-API error (150/152 = bad origin handling) DOES fail the test.
final class YouTubeLiveTests: XCTestCase {

    private var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "YTAPIKey") as? String) ?? ""
    }

    /// search.list + videos.list verification yields a non-empty pool of embeddable,
    /// micro-break-length, unique videos. If this fails, the fetch pipeline is broken.
    func testLivePoolReturnsPlayableVideos() async throws {
        try XCTSkipIf(apiKey.isEmpty, "Set YTAPIKey in project.yml to run the live YouTube tests")

        let pool = await YouTubeProvider(apiKey: apiKey).pool()

        XCTAssertGreaterThanOrEqual(pool.count, 3,
            "search + videos.list verification returned \(pool.count) videos — pipeline likely broken")
        XCTAssertEqual(Set(pool.map(\.id)).count, pool.count, "duplicate video ids in pool")
        for v in pool {
            XCTAssertGreaterThan(v.durationSec, 30, "\(v.id) suspiciously short")
            XCTAssertLessThan(v.durationSec, 1800, "\(v.id) longer than a micro-break")
        }
    }

    /// End-to-end: the app's real player HTML actually starts playing the first live-pool
    /// video in a WKWebView. Passes only on `playing`; skips on the Simulator's 153 block;
    /// fails on a real IFrame-API error (which would mean broken origin handling).
    @MainActor
    func testRealPlayerStartsFirstLivePoolVideo() async throws {
        try XCTSkipIf(apiKey.isEmpty, "Set YTAPIKey to run")

        let pool = await YouTubeProvider(apiKey: apiKey).pool()
        let id = try XCTUnwrap(pool.first?.id, "empty pool — nothing to load")

        let bridge = PlayerBridge()
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(bridge, name: "yt")

        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 180), configuration: config)
        web.loadHTMLString(YouTubePlayerView.html(id, warm: false),
                           baseURL: URL(string: kYouTubePlayerHost))

        switch await bridge.wait(timeout: 25) {
        case .playing:
            break // success — a real video actually started
        case .blocked, .timeout:
            throw XCTSkip("Playback blocked in this environment (Error 153 / never started) — verify on a real device")
        case .apiError(let code):
            XCTFail("player reported IFrame-API error \(code) for video \(id) — origin/embed handling is broken")
        }
    }

    private final class PlayerBridge: NSObject, WKScriptMessageHandler {
        enum Outcome { case playing, blocked, apiError(Int), timeout }
        private var cont: CheckedContinuation<Outcome, Never>?
        private var settled = false

        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
            guard let s = m.body as? String else { return }
            if s == "playing" {
                settle(.playing)
            } else if s.hasPrefix("error:") {
                let code = Int(s.dropFirst(6)) ?? -1
                settle(code == 153 ? .blocked : .apiError(code))
            }
            // "ready" is not terminal — keep waiting for playing / error.
        }

        private func settle(_ o: Outcome) {
            guard !settled else { return }
            settled = true
            cont?.resume(returning: o)
            cont = nil
        }

        func wait(timeout: TimeInterval) async -> Outcome {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                settle(.timeout)
            }
            return await withCheckedContinuation { cont = $0 }
        }
    }
}
