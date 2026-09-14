import Foundation
import WebKit

/// Keeps one hidden WKWebView with the YouTube player + iframe API already loaded for the
/// *next* likely video, so tapping "Stretch now" starts almost immediately instead of
/// paying the ~2–3 s iframe-API + player-init cost.
@MainActor
final class PlayerWarmer {
    static let shared = PlayerWarmer()
    private init() {}

    private var web: WKWebView?
    private(set) var warmedVideo: StretchVideo?

    /// Pre-build the player for a plausible next pick. Cheap no-op if already warmed for it.
    func warm(from pool: [StretchVideo], avoiding recent: [String]) {
        guard !pool.isEmpty else { return }
        let recentSet = Set(recent.prefix(10))
        let candidates = pool.filter { !recentSet.contains($0.id) }
        guard let pick = candidates.randomElement() ?? pool.first,
              pick.id != warmedVideo?.id else { return }

        warmedVideo = pick
        let wv = web ?? Self.makeWebView()
        web = wv
        wv.loadHTMLString(YouTubePlayerView.html(pick.id, warm: true),
                          baseURL: URL(string: kYouTubePlayerHost))
    }

    /// Hand the warm webview to a session if it matches `videoID`; else nil (fresh load).
    func claim(videoID: String, handler: WKScriptMessageHandler) -> WKWebView? {
        guard videoID == warmedVideo?.id, let wv = web else { return nil }
        web = nil
        warmedVideo = nil

        let ucc = wv.configuration.userContentController
        ucc.removeScriptMessageHandler(forName: "yt")
        ucc.add(handler, name: "yt")
        wv.scrollView.isScrollEnabled = false
        // player object already exists — start it and arm the no-playback watchdog
        wv.evaluateJavaScript("if (window.player && player.playVideo) { startPlayback(); }")
        return wv
    }

    private static func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(Sink.shared, name: "yt")   // swallow 'ready' while warming

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        return web
    }

    private final class Sink: NSObject, WKScriptMessageHandler {
        static let shared = Sink()
        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {}
    }
}
