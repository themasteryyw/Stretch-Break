import Foundation
import SwiftData
import UserNotifications

// MARK: - Config (UserDefaults-backed, defaults mirrored in @AppStorage in the views)

enum Cfg {
    static var startHour: Int      { int("startHour", 9) }
    static var endHour: Int        { int("endHour", 18) }
    static var intervalMin: Int    { max(15, int("intervalMin", 60)) }
    static var activeDaysMask: Int { int("activeDaysMask", 62) }   // Mon–Fri (bits for weekday 2…6)
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

    static func computedDailyGoal(startHour: Int, endHour: Int, intervalMin: Int) -> Int {
        guard intervalMin > 0, endHour > startHour else { return 1 }
        var minute = startHour * 60
        let endMinute = endHour * 60
        var count = 0
        while minute <= endMinute {
            count += 1
            minute += intervalMin
        }
        return max(1, count)
    }
}

// MARK: - Notification scheduling

enum NotificationScheduler {
    static let center = UNUserNotificationCenter.current()
    static let categoryID = "STRETCH"
    private static let maxPending = 60

    static let promptsEN = [
        "Your chair called. It needs some alone time 🪑",
        "Breaking news: your neck has filed a complaint 📰",
        "Your shoulders are up by your ears again. We can see them 👀",
        "Hips don't lie, and right now they're saying \"help\" 💃",
        "Plot twist: you stand up and stretch 🎬",
        "Your spine would like to speak to the manager",
        "Wrists: typed a lot. Thanks: none. Fix that ✋",
        "Achievement unlocked: Professional Sitter. Time to level up 🏆",
        "Your hamstrings sent a strongly worded email 📧",
        "Quads on strike. Demand: one good stretch 🪧",
        "Calves asleep? Wake them before they start snoring 😴",
        "Ankles, assemble! Roll them out 🦸",
        "Your lower back called a team meeting. You're invited",
        "Chest out, superhero pose. Nobody's watching (probably) 🦸‍♀️",
        "Loading energy... 12%. Stretch to recharge 🔋",
        "Your body called. It wants a reboot, not a coffee ☕",
        "Gravity has been winning all day. Fight back 🌍",
        "Shrimp posture detected 🦐 Straighten up!",
        "Your cat stretches 40 times a day. Just saying 🐈",
        "Pause the scroll, start the roll (shoulders, that is) 🌀",
        "Today's dare: stand up before this banner disappears ⏱️",
        "Your future self is waving from the couch. Wave back 👋",
        "Blood flow update: stuck in traffic. Clear the road 🚗",
        "Stretch now, thank yourself later. Small price, big payoff 💸",
        "Your desk isn't going anywhere. Promise 🤝",
        "Fun fact: you're about 1 cm taller in the morning. Stretch to win some back 📏",
        "Your toes forgot what the floor feels like. Remind them 🦶",
        "Hourly reminder: you have legs. Use them 🦵",
        "Reach for the ceiling like it owes you money 💰",
        "Your glutes switched to airplane mode ✈️",
        "Body fact: muscles love blood flow. Moving is free delivery 🚚",
        "Stand up. Sit down. Okay, just do the first part 🙃",
        "Side bend time. Be a banana for 10 seconds 🍌",
        "Neck rolls, nice and slow, like a sleepy owl 🦉",
        "Keep the music on. Just listen standing up 🎧",
        "Spine update available. Install now? 🔄",
        "Refill your water and stretch on the way. Two wins, one trip 💧",
        "Your inbox can wait. Your hip flexors can't 📥",
        "Fun fact: you have 600+ muscles. Pick a few and say hi 💪",
        "Roll your shoulders back. Instantly look like you have a plan 😎",
        "Stretch like you just woke up from a 10-hour nap 🥱",
        "Dinosaurs stopped moving. You know how that went 🦕",
        "Your knees asked for one squat. Just one. Very reasonable 🙏",
        "Mini mission: touch your toes, or at least wave at them 🎯"
    ]
    static let promptsZH = [
        "椅子說它需要一點私人空間 🪑",
        "插播快訊：你的脖子正式提出抗議 📰",
        "肩膀又跑到耳朵旁邊了，我們都看到了 👀",
        "髖部不會說謊，它現在在喊救命 💃",
        "劇情急轉彎：你站起來伸展了 🎬",
        "你的脊椎要求見主管",
        "手腕打了一整天字，連聲謝謝都沒有 ✋",
        "成就解鎖：職業坐坐專家 🏆 該升級了",
        "大腿後側寄了一封措辭強烈的信給你 📧",
        "大腿前側罷工中，訴求：一次好好的伸展 🪧",
        "小腿睡著了？趁它還沒打呼前叫醒它 😴",
        "腳踝們，集合！轉一轉 🦸",
        "下背召開緊急會議，你是必須出席的那位",
        "挺起胸口，擺個超人姿勢，沒人在看啦（大概）🦸‍♀️",
        "電量剩下 12%… 伸展一下來充電 🔋",
        "身體說它想重開機，不是再來一杯咖啡 ☕",
        "地心引力今天贏太多場了，反擊吧 🌍",
        "偵測到蝦子坐姿 🦐 請立刻挺直",
        "貓咪一天伸懶腰四十次，只是說說而已 🐈",
        "停止滑手機，開始轉肩膀 🌀",
        "今日挑戰：在這則通知消失前站起來 ⏱️",
        "未來的你正在沙發上跟你揮手，揮回去吧 👋",
        "血液循環快報：嚴重塞車中，快來疏通 🚗",
        "現在動一動，之後少痠痛，超划算 💸",
        "桌子不會跑掉，等你回來它還在，保證 🤝",
        "冷知識：早上的你比晚上高約 1 公分，伸展一下拿回來 📏",
        "腳趾快忘記踩地板是什麼感覺了，提醒它們一下 🦶",
        "整點提醒：你是有腿的，用一下吧 🦵",
        "雙手往天花板伸，像它欠你錢一樣 💰",
        "你的屁股已經切換成飛航模式了 ✈️",
        "身體小知識：肌肉最愛血液，動起來就是外送到府 🚚",
        "站起來，坐下。好啦，先做前半段就好 🙃",
        "側彎時間到，當 10 秒的香蕉 🍌",
        "慢慢轉脖子，像一隻想睡覺的貓頭鷹 🦉",
        "音樂繼續放，只是換你站著聽 🎧",
        "脊椎有新版本，要立即更新嗎？🔄",
        "去裝個水，順路伸展，一趟賺兩個 💧",
        "信箱可以等，你的髖屈肌等不了 📥",
        "冷知識：你全身有六百多條肌肉，挑幾條打個招呼 💪",
        "肩膀往後轉一轉，瞬間看起來很有計畫 😎",
        "像剛睡飽十小時那樣，大大伸個懶腰 🥱",
        "恐龍後來不動了，結局你也知道 🦕",
        "膝蓋只要求一個深蹲，就一個，很講理吧 🙏",
        "小任務：摸到腳趾，摸不到就跟它們揮揮手 🎯"
    ]
    private static var prompts: [String] {
        AppLanguage.current == .zh ? promptsZH : promptsEN
    }

