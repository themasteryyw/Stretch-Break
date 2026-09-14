import Foundation

// MARK: - App language

/// Supported in-app languages. Free to switch from Settings at any time —
/// no restart needed, since every view re-reads `t(_:)` on redraw.
enum AppLanguage: String, CaseIterable, Identifiable {
    case en, zh   // zh = Traditional Chinese (繁體中文)
    var id: String { rawValue }

    var label: String {
        switch self {
        case .en: "English"
        case .zh: "繁體中文"
        }
    }

    /// Falls back to the device's preferred language on first launch, then to English.
    static var current: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: raw) {
            return lang
        }
        return Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .zh : .en
    }
}

// MARK: - Translation keys

enum L: String, CaseIterable {
    // Tabs
    case tabToday, tabHistory, tabSettings

    // Home
    case standUpsToday, dayStreak, minThisWeek, stretchNowButton
    case notifOffWarning, nextReminder, outsideReminderHours, loadingStretch

    // Session flow
    case painBeforeTitle, painAfterTitle, nextVideoButton, doneEndEarlyButton, openInYouTubeButton

    // Offline routine
    case moveCounter, skipThisOneButton, endButton

    // Repeat offer
    case repeatLastTime, repeatQuestion, repeatItButton, somethingNewButton

    // Rating
    case howWasThat, submitButton, skipButton

    // Reward
    case rewardMilestoneHeadline, rewardFirstTodayHeadline, rewardGenericHeadline
    case rewardMilestoneMessage, rewardGenericMessage
    case rewardStreakLabel, rewardTodayLabel, rewardDoneButton

    // Pain check-in
    case painNone, painSevere

    // History
    case historyChartTitle, historyPainTrendTitle, historyRecentSection
    case historyNoLogsYet, historyNavTitle

    // Settings
    case settingsNavTitle, sectionReminderHours, stepperStart, stepperEnd, intervalLabel, minUnit
    case sectionGoalPrompts, dailyGoal, askDiscomfortToggle
    case sectionAppearance, appearanceFooter
    case sectionLanguage, languageFooter
    case pasteYoutubeLinkPlaceholder, addButton, sectionVideoSources
    case videoSourcesFooterWithKey, videoSourcesFooterNoKey
    case rescheduleNotifButton, notifOffOpenSettings

    // Theme names
    case themeTeal, themeBlush, themeLatte

    // Onboarding
    case onboard1Title, onboard1Message, onboard2Title, onboard2Message
    case onboard3Title, onboard3Message
    case nextButton, allowNotifStartButton, maybeLaterButton

    // Body areas (video tagging)
    case areaPiriformis, areaGlutes, areaHipFlexors, areaHamstrings, areaLowerBack
    case areaThoracic, areaNeck, areaShoulders, areaChest, areaWristsForearms
    case areaQuads, areaCalvesAnkles

    // Focus areas (check-in rotation)
    case focusLowerBack, focusLeftHip, focusRightHip, focusHamstrings, focusNeckShoulders
    case focusPiriformis, focusUpperBack, focusChest, focusWristsForearms, focusQuads
    case focusCalvesAnkles

    // Intensity / feeling / feedback
    case intensityGentle, intensityModerate
    case feelingDislike, feelingMeh, feelingGood, feelingLoveIt
    case feedbackTooHard, feedbackJustRight, feedbackTooEasy

    // Notification actions
    case notifActionStart, notifActionSnooze, notifActionSkip, notifSnoozeBody

    // Misc user-facing labels
    case channelYourList, channelRepeat, customVideoTitle
}

/// Returns the localized string for `key` in the current `AppLanguage`.
/// Falls back to the English string (or the raw key) if a translation is missing.
func t(_ key: L) -> String {
    strings[key]?[AppLanguage.current] ?? strings[key]?[.en] ?? key.rawValue
}

/// `String(format:)` variant for templated strings (e.g. "%@" / "%d" placeholders).
func t(_ key: L, _ args: CVarArg...) -> String {
    String(format: t(key), arguments: args)
}

