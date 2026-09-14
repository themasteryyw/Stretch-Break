import Foundation
import UserNotifications

// MARK: - Config (UserDefaults-backed, defaults mirrored in @AppStorage in the views)

enum Cfg {
    static var startHour: Int      { int("startHour", 9) }
    static var endHour: Int        { int("endHour", 18) }
    static var intervalMin: Int    { max(15, int("intervalMin", 60)) }
    static var activeDaysMask: Int { int("activeDaysMask", 62) }   // Mon–Fri (bits for weekday 2…6)
    static var goalPerDay: Int     { int("goalPerDay", 8) }
    static var onboarded: Bool     { bool("onboarded", false) }
    static var askPain: Bool       { bool("askPain", true) }

    static func weekdayEnabled(_ weekday: Int, mask: Int? = nil) -> Bool {
        ((mask ?? activeDaysMask) >> (weekday - 1)) & 1 == 1
    }
    private static func int(_ k: String, _ d: Int) -> Int {
        UserDefaults.standard.object(forKey: k) as? Int ?? d
    }
    private static func bool(_ k: String, _ d: Bool) -> Bool {
        UserDefaults.standard.object(forKey: k) as? Bool ?? d
    }
}

// MARK: - Notification scheduling

enum NotificationScheduler {
    static let center = UNUserNotificationCenter.current()
    static let categoryID = "STRETCH"
    private static let maxPending = 60

    /// 22 rotating reminder messages per language, covering the whole body — not just
    /// the lower back / sciatic area — so the same line rarely repeats.
    static let promptsEN = [
        "Time to stand up 🧘 Take 3 minutes",
        "Sitting break — loosen up your hips",
        "Your sciatic nerve says thanks. Quick stretch?",
        "Stand up! Roll those shoulders 🌀",
        "3-minute micro-stretch, then back to focus",
        "Shift position, get the blood moving 🩵",
        "Your neck's been in one spot too long — reset it",
        "Quick stretch break: unlock those hips",
        "Give your lower back a breather",
        "Stand tall, open up that chest 🌿",
        "Wrists tired from typing? Give them a stretch",
        "Legs feel stiff? Time for a quick stretch",
        "A short break now beats a sore back later",
        "Your body could use a 3-minute reset",
        "Get up, shake it out, come back sharper",
        "Time to move — your future self will thank you",
        "Tight shoulders? Let's fix that in 3 minutes",
        "Desk posture check — time for a stretch",
        "Stretch break: hamstrings and hips need love",
        "Reset your spine with a quick stretch",
        "Ankles and calves have been idle — wake them up",
        "You've earned a 3-minute stretch break"
    ]
    static let promptsZH = [
        "起身時間到了 🧘 花 3 分鐘動一動",
        "坐太久了 — 放鬆一下髖部吧",
        "你的坐骨神經說聲謝謝，來個伸展？",
        "起來動一動！轉轉肩膀 🌀",
        "3 分鐘微伸展，然後回去專心",
        "換個姿勢，讓血液循環一下 🩵",
        "脖子固定太久了，放鬆一下吧",
        "伸展小休息：解放一下髖部",
        "讓下背喘口氣",
        "站起來，展開胸口 🌿",
        "手腕打字打累了嗎？伸展一下",
        "腿覺得僵硬嗎？該伸展了",
        "現在稍微休息一下，勝過之後腰痠背痛",
        "身體需要 3 分鐘重新開機",
        "起來甩一甩，回來更有精神",
        "動一動吧 — 未來的你會感謝現在的你",
        "肩膀緊繃嗎？3 分鐘幫你放鬆",
        "檢查一下坐姿 — 該伸展了",
        "伸展時間：大腿後側和髖部需要照顧",
        "來個伸展，讓脊椎重新歸位",
        "腳踝和小腿太久沒動了，喚醒它們",
        "你值得這 3 分鐘的伸展休息"
    ]
    private static var prompts: [String] {
        AppLanguage.current == .zh ? promptsZH : promptsEN
    }

