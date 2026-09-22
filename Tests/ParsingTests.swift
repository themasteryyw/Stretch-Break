import XCTest
@testable import StretchBreak

final class ParsingTests: XCTestCase {

    func testYouTubeURLParsing() {
        XCTAssertEqual(YouTubeURL.id(from: "https://www.youtube.com/watch?v=abc123DEF45"), "abc123DEF45")
        XCTAssertEqual(YouTubeURL.id(from: "https://youtu.be/abc123DEF45"), "abc123DEF45")
        XCTAssertEqual(YouTubeURL.id(from: "https://www.youtube.com/watch?v=abc123DEF45&t=30s"), "abc123DEF45")
        XCTAssertEqual(YouTubeURL.id(from: "https://www.youtube.com/embed/abc123DEF45"), "abc123DEF45")
        XCTAssertEqual(YouTubeURL.id(from: "https://www.youtube.com/shorts/abc123DEF45"), "abc123DEF45")
        XCTAssertEqual(YouTubeURL.id(from: "  https://youtu.be/abc123DEF45  "), "abc123DEF45")
        XCTAssertNil(YouTubeURL.id(from: "https://example.com/foo"))
        XCTAssertNil(YouTubeURL.id(from: "not a url at all"))
    }

    func testISO8601DurationParsing() {
        XCTAssertEqual(YouTubeProvider.parseISO8601Duration("PT4M30S"), 270)
        XCTAssertEqual(YouTubeProvider.parseISO8601Duration("PT1H2M3S"), 3723)
        XCTAssertEqual(YouTubeProvider.parseISO8601Duration("PT45S"), 45)
        XCTAssertEqual(YouTubeProvider.parseISO8601Duration("PT10M"), 600)
        XCTAssertEqual(YouTubeProvider.parseISO8601Duration("PT1H"), 3600)
        XCTAssertEqual(YouTubeProvider.parseISO8601Duration("P0D"), 0)
    }

    func testSearchResponseDecoding() throws {
        let json = Data("""
        {"items":[
          {"id":{"videoId":"vid1"},"snippet":{"title":"Hip &amp; Back","channelTitle":"PT Chan"}},
          {"id":{"videoId":"vid2"},"snippet":{"title":"Piriformis","channelTitle":"Yoga"}}
        ]}
        """.utf8)
        let r = try JSONDecoder().decode(YTSearchResponse.self, from: json)
        XCTAssertEqual(r.items.count, 2)
        XCTAssertEqual(r.items[0].id.videoId, "vid1")
        XCTAssertEqual(r.items[0].snippet.channelTitle, "PT Chan")
    }

    func testSearchURLDoesNotRestrictToMediumDuration() throws {
        let url = try XCTUnwrap(YouTubeProvider.searchURL(query: "test", apiKey: "key"))
        let comps = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let duration = comps.queryItems?.first { $0.name == "videoDuration" }?.value
        XCTAssertNotEqual(duration, "medium")
        XCTAssertNotEqual(duration, "long")
        XCTAssertEqual(duration, "any")
    }

    func testVideosResponseDecoding() throws {
        let json = Data("""
        {"items":[
          {"id":"vid1","status":{"privacyStatus":"public","embeddable":true},"contentDetails":{"duration":"PT3M40S"}},
          {"id":"vid2","status":{"privacyStatus":"unlisted","embeddable":false},"contentDetails":{"duration":"PT5M"}}
        ]}
        """.utf8)
        let r = try JSONDecoder().decode(YTVideosResponse.self, from: json)
        XCTAssertTrue(r.items[0].status.embeddable)
        XCTAssertEqual(r.items[0].status.privacyStatus, "public")
        XCTAssertFalse(r.items[1].status.embeddable)
        XCTAssertEqual(YouTubeProvider.parseISO8601Duration(r.items[0].contentDetails.duration), 220)
    }
}