private let strings: [L: [AppLanguage: String]] = [
    // MARK: Tabs
    .tabToday:    [.en: "Today", .zh: "今天"],
    .tabHistory:  [.en: "History", .zh: "紀錄"],
    .tabSettings: [.en: "Settings", .zh: "設定"],

    // MARK: Home
    .standUpsToday:        [.en: "stand-ups today", .zh: "今日次數"],
    .dayStreak:            [.en: "day streak", .zh: "連續天數"],
    .minThisWeek:          [.en: "min this week", .zh: "本週分鐘"],
    .stretchNowButton:     [.en: "Stretch now · 3 min", .zh: "現在伸展 · 3 分鐘"],
    .notifOffWarning:      [.en: "Notifications are off — you won't get reminders. Turn them on in Settings",
                             .zh: "通知未開啟，不會收到休息提醒 — 前往「設定」開啟"],
    .nextReminder:         [.en: "Next reminder: %@", .zh: "下次提醒：%@"],
    .outsideReminderHours: [.en: "Outside reminder hours — adjust in Settings",
                             .zh: "目前不在提醒時段內 — 可在設定調整"],
    .loadingStretch:       [.en: "Getting your stretch ready…", .zh: "正在準備伸展內容…"],

    // MARK: Session flow
    .painBeforeTitle:   [.en: "How's your %@ right now?", .zh: "現在你的%@感覺如何？"],
    .painAfterTitle:    [.en: "And your %@ now, after stretching?", .zh: "伸展後，你的%@現在感覺如何？"],
    .nextVideoButton:   [.en: "Next video", .zh: "換一支影片"],
    .doneEndEarlyButton:[.en: "Done / end early", .zh: "完成／提早結束"],
    .openInYouTubeButton:[.en: "Open in YouTube", .zh: "在 YouTube 開啟"],

    // MARK: Offline routine
    .moveCounter:       [.en: "Move %d / %d", .zh: "第 %d／%d 組"],
    .skipThisOneButton: [.en: "Skip this one", .zh: "跳過這組"],
    .endButton:         [.en: "End", .zh: "結束"],

    // MARK: Repeat offer
    .repeatLastTime:     [.en: "Last time your %@ was %d/10.", .zh: "上次你的%@是 %d/10。"],
    .repeatQuestion:     [.en: "Want to keep working on it with the same stretch?",
                           .zh: "要用同一組 stretch 繼續嗎？"],
    .repeatItButton:     [.en: "Repeat it", .zh: "重複這組"],
    .somethingNewButton: [.en: "Try something new", .zh: "換點新的"],

    // MARK: Rating
    .howWasThat:  [.en: "How was that?", .zh: "剛剛感覺如何？"],
    .submitButton:[.en: "Submit", .zh: "送出"],
    .skipButton:  [.en: "Skip", .zh: "跳過"],

    // MARK: Reward
    .rewardMilestoneHeadline: [.en: "Amazing — %d days in a row!", .zh: "了不起，連續 %d 天了！"],
    .rewardFirstTodayHeadline:[.en: "First stretch of the day, done!", .zh: "今天的第一次伸展，完成！"],
    .rewardGenericHeadline:   [.en: "Well done — give yourself a hand", .zh: "做得很好，給自己一個掌聲"],
    .rewardMilestoneMessage:  [.en: "Remembering to take care of yourself on a busy day — that consistency is precious.",
                                .zh: "忙碌的一天裡還記得照顧自己，這份堅持很珍貴。"],
    .rewardGenericMessage:    [.en: "A few minutes to care for your body — you deserve this break.",
                                .zh: "花幾分鐘照顧身體，你值得這樣的休息。"],
    .rewardStreakLabel: [.en: "day streak", .zh: "連續天數"],
    .rewardTodayLabel:  [.en: "done today", .zh: "今日完成"],
    .rewardDoneButton:  [.en: "Done", .zh: "完成"],

    // MARK: Pain check-in
    .painNone:   [.en: "0 None", .zh: "0 不痛"],
    .painSevere: [.en: "10 Severe", .zh: "10 劇烈"],

    // MARK: History
    .historyChartTitle:     [.en: "Stand-ups per day (last 14 days)", .zh: "每日起身次數（近 14 天）"],
    .historyPainTrendTitle: [.en: "Post-stretch discomfort trend", .zh: "伸展後不適度趨勢"],
    .historyRecentSection:  [.en: "Recent", .zh: "最近紀錄"],
    .historyNoLogsYet:      [.en: "No history yet — do your first stretch!", .zh: "還沒有紀錄 — 做你的第一次伸展吧！"],
    .historyNavTitle:       [.en: "History", .zh: "紀錄"],

    // MARK: Settings
    .settingsNavTitle:    [.en: "Settings", .zh: "設定"],
    .sectionReminderHours:[.en: "Reminder hours", .zh: "提醒時段"],
    .stepperStart:        [.en: "Start: %d:00", .zh: "開始：%d:00"],
    .stepperEnd:          [.en: "End: %d:00", .zh: "結束：%d:00"],
    .intervalLabel:       [.en: "Interval", .zh: "間隔"],
    .minUnit:             [.en: "%d min", .zh: "%d 分鐘"],
    .sectionGoalPrompts:  [.en: "Goal & prompts", .zh: "目標與提示"],
    .dailyGoal:           [.en: "Daily goal: %d", .zh: "每日目標：%d"],
    .askDiscomfortToggle: [.en: "Ask discomfort each time", .zh: "每次都詢問不適度"],
    .sectionAppearance:   [.en: "Appearance", .zh: "外觀"],
    .appearanceFooter:    [
        .en: "One tap changes both the theme color and the app icon. Peach Fuzz and Mocha Mousse are real Pantone Colors of the Year (2024 / 2025).",
        .zh: "點一下同時套用主題色與 App 圖示。蜜桃絨、摩卡慕斯皆為真實的 Pantone 年度代表色（2024／2025）。"],
    .sectionLanguage:     [.en: "Language", .zh: "語言"],
    .languageFooter:      [.en: "Switch freely at any time — no restart needed.",
                            .zh: "可隨時自由切換，不需要重新啟動。"],
    .pasteYoutubeLinkPlaceholder: [.en: "Paste a YouTube link", .zh: "貼上 YouTube 連結"],
    .addButton:           [.en: "Add", .zh: "新增"],
    .sectionVideoSources: [.en: "Video sources", .zh: "影片來源"],
    .videoSourcesFooterWithKey: [
        .en: "YouTube API key set: fetches embeddable 3–5 min stretch videos, rotating by body area and avoiding repeats.",
        .zh: "已設定 YouTube API 金鑰：會抓取可嵌入的 3–5 分鐘伸展影片，依身體部位輪流且避免重複。"],
    .videoSourcesFooterNoKey: [
        .en: "No API key: uses the built-in timed routine. Add links above for your own list, or set YTAPIKey in project.yml.",
        .zh: "未設定金鑰：使用內建計時伸展組。可在上方新增自己的影片清單，或在 project.yml 設定 YTAPIKey。"],
    .rescheduleNotifButton: [.en: "Reschedule notifications", .zh: "重新排定通知"],
    .notifOffOpenSettings:  [.en: "Notifications are off — open Settings", .zh: "通知已關閉 — 前往「設定」開啟"],

    // MARK: Theme names (blush/latte follow real Pantone Colors of the Year)
    .themeTeal:  [.en: "Teal", .zh: "薄荷綠"],
    .themeBlush: [.en: "Peach Fuzz", .zh: "蜜桃絨"],
    .themeLatte: [.en: "Mocha Mousse", .zh: "摩卡慕斯"],

    // MARK: Onboarding
    .onboard1Title:  [.en: "Sitting compresses the sciatic nerve", .zh: "久坐會壓迫坐骨神經"],
    .onboard1Message:[
        .en: "A 3–5 minute micro-stretch every hour meaningfully lowers discomfort across your whole body — lower back, hips, neck, shoulders and more. This app does one thing: remind you on time and hand you a non-repeating stretch.",
        .zh: "每小時做 3–5 分鐘的微伸展，能有效降低全身的不適感 — 下背、髖部、頸肩等都涵蓋在內。這個 App 只做一件事：準時提醒你，並提供不重複的伸展內容。"],
    .onboard2Title:  [.en: "Set your working hours", .zh: "設定你的工作時段"],
    .onboard2Message:[
        .en: "Reminders fire only during the hours and days you pick — silent the rest of the time. Change it anytime in Settings.",
        .zh: "提醒只會在你選擇的時段與日子出現，其餘時間保持安靜。可以隨時在設定裡調整。"],
    .onboard3Title:  [.en: "Allow notifications", .zh: "允許通知"],
    .onboard3Message:[
        .en: "Everything is scheduled locally on your device. No network, no data leaves your phone.",
        .zh: "所有提醒都在你的裝置上本機排程，不需要網路，也不會有任何資料離開你的手機。"],
    .nextButton:             [.en: "Next", .zh: "下一步"],
    .allowNotifStartButton:  [.en: "Allow notifications & start", .zh: "允許通知並開始"],
    .maybeLaterButton:       [.en: "Maybe later", .zh: "之後再說"],

    // MARK: Body areas (video tagging)
    .areaPiriformis:     [.en: "Piriformis", .zh: "梨狀肌"],
    .areaGlutes:         [.en: "Glutes", .zh: "臀肌"],
    .areaHipFlexors:     [.en: "Hip flexors", .zh: "髖屈肌"],
    .areaHamstrings:     [.en: "Hamstrings", .zh: "大腿後側"],
    .areaLowerBack:      [.en: "Lower back", .zh: "下背"],
    .areaThoracic:       [.en: "Thoracic spine", .zh: "胸椎／上背"],
    .areaNeck:           [.en: "Neck", .zh: "頸部"],
    .areaShoulders:      [.en: "Shoulders", .zh: "肩膀"],
    .areaChest:          [.en: "Chest", .zh: "胸部"],
    .areaWristsForearms: [.en: "Wrists & forearms", .zh: "手腕／前臂"],
    .areaQuads:          [.en: "Quads", .zh: "大腿前側"],
    .areaCalvesAnkles:   [.en: "Calves & ankles", .zh: "小腿／腳踝"],

    // MARK: Focus areas (check-in rotation)
    .focusLowerBack:      [.en: "lower back", .zh: "下背"],
    .focusLeftHip:        [.en: "left hip / glute", .zh: "左髖"],
    .focusRightHip:       [.en: "right hip / glute", .zh: "右髖"],
    .focusHamstrings:     [.en: "hamstrings", .zh: "大腿後側"],
    .focusNeckShoulders:  [.en: "neck & shoulders", .zh: "頸肩"],
    .focusPiriformis:     [.en: "deep glute (piriformis)", .zh: "深層臀肌（梨狀肌）"],
    .focusUpperBack:      [.en: "upper back", .zh: "上背／胸椎"],
    .focusChest:          [.en: "chest", .zh: "胸部"],
    .focusWristsForearms: [.en: "wrists & forearms", .zh: "手腕／前臂"],
    .focusQuads:          [.en: "quads", .zh: "大腿前側"],
    .focusCalvesAnkles:   [.en: "calves & ankles", .zh: "小腿／腳踝"],

    // MARK: Intensity / feeling / feedback
    .intensityGentle:   [.en: "Gentle", .zh: "溫和"],
    .intensityModerate: [.en: "Moderate", .zh: "中等"],
    .feelingDislike:    [.en: "Dislike", .zh: "不喜歡"],
    .feelingMeh:        [.en: "Meh", .zh: "普通"],
    .feelingGood:       [.en: "Good", .zh: "不錯"],
    .feelingLoveIt:     [.en: "Love it", .zh: "喜歡"],
    .feedbackTooHard:   [.en: "Too hard", .zh: "太難"],
    .feedbackJustRight: [.en: "Just right", .zh: "剛剛好"],
    .feedbackTooEasy:   [.en: "Too easy", .zh: "太簡單"],

    // MARK: Notification actions
    .notifActionStart:  [.en: "Stretch now", .zh: "開始伸展"],
    .notifActionSnooze: [.en: "Snooze 5 min", .zh: "延後 5 分鐘"],
    .notifActionSkip:   [.en: "Not today", .zh: "今天不用了"],
    .notifSnoozeBody:   [.en: "Snooze's up — let's move 🧘", .zh: "延後時間到了，動一動吧 🧘"],

    // MARK: Misc
    .channelYourList:   [.en: "Your list", .zh: "我的清單"],
    .channelRepeat:     [.en: "Repeat", .zh: "重複"],
    .customVideoTitle:  [.en: "Custom video %d", .zh: "自訂影片 %d"],
]