    static func requestAuth() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Re-run after a language change so notification action buttons pick up the new titles.
    static func registerCategory() {
        let start  = UNNotificationAction(identifier: "START",  title: t(.notifActionStart), options: [.foreground])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: t(.notifActionSnooze))
        let skip   = UNNotificationAction(identifier: "SKIP",   title: t(.notifActionSkip), options: [.destructive])
        let cat = UNNotificationCategory(identifier: categoryID,
                                        actions: [start, snooze, skip],
                                        intentIdentifiers: [])
        center.setNotificationCategories([cat])
    }

    /// Rolling schedule for the next 8 days, capped at `maxPending`.
    static func reschedule() async {
        guard await authStatus() == .authorized else { return }
        center.removeAllPendingNotificationRequests()

        let cal = Calendar.current
        let now = Date()
        var scheduled = 0

        for dayOffset in 0..<8 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = cal.component(.weekday, from: day)
            guard Cfg.weekdayEnabled(weekday) else { continue }

            var minute = Cfg.startHour * 60
            let endMinute = Cfg.endHour * 60
            while minute <= endMinute {
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = minute / 60
                comps.minute = minute % 60

                if let fire = cal.date(from: comps), fire > now, scheduled < maxPending {
                    let content = UNMutableNotificationContent()
                    content.title = "StretchBreak"
                    content.body = prompts.randomElement()!
                    content.sound = .default
                    content.categoryIdentifier = categoryID

                    let trigger = UNCalendarNotificationTrigger(
                        dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                        repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "stretch-\(Int(fire.timeIntervalSince1970))",
                        content: content, trigger: trigger)
                    try? await center.add(request)
                    scheduled += 1
                }
                minute += Cfg.intervalMin
            }
        }
    }

    static func snooze() async {
        let content = UNMutableNotificationContent()
        content.title = "StretchBreak"
        content.body = t(.notifSnoozeBody)
        content.sound = .default
        content.categoryIdentifier = categoryID
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "snooze-\(UUID().uuidString)",
                                                    content: content, trigger: trigger))
    }

    static func cancelToday() {
        let cal = Calendar.current
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { req in
                guard let trigger = req.trigger as? UNCalendarNotificationTrigger,
                      let next = trigger.nextTriggerDate() else { return false }
                return cal.isDateInToday(next)
            }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    static func nextFireDate() -> Date? {
        let cal = Calendar.current
        let now = Date()
        for dayOffset in 0..<8 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = cal.component(.weekday, from: day)
            guard Cfg.weekdayEnabled(weekday) else { continue }
            var minute = Cfg.startHour * 60
            while minute <= Cfg.endHour * 60 {
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = minute / 60
                comps.minute = minute % 60
                if let fire = cal.date(from: comps), fire > now { return fire }
                minute += Cfg.intervalMin
            }
        }
        return nil
    }
}

// MARK: - Video sources

protocol VideoProvider {
    func pool() async -> [StretchVideo]
}

/// Live YouTube search, rotating queries by body area. Needs a Data API v3 key.
struct YouTubeProvider: VideoProvider {
    let apiKey: String

    private static let queries: [(q: String, areas: [BodyArea], intensity: Intensity)] = [
        ("piriformis stretch follow along 5 minutes", [.piriformis, .glutes], .gentle),
        ("sciatica hip flexor stretch routine follow along", [.hipFlexors, .lowerBack], .gentle),
        ("hamstring stretch for lower back pain", [.hamstrings, .lowerBack], .gentle),
        ("thoracic spine mobility routine 5 min", [.thoracic, .neck], .moderate),
        ("desk break full body stretch 3 minutes", BodyArea.allCases, .gentle),
        ("gentle lower back stretch routine standing", [.lowerBack, .glutes], .gentle),
        ("shoulder mobility stretch routine standing", [.shoulders, .neck], .gentle),
        ("chest opener doorway stretch routine", [.chest, .shoulders], .gentle),
        ("wrist forearm stretch for typing desk", [.wristsForearms], .gentle),
        ("quad stretch standing routine follow along", [.quads, .hipFlexors], .gentle),
        ("calf ankle stretch standing routine", [.calvesAnkles], .gentle)
    ]