    /// Stable per-day shuffle: no prompt repeats within a day, and rescheduling keeps the same order.
    static func promptOrder(forDay day: Int, count: Int) -> [Int] {
        var rng = SeededGenerator(seed: UInt64(bitPattern: Int64(day)))
        return Array(0..<count).shuffled(using: &rng)
    }

    static func requestAuth() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

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

            let dayNumber = Int(cal.startOfDay(for: day).timeIntervalSince1970 / 86_400)
            let order = promptOrder(forDay: dayNumber, count: prompts.count)
            var slot = 0
            var minute = Cfg.startHour * 60
            let endMinute = Cfg.endHour * 60
            while minute <= endMinute {
                defer { slot += 1 }
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = minute / 60
                comps.minute = minute % 60

                if let fire = cal.date(from: comps), fire > now, scheduled < maxPending {
                    let content = UNMutableNotificationContent()
                    content.title = "StretchBreak"
                    content.body = prompts[order[slot % order.count]]
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

    static func announceTimerDone() {
        let content = UNMutableNotificationContent()
        content.title = "StretchBreak"
        content.body = t(.timerDoneBody)
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: "timer-done-\(UUID().uuidString)",
                                         content: content, trigger: trigger), withCompletionHandler: nil)
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

    private static let queriesEN: [(q: String, areas: [BodyArea], intensity: Intensity)] = [
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
    private static let queriesZH: [(q: String, areas: [BodyArea], intensity: Intensity)] = [
        ("梨狀肌 伸展 跟著做", [.piriformis, .glutes], .gentle),
        ("坐骨神經 髖屈肌 伸展 跟著做", [.hipFlexors, .lowerBack], .gentle),
        ("大腿後側 伸展 下背痛", [.hamstrings, .lowerBack], .gentle),
        ("胸椎 活動度 伸展", [.thoracic, .neck], .moderate),
        ("久坐 全身伸展 辦公室", BodyArea.allCases, .gentle),
        ("下背 伸展 站姿 溫和", [.lowerBack, .glutes], .gentle),
        ("肩膀 活動度 伸展 站姿", [.shoulders, .neck], .gentle),
        ("胸口 伸展 門框", [.chest, .shoulders], .gentle),
        ("手腕 前臂 伸展 打字", [.wristsForearms], .gentle),
        ("大腿前側 伸展 站姿 跟著做", [.quads, .hipFlexors], .gentle),
        ("小腿 腳踝 伸展 站姿", [.calvesAnkles], .gentle)
    ]
    private static var queries: [(q: String, areas: [BodyArea], intensity: Intensity)] {
        AppLanguage.current == .zh ? queriesZH : queriesEN
    }

    static func searchURL(query: String, apiKey: String, relevanceLanguage: String = "en", regionCode: String? = nil) -> URL? {
        var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        comps.queryItems = [
            .init(name: "part", value: "snippet"),
            .init(name: "q", value: query),
            .init(name: "type", value: "video"),
            .init(name: "videoEmbeddable", value: "true"),
            // "any" returns mostly sub-minute Shorts; "medium" is 4–20 min.
            .init(name: "videoDuration", value: "medium"),
            .init(name: "maxResults", value: "20"),
            .init(name: "relevanceLanguage", value: relevanceLanguage),
            .init(name: "safeSearch", value: "strict"),
            .init(name: "key", value: apiKey)
        ]
        if let regionCode { comps.queryItems?.append(.init(name: "regionCode", value: regionCode)) }
        return comps.url
    }

    func pool() async -> [StretchVideo] {
        var found: [String: StretchVideo] = [:]        // id -> video (search result, unverified)

        for spec in Self.queries {
            let lang = AppLanguage.current
            guard let data = await get(Self.searchURL(query: spec.q, apiKey: apiKey,
                                                      relevanceLanguage: lang.youTubeRelevanceLanguage,
                                                      regionCode: lang.youTubeRegionCode)),
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
        return all.filter { StretchConfig.poolDurationRange.contains($0.durationSec) }
    }

    /// Real durations for the user's pasted links (they arrive without one).
    func durations(for ids: [String]) async -> [String: Int] {
        await verify(ids).compactMapValues { $0.durationSec > 0 ? $0.durationSec : nil }
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

enum SessionPlanner {
    /// Videos that can deliver `band`: ones inside it, plus (when fewer than two fit)
    /// shorter ones the offline routine can top up. Never returns longer videos.
    static func lengthFiltered(_ source: [StretchVideo], band: StretchBand,
                               maxPadSec: Int = RoutineMove.totalSeconds) -> [StretchVideo] {
        let inBand = source.filter { band.range.contains($0.durationSec) }
        if inBand.count >= 2 { return inBand }
        let paddable = source.filter {
            $0.durationSec < band.range.lowerBound && band.targetSec - $0.durationSec <= maxPadSec
        }
        return inBand + paddable
    }

    /// Seconds of offline routine to append after `video` so the session reaches `band`.
    static func padSeconds(for video: StretchVideo, band: StretchBand) -> Int {
        video.durationSec < band.range.lowerBound ? band.targetSec - video.durationSec : 0
    }

    static func areaFiltered(_ source: [StretchVideo], targeting areas: [BodyArea], minCount: Int = 2) -> [StretchVideo] {
        let wanted = Set(areas)
        let filtered = source.filter { !Set($0.areas).isDisjoint(with: wanted) }
        return filtered.count >= minCount ? filtered : source
    }

    static func targetedPool(_ source: [StretchVideo], askPain: Bool, targeting areas: [BodyArea]) -> [StretchVideo] {
        guard askPain else { return source }
        return areaFiltered(source, targeting: areas)
    }

    /// Length is a hard rule, body area a preference: narrow to the area only when that
    /// still leaves enough videos to rotate through.
    static func sessionPool(_ source: [StretchVideo], band: StretchBand, askPain: Bool,
                            targeting areas: [BodyArea], minRotation: Int = 4) -> [StretchVideo] {
        let fitting = lengthFiltered(source, band: band)
        guard askPain else { return fitting }
        return areaFiltered(fitting, targeting: areas, minCount: minRotation)
    }

    static func logsIncludingSession(_ logs: [SessionLog], newLog: SessionLog) -> [SessionLog] {
        let alreadyIncluded = logs.contains { $0.persistentModelID == newLog.persistentModelID }
        return alreadyIncluded ? logs : logs + [newLog]
    }

    static func timerTick(elapsed: Int, target: Int) -> (elapsed: Int, done: Bool) {
        guard elapsed < target else { return (elapsed, false) }
        let next = elapsed + 1
        return (next, next >= target)
    }
}

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

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
