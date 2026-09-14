import SwiftUI
import WebKit

let kYouTubePlayerHost = "https://www.youtube-nocookie.com"

/// YouTube IFrame-API player in a WKWebView (Google's youtube-ios-player-helper approach):
/// `loadHTMLString` with `baseURL` = the player host AND `playerVars.origin` set to match —
/// without the matching origin the API handshake fails and videos throw 150/152.
///
/// YouTube's *"configuration error / Error 15x"* overlay is NOT an IFrame-API `onError`
/// code (those are only 2, 5, 100, 101, 150) — it's an anti-abuse block, common when the
/// page is an HTML string and/or the traffic is from the iOS Simulator. The error UI lives
/// inside the cross-origin iframe so we can't read it; instead we watch `getPlayerState()`
/// and, if playback never starts, surface `error:153` so the app moves on.
///
/// If `PlayerWarmer` has a webview pre-built for this exact video, we adopt it (player and
/// iframe API are already loaded → near-instant start) and just repoint the message bridge.
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    var onEnded: () -> Void = {}
    var onError: (Int) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        if let warmed = PlayerWarmer.shared.claim(videoID: videoID, handler: context.coordinator) {
            return warmed
        }
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "yt")

        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        web.backgroundColor = .black
        web.loadHTMLString(Self.html(videoID, warm: false), baseURL: URL(string: kYouTubePlayerHost))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        private let parent: YouTubePlayerView
        init(_ parent: YouTubePlayerView) { self.parent = parent }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let text = message.body as? String else { return }
            if text == "ended" {
                parent.onEnded()
            } else if text.hasPrefix("error:") {
                parent.onError(Int(text.dropFirst(6)) ?? -1)
            }
        }
    }

    /// `warm: true` builds the player but does not autoplay and does not start the
    /// no-playback watchdog — `PlayerWarmer.claim` calls `startPlayback()` on hand-off.
    static func html(_ id: String, warm: Bool) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <style>html,body{margin:0;background:#000;height:100%;overflow:hidden}#p{width:100%;height:100%}</style>
        </head>
        <body>
          <div id="p"></div>
          <script src="https://www.youtube.com/iframe_api"></script>
          <script>
            var player, errorSent = false, watching = false;
            function post(m){ try { window.webkit.messageHandlers.yt.postMessage(m); } catch (e) {} }
            function fail(code){ if (!errorSent) { errorSent = true; post('error:' + code); } }

            function startPlayback() {
              try { player.playVideo(); } catch (e) {}
              if (watching) return;
              watching = true;
              var waited = 0;
              var w = setInterval(function () {
                waited += 1500;
                var s = -99;
                try { s = player.getPlayerState(); } catch (e) {}
                if (s === 1 || s === 3) { clearInterval(w); post('playing'); return; }
                if (waited >= 7000) { clearInterval(w); fail(153); }
              }, 1500);
            }

            function onYouTubeIframeAPIReady() {
              player = new YT.Player('p', {
                videoId: '\(id)',
                host: '\(kYouTubePlayerHost)',
                playerVars: {
                  playsinline: 1, rel: 0, autoplay: \(warm ? 0 : 1), fs: 0,
                  enablejsapi: 1, origin: '\(kYouTubePlayerHost)'
                },
                events: {
                  onReady: function () { post('ready'); \(warm ? "" : "startPlayback();") },
                  onStateChange: function (e) { if (e.data === YT.PlayerState.ENDED) post('ended'); },
                  onError: function (e) { fail(e.data); }
                }
              });
            }
          </script>
        </body>
        </html>
        """
    }
}