    func pool() async -> [StretchVideo] {
        var found: [String: StretchVideo] = [:]        // id -> video (search result, unverified)

        for spec in Self.queries {
            var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
            comps.queryItems = [
                .init(name: "part", value: "snippet"),
                .init(name: "q", value: spec.q),
                .init(name: "type", value: "video"),
                .init(name: "videoEmbeddable", value: "true"),
                .init(name: "videoDuration", value: "medium"),
                .init(name: "maxResults", value: "8"),
                .init(name: "relevanceLanguage", value: "en"),
                .init(name: "safeSearch", value: "strict"),
                .init(name: "key", value: apiKey)
            ]
            guard let data = await get(comps.url),
                  let decoded = try? JSONDecoder().decode(YTSearchResponse.self, from: data)
            else { continue }

            for item in decoded.items where found[item.id.videoId] == nil {
                found[item.id.videoId] = StretchVideo(
                    id: item.id.videoId,
                    title: item.snippet.title.htmlDecoded,
                    channel: item.snippet.channelTitle,
                    durationSec: 300,
                    areas: spec.areas,
                    intensity: spec.intensity,
                    source: "youtube")
            }
        }
        guard !found.isEmpty else { return [] }

        // Verify with videos.list: keep only public + embeddable, and use real durations.
        // search.list's videoEmbeddable filter is unreliable; this pass kills the 150/152 errors.
        let verified = await verify(Array(found.keys))
        let all: [StretchVideo] = found.values.compactMap { video in
            guard let meta = verified[video.id], meta.embeddable, meta.isPublic else { return nil }
            var v = video
            if meta.durationSec > 0 { v = StretchVideo(id: v.id, title: v.title, channel: v.channel,
                                                       durationSec: meta.durationSec, areas: v.areas,
                                                       intensity: v.intensity, source: v.source) }
            return v
        }
        // Prefer genuine micro-breaks (~2–8 min); fall back to the full set if that's too thin.
        let preferred = all.filter { (90...480).contains($0.durationSec) }
        return preferred.count >= 3 ? preferred : all
    }

    private struct Meta { let embeddable: Bool; let isPublic: Bool; let durationSec: Int }

    private func verify(_ ids: [String]) async -> [String: Meta] {
        var out: [String: Meta] = [:]
        for chunk in stride(from: 0, to: ids.count, by: 50).map({ Array(ids[$0..<min($0 + 50, ids.count)]) }) {
            var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
            comps.queryItems = [
                .init(name: "part", value: "status,contentDetails"),
                .init(name: "id", value: chunk.joined(separator: ",")),
                .init(name: "key", value: apiKey)
            ]
            guard let data = await get(comps.url),
                  let decoded = try? JSONDecoder().decode(YTVideosResponse.self, from: data)
            else { continue }
            for item in decoded.items {
                out[item.id] = Meta(
                    embeddable: item.status.embeddable,
                    isPublic: item.status.privacyStatus == "public",
                    durationSec: Self.parseISO8601Duration(item.contentDetails.duration))
            }
        }
        return out
    }

    private func get(_ url: URL?) async -> Data? {
        guard let url else { return nil }
        var request = URLRequest(url: url)
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        return try? await URLSession.shared.data(for: request).0
    }

    /// "PT4M30S" -> 270
    static func parseISO8601Duration(_ s: String) -> Int {
        var total = 0, number = 0
        for ch in s {
            if let d = ch.wholeNumberValue { number = number * 10 + d }
            else if ch == "H" { total += number * 3600; number = 0 }
            else if ch == "M" { total += number * 60; number = 0 }
            else if ch == "S" { total += number; number = 0 }
            else { number = 0 }   // 'P', 'T'
        }
        return total
    }
}

struct YTSearchResponse: Codable {
    struct Item: Codable { let id: ID; let snippet: Snippet }
    struct ID: Codable { let videoId: String }
    struct Snippet: Codable { let title: String; let channelTitle: String }
    let items: [Item]
}

struct YTVideosResponse: Codable {
    struct Item: Codable { let id: String; let status: Status; let contentDetails: ContentDetails }
    struct Status: Codable { let privacyStatus: String; let embeddable: Bool }
    struct ContentDetails: Codable { let duration: String }
    let items: [Item]
}

/// Whether to offer repeating the last stretch because the sore area still scored high.
enum RepeatPolicy {
    static let highScore = 7
    static let maxAge: TimeInterval = 24 * 3600

    static func shouldOffer(lastScore: Int, feelingRaw: Int?, age: TimeInterval, isOffline: Bool) -> Bool {
        !isOffline
            && age >= 0 && age < maxAge
            && feelingRaw != Feeling.bad.rawValue
            && lastScore >= highScore
    }
}

private extension String {
    var htmlDecoded: String {
        replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

// MARK: - Recommender

enum Recommender {
    /// Picks the next video: never repeats within a sliding window, prefers unseen,
    /// weights by rating + body-area rotation + learned difficulty, then weighted-random.
    static func next(from pool: [StretchVideo],
                     stats: [String: VideoStat],
                     recentIDs: [String],
                     recentAreas: [BodyArea]) -> StretchVideo? {
        guard !pool.isEmpty else { return nil }

        let window = min(pool.count - 1, 10)
        let recentSet = Set(recentIDs.prefix(window))

        var candidates = pool.filter { !recentSet.contains($0.id) && !(stats[$0.id]?.isBroken ?? false) }
        if candidates.isEmpty { candidates = pool.filter { !(stats[$0.id]?.isBroken ?? false) } }
        if candidates.isEmpty { candidates = pool }

        let dislikedIDs = Set(stats.values.filter { $0.feeling == .bad }.map(\.videoID))
        let notDisliked = candidates.filter { !dislikedIDs.contains($0.id) }
        if !notDisliked.isEmpty { candidates = notDisliked }

        let hardVotes = stats.values.filter { $0.feedback == .tooHard }.count
        let easyVotes = stats.values.filter { $0.feedback == .tooEasy }.count
        let recentAreaSet = Set(recentAreas.prefix(3))

        func score(_ v: StretchVideo) -> Double {
            var s = 1.0
            let stat = stats[v.id]
            if (stat?.timesPlayed ?? 0) == 0 { s += 2.0 }
            if let f = stat?.feeling { s += Double(f.rawValue - 2) * 0.6 }
            if Set(v.areas).isDisjoint(with: recentAreaSet) { s += 0.6 }
            if hardVotes > easyVotes, v.intensity == .gentle { s += 0.4 }
            if easyVotes > hardVotes, v.intensity == .moderate { s += 0.4 }
            return max(0.05, s)
        }

        let weighted = candidates.map { ($0, score($0)) }
        let total = weighted.reduce(0) { $0 + $1.1 }
        var r = Double.random(in: 0..<max(total, 0.0001))
        for (video, w) in weighted {
            r -= w
            if r <= 0 { return video }
        }
        return weighted.last?.0
    }
}

// MARK: - Stats

enum StatsService {
    static func todayCount(_ logs: [SessionLog]) -> Int {
        logs.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    static func minutesThisWeek(_ logs: [SessionLog]) -> Int {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) else { return 0 }
        return logs.filter { $0.date > weekAgo }.reduce(0) { $0 + $1.completedSec } / 60
    }

    /// Consecutive days with ≥1 session. One "freeze" bridges a single gap.
    static func streak(_ logs: [SessionLog]) -> Int {
        let cal = Calendar.current
        let days = Set(logs.map { cal.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var freezesLeft = 1
        var day = cal.startOfDay(for: .now)
        if !days.contains(day) {                       // today still in progress
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        while true {
            if days.contains(day) {
                streak += 1
            } else if freezesLeft > 0, streak > 0 {
                freezesLeft -= 1
            } else {
                break
            }
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }
}

// MARK: - YouTube URL parsing

enum YouTubeURL {
    static func id(from raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: s) else { return nil }
        if comps.host?.contains("youtu.be") == true {
            return comps.path.split(separator: "/").first.map(String.init)
        }
        if let v = comps.queryItems?.first(where: { $0.name == "v" })?.value { return v }
        if comps.path.contains("/shorts/") || comps.path.contains("/embed/") {
            return comps.path.split(separator: "/").last.map(String.init)
        }
        return nil
    }
}
