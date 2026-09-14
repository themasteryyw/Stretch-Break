import SwiftUI
import SwiftData
import Charts

// MARK: - Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case teal, blush, latte

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .teal: .teal
        case .blush: Color(red: 0.85, green: 0.55, blue: 0.56)   // morandi blush pink
        case .latte: Color(red: 0.72, green: 0.58, blue: 0.43)   // morandi latte
        }
    }

    var label: String {
        switch self {
        case .teal: "薄荷綠"
        case .blush: "粉色"
        case .latte: "奶茶色"
        }
    }

    /// nil = the app's primary (default) icon.
    var iconName: String? {
        switch self {
        case .teal: nil
        case .blush: "AppIcon-Pink"
        case .latte: "AppIcon-Latte"
        }
    }
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var phase
    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "figure.cooldown") }
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.xyaxis.line") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(theme)
        .fullScreenCover(isPresented: $model.showOnboarding, onDismiss: {
            Task { await NotificationScheduler.reschedule() }
        }) {
            OnboardingView()
        }
        .fullScreenCover(isPresented: $model.pendingStart) {
            SessionFlowView()
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active {
                Task { await NotificationScheduler.reschedule() }
                VideoStore.shared.prefetch()
            }
        }
        .task {
            VideoStore.shared.prefetch()
            // Rebuilds the pending queue on every cold launch — a reinstall (e.g. re-signing after
            // the free sideload cert expires) wipes already-scheduled notifications silently.
            await NotificationScheduler.reschedule()
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Query(sort: \SessionLog.date, order: .reverse) private var logs: [SessionLog]
    @AppStorage("goalPerDay") private var goalPerDay = 8
    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    @State private var notifAuthorized = true

    private var done: Int { StatsService.todayCount(logs) }
    private var streak: Int { StatsService.streak(logs) }
    private var weekMinutes: Int { StatsService.minutesThisWeek(logs) }
    private var next: Date? { NotificationScheduler.nextFireDate() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    ProgressRing(value: Double(done), total: Double(goalPerDay), tint: theme)
                        .frame(width: 210, height: 210)
                        .overlay {
                            VStack(spacing: 2) {
                                Text("\(done)/\(goalPerDay)")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                Text("stand-ups today")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 16)

                    HStack(spacing: 14) {
                        StatCard(icon: "flame.fill", tint: .orange,
                                 value: "\(streak)", label: "day streak")
                        StatCard(icon: "clock.fill", tint: theme,
                                 value: "\(weekMinutes)", label: "min this week")
                    }

                    Button {
                        model.pendingStart = true
                    } label: {
                        Label("Stretch now · 3 min", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme)
                    .controlSize(.large)

                    Group {
                        if !notifAuthorized {
                            Text("通知未開啟，不會收到休息提醒 — 前往「設定」開啟")
                                .foregroundStyle(.red)
                        } else if let next {
                            Text("Next reminder: \(next.formatted(date: .omitted, time: .shortened))")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Outside reminder hours — adjust in Settings")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
            }
            .navigationTitle("StretchBreak")
            .task {
                notifAuthorized = await NotificationScheduler.authStatus() == .authorized
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint)
            Text(value).font(.title2.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ProgressRing: View {
    let value: Double
    let total: Double
    var tint: Color = .teal
    private var pct: Double { total <= 0 ? 0 : min(1, value / total) }

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: 22)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(tint, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: pct)
        }
    }
}

// MARK: - Session flow

struct SessionFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @Query(sort: \SessionLog.date, order: .reverse) private var logs: [SessionLog]
    @Query private var stats: [VideoStat]
    @Query private var userVideos: [UserVideo]

    @AppStorage("askPain") private var askPain = true
    @AppStorage("painAreaCursor") private var painAreaCursor = 0
    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    @State private var step: Step = .loading
    @State private var pool: [StretchVideo] = []
    @State private var video: StretchVideo?
    @State private var failCount = 0
    @State private var area: FocusArea = .lowerBack
    @State private var repeatInfo: RepeatInfo?
    @State private var painBefore = 3
    @State private var painAfter = 3
    @State private var feeling: Feeling?
    @State private var feedback: FeedbackTag?
    @State private var elapsed = 0
    @State private var showConfetti = false
    @State private var rewardStreak = 0
    @State private var rewardToday = 0
    @State private var rewardMilestone = false

    private let maxFails = 4
    private enum Step { case loading, repeatOffer, painBefore, playing, offline, rating, painAfter, reward }

    struct RepeatInfo { let videoID: String; let title: String; let area: String; let score: Int }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showConfetti, !reduceMotion {
                ConfettiView().allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .onDisappear { rewarmNext() }
        .onChange(of: elapsed) { _, e in
            if step == .playing, let v = video, e >= min(v.durationSec, 420) {
                step = .rating
            }
        }
        .task { await load() }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .loading:
            ProgressView("Getting your stretch ready…")

        case .repeatOffer:
            if let info = repeatInfo {
                RepeatOfferView(info: info,
                                repeatIt: { acceptRepeat(info) },
                                somethingNew: { declineRepeat() })
            }

        case .painBefore:
            PainView(title: "How's your \(area.label) right now?", value: $painBefore,
                     submit: { advanceFromPainBefore() },
                     skip: { advanceFromPainBefore() })

        case .playing:
            if let video {
                VStack(spacing: 12) {
                    YouTubePlayerView(
                        videoID: video.id,
                        onEnded: { step = .rating },
                        onError: { code in handlePlaybackError(code) })
                        .id(video.id)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    Text(video.title)
                        .font(.subheadline).multilineTextAlignment(.center)
                        .lineLimit(2).padding(.horizontal)
                    Text(video.channel)
                        .font(.caption).foregroundStyle(.secondary)

                    TimerBar(target: video.durationSec, elapsed: $elapsed)
                        .padding(.horizontal)

                    HStack(spacing: 10) {
                        Button {
                            rerollVideo()
                        } label: {
                            Label("Next video", systemImage: "forward.fill")
                        }
                        .buttonStyle(.bordered)

                        Button("Done / end early") { step = .rating }
                            .buttonStyle(.borderedProminent).tint(.teal)
                    }

                    Button {
                        if let url = URL(string: "https://www.youtube.com/watch?v=\(video.id)") {
                            openURL(url)
                        }
                    } label: {
                        Label("Open in YouTube", systemImage: "arrow.up.forward.app")
                            .font(.footnote)
                    }
                    .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.top, 44)
            }

        case .offline:
            OfflineRoutineView(elapsed: $elapsed) { step = .rating }

        case .rating:
            RatingView(feeling: $feeling, feedback: $feedback) {
                if askPain { step = .painAfter } else { finish() }
            }

        case .painAfter:
            PainView(title: "And your \(area.label) now, after stretching?", value: $painAfter,
                     submit: { finish() }, skip: { finish() })

        case .reward:
            RewardView(streak: rewardStreak, today: rewardToday, milestone: rewardMilestone) {
                dismiss()
            }
        }
    }

    // MARK: flow helpers

    private func advanceFromPainBefore() {
        step = (video == nil) ? .offline : .playing
    }

    private func load() async {
        VideoStore.shared.setUserVideos(userVideos.map {
            StretchVideo(id: $0.videoID, title: $0.title, channel: "Your list",
                         durationSec: 240, areas: BodyArea.allCases,
                         intensity: .gentle, source: "user")
        })
        let fetched = await VideoStore.shared.ready()   // instant when the pool is already warm

        await MainActor.run {
            pool = fetched
            area = FocusArea.at(painAreaCursor)
            video = warmedPickIfUsable(from: fetched) ?? pickNext(from: fetched)
            repeatInfo = computeRepeatInfo()
            if repeatInfo != nil {
                step = .repeatOffer
            } else {
                step = askPain ? .painBefore : (video == nil ? .offline : .playing)
            }
        }
    }

    /// If the most recent check-in scored ≥ 7 for an area (and the stretch wasn't disliked,
    /// and it was recent), offer to repeat that same stretch this time.
    private func computeRepeatInfo() -> RepeatInfo? {
        guard let last = logs.first else { return nil }
        let score = max(last.painBefore ?? 0, last.painAfter ?? 0)
        guard RepeatPolicy.shouldOffer(lastScore: score,
                                       feelingRaw: last.feelingRaw,
                                       age: Date().timeIntervalSince(last.date),
                                       isOffline: last.videoID == "offline-routine")
        else { return nil }
        return RepeatInfo(videoID: last.videoID, title: last.videoTitle,
                          area: last.focusArea ?? area.label, score: score)
    }

    private func acceptRepeat(_ info: RepeatInfo) {
        // keep the check-in focused on the sore area, not the rotation
        if let matched = FocusArea.allCases.first(where: { $0.label == info.area }) {
            area = matched
        }
        video = pool.first { $0.id == info.videoID }
            ?? StretchVideo(id: info.videoID, title: info.title, channel: "Repeat",
                            durationSec: 300, areas: BodyArea.allCases,
                            intensity: .gentle, source: "repeat")
        elapsed = 0
        step = askPain ? .painBefore : .playing
    }

    private func declineRepeat() {
        step = askPain ? .painBefore : (video == nil ? .offline : .playing)
    }

    private func pickNext(from source: [StretchVideo]? = nil) -> StretchVideo? {
        let statMap = Dictionary(stats.map { ($0.videoID, $0) }, uniquingKeysWith: { a, _ in a })
        let recentIDs = Array(logs.prefix(12).map(\.videoID))
        return Recommender.next(from: source ?? pool, stats: statMap,
                                recentIDs: recentIDs, recentAreas: [])
    }

    /// Use the pre-warmed video if it's a legitimate pick (in pool, not broken, not recent)
    /// so the session starts instantly.
    private func warmedPickIfUsable(from source: [StretchVideo]) -> StretchVideo? {
        guard let w = PlayerWarmer.shared.warmedVideo,
              let match = source.first(where: { $0.id == w.id }),
              !(stats.first(where: { $0.videoID == w.id })?.isBroken ?? false),
              !logs.prefix(10).contains(where: { $0.videoID == w.id })
        else { return nil }
        return match
    }

    private func rewarmNext() {
        let recent = ([video?.id].compactMap { $0 } + logs.prefix(10).map(\.videoID))
        PlayerWarmer.shared.warm(from: pool, avoiding: recent)
    }

    /// User asked for a different video.
    private func rerollVideo() {
        elapsed = 0
        video = pickNext()
        if video == nil { step = .offline }
    }

    /// Playback failed (150/152 embed-disabled, 100 removed, 5 HTML5, …).
    private func handlePlaybackError(_ code: Int) {
        if let id = video?.id { statFor(id).isBroken = true; try? ctx.save() }
        failCount += 1
        elapsed = 0
        if failCount >= maxFails {
            video = nil
            step = .offline               // always give the user a stretch
            VideoStore.shared.prefetch(force: true)   // refill for next time
        } else {
            video = pickNext()
            if video == nil { step = .offline }
        }
    }

    private func statFor(_ id: String) -> VideoStat {
        if let existing = stats.first(where: { $0.videoID == id }) { return existing }
        let created = VideoStat(videoID: id)
        ctx.insert(created)
        return created
    }

    private func finish() {
        let id = video?.id ?? "offline-routine"
        let title = video?.title ?? "Offline routine"

        let stat = statFor(id)
        stat.timesPlayed += 1
        stat.lastPlayedAt = .now
        if let feeling { stat.feelingRaw = feeling.rawValue }
        if let feedback { stat.feedbackRaw = feedback.rawValue }

        let log = SessionLog(
            videoID: id, videoTitle: title,
            completedSec: max(elapsed, video?.durationSec ?? 180),
            painBefore: askPain ? painBefore : nil,
            painAfter: askPain ? painAfter : nil,
            feelingRaw: feeling?.rawValue,
            focusArea: askPain ? area.label : nil)
        ctx.insert(log)
        try? ctx.save()
        painAreaCursor += 1        // next session asks about the next body area

        rewardToday = StatsService.todayCount(logs) + 1
        rewardStreak = StatsService.streak(logs)
        rewardMilestone = [7, 30, 50, 100].contains(rewardStreak) || rewardToday == 1

        if rewardMilestone && !reduceMotion { showConfetti = true }
        step = .reward
    }
}

// MARK: - Timer bar

struct TimerBar: View {
    let target: Int
    @Binding var elapsed: Int
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: Double(min(elapsed, target)), total: Double(max(target, 1)))
                .tint(theme)
            Text("\(mmss(elapsed)) / \(mmss(target))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .onReceive(tick) { _ in elapsed += 1 }
    }

    private func mmss(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Offline routine

struct OfflineRoutineView: View {
    @Binding var elapsed: Int
    let onDone: () -> Void

    @State private var moves: [RoutineMove] = []
    @State private var index = 0
    @State private var remaining = 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        VStack(spacing: 24) {
            if moves.indices.contains(index) {
                let move = moves[index]
                Text("Move \(index + 1) / \(moves.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Image(systemName: move.symbol)
                    .font(.system(size: 90))
                    .foregroundStyle(theme)
                    .symbolRenderingMode(.hierarchical)
                Text(move.name).font(.title2.bold()).multilineTextAlignment(.center)
                Text(move.cue)
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Text("\(remaining)s")
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                HStack {
                    Button("Skip this one") { nextMove() }
                        .buttonStyle(.bordered)
                    Button("End") { onDone() }
                        .buttonStyle(.borderedProminent).tint(theme)
                }
            } else {
                ProgressView()
            }
        }
        .padding()
        .padding(.top, 44)
        .onAppear(perform: loadRoutine)
        .onReceive(tick) { _ in
            guard !moves.isEmpty else { return }
            elapsed += 1
            remaining -= 1
            if remaining <= 0 { nextMove() }
        }
    }

    private func loadRoutine() {
        guard let url = Bundle.main.url(forResource: "routine", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([RoutineMove].self, from: data),
              !decoded.isEmpty
        else {
            onDone(); return
        }
        moves = decoded
        remaining = decoded[0].seconds
    }

    private func nextMove() {
        if index + 1 < moves.count {
            index += 1
            remaining = moves[index].seconds
        } else {
            onDone()
        }
    }
}

// MARK: - Repeat offer (when last check-in scored high)

struct RepeatOfferView: View {
    let info: SessionFlowView.RepeatInfo
    let repeatIt: () -> Void
    let somethingNew: () -> Void

    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme)
                .symbolRenderingMode(.hierarchical)
            Text("Last time your \(info.area) was \(info.score)/10.")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("Want to keep working on it with the same stretch?")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(info.title)
                .font(.footnote).foregroundStyle(.secondary)
                .lineLimit(2).multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button("Repeat it") { repeatIt() }
                .buttonStyle(.borderedProminent).tint(theme).controlSize(.large)
            Button("Try something new") { somethingNew() }
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding()
        .padding(.bottom, 20)
    }
}

// MARK: - Rating

struct RatingView: View {
    @Binding var feeling: Feeling?
    @Binding var feedback: FeedbackTag?
    let onSubmit: () -> Void

    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("How was that?").font(.title2.bold())

            HStack(spacing: 18) {
                ForEach(Feeling.allCases) { f in
                    Button {
                        feeling = f
                    } label: {
                        Text(f.emoji)
                            .font(.system(size: 44))
                            .padding(10)
                            .background(feeling == f ? theme.opacity(0.2) : .clear,
                                        in: Circle())
                    }
                    .accessibilityLabel(f.label)
                }
            }

            HStack(spacing: 10) {
                ForEach(FeedbackTag.allCases) { tag in
                    Chip(text: tag.label, selected: feedback == tag) {
                        feedback = (feedback == tag) ? nil : tag
                    }
                }
            }

            Spacer()
            Button("Submit") { onSubmit() }
                .buttonStyle(.borderedProminent).tint(theme).controlSize(.large)
                .disabled(feeling == nil)
            Button("Skip") { onSubmit() }
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .padding(.bottom, 20)
    }
}

struct Chip: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? theme : Color(.secondarySystemBackground),
                            in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
    }
}

// MARK: - Reward

struct RewardView: View {
    let streak: Int
    let today: Int
    let milestone: Bool
    let onDone: () -> Void

    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    private var headline: String {
        if milestone { "了不起，連續 \(streak) 天了！" }
        else if today == 1 { "今天的第一次伸展，完成！" }
        else { "做得很好，給自己一個掌聲" }
    }

    private var message: String {
        milestone
            ? "忙碌的一天裡還記得照顧自己，這份堅持很珍貴。"
            : "花幾分鐘照顧身體，你值得這樣的休息。"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: milestone ? "star.circle.fill" : "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(theme)
                .symbolRenderingMode(.hierarchical)

            Text(headline).font(.title2.bold()).multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 28) {
                RewardStat(value: "\(streak)", label: "連續天數", tint: theme)
                RewardStat(value: "\(today)", label: "今日完成", tint: theme)
            }
            .padding(.top, 8)

            Spacer()
            Button("完成") { onDone() }
                .buttonStyle(.borderedProminent).tint(theme).controlSize(.large)
        }
        .padding()
        .padding(.bottom, 20)
    }
}

struct RewardStat: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title.bold().monospacedDigit()).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 72)
    }
}

// MARK: - Pain check-in

struct PainView: View {
    let title: String
    @Binding var value: Int
    let submit: () -> Void
    let skip: () -> Void

    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Text(title).font(.title3.bold()).multilineTextAlignment(.center)
            Text("\(value)")
                .font(.system(size: 60, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
            Slider(value: Binding(get: { Double(value) },
                                  set: { value = Int($0.rounded()) }),
                   in: 0...10, step: 1)
                .tint(color)
                .padding(.horizontal)
            HStack {
                Text("0 None").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("10 Severe").font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal)
            Spacer()
            Button("Submit") { submit() }
                .buttonStyle(.borderedProminent).tint(theme).controlSize(.large)
            Button("Skip") { skip() }
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .padding(.bottom, 20)
    }

    private var color: Color {
        switch value {
        case 0...3: .green
        case 4...6: .orange
        default: .red
        }
    }
}

// MARK: - History

struct HistoryView: View {
    @Query(sort: \SessionLog.date, order: .reverse) private var logs: [SessionLog]
    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    private var dailyCounts: [(day: Date, count: Int)] {
        let cal = Calendar.current
        return (0..<14).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: .now))
            else { return nil }
            let c = logs.filter { cal.isDate($0.date, inSameDayAs: day) }.count
            return (day, c)
        }
    }

    private var painPoints: [(date: Date, pain: Int)] {
        logs.compactMap { log in log.painAfter.map { (log.date, $0) } }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Stand-ups per day (last 14 days)") {
                    Chart(dailyCounts, id: \.day) { item in
                        BarMark(x: .value("Date", item.day, unit: .day),
                                y: .value("Count", item.count))
                            .foregroundStyle(theme)
                    }
                    .frame(height: 160)
                }

                if painPoints.count >= 2 {
                    Section("Post-stretch discomfort trend") {
                        Chart(painPoints, id: \.date) { p in
                            LineMark(x: .value("Date", p.date),
                                     y: .value("Discomfort", p.pain))
                                .foregroundStyle(.orange)
                                .symbol(.circle)
                            PointMark(x: .value("Date", p.date),
                                      y: .value("Discomfort", p.pain))
                                .foregroundStyle(.orange)
                        }
                        .chartYScale(domain: 0...10)
                        .frame(height: 160)
                    }
                }

                Section("Recent") {
                    if logs.isEmpty {
                        Text("No history yet — do your first stretch!")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(logs.prefix(40)) { log in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(log.videoTitle).font(.subheadline).lineLimit(1)
                                Spacer()
                                if let f = log.feelingRaw, let feeling = Feeling(rawValue: f) {
                                    Text(feeling.emoji)
                                }
                            }
                            Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \UserVideo.addedAt, order: .reverse) private var userVideos: [UserVideo]

    @AppStorage("startHour") private var startHour = 9
    @AppStorage("endHour") private var endHour = 18
    @AppStorage("intervalMin") private var intervalMin = 60
    @AppStorage("activeDaysMask") private var activeDaysMask = 62
    @AppStorage("goalPerDay") private var goalPerDay = 8
    @AppStorage("askPain") private var askPain = true
    @AppStorage("themeColorRaw") private var themeColorRaw = AppTheme.teal.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    @State private var linkText = ""
    @State private var authDenied = false

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private var hasAPIKey: Bool {
        !((Bundle.main.object(forInfoDictionaryKey: "YTAPIKey") as? String) ?? "").isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder hours") {
                    Stepper("Start: \(startHour):00", value: $startHour, in: 0...22)
                    Stepper("End: \(endHour):00", value: $endHour, in: (startHour + 1)...23)
                    Picker("Interval", selection: $intervalMin) {
                        ForEach([30, 45, 60, 90, 120], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    HStack {
                        ForEach(1...7, id: \.self) { wd in
                            let on = Cfg.weekdayEnabled(wd, mask: activeDaysMask)
                            Button(weekdaySymbols[wd - 1]) {
                                activeDaysMask ^= (1 << (wd - 1))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(on ? theme : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(on ? .white : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("Goal & prompts") {
                    Stepper("Daily goal: \(goalPerDay)", value: $goalPerDay, in: 3...16)
                    Toggle("Ask discomfort each time", isOn: $askPain)
                }

                Section {
                    HStack(spacing: 16) {
                        ForEach(AppTheme.allCases) { t in
                            Button {
                                themeColorRaw = t.rawValue
                                Task { try? await UIApplication.shared.setAlternateIconName(t.iconName) }
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(t.color)
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if themeColorRaw == t.rawValue {
                                                Circle().strokeBorder(.primary, lineWidth: 2).padding(-4)
                                            }
                                        }
                                    Text(t.label).font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("外觀")
                } footer: {
                    Text("套用到主題色與 App 圖示。")
                }

                Section {
                    HStack {
                        TextField("Paste a YouTube link", text: $linkText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Add") { addLink() }
                            .disabled(YouTubeURL.id(from: linkText) == nil)
                    }
                    ForEach(userVideos) { v in
                        Text(v.title).lineLimit(1)
                    }
                    .onDelete { idx in
                        idx.map { userVideos[$0] }.forEach(ctx.delete)
                        try? ctx.save()
                    }
                } header: {
                    Text("Video sources")
                } footer: {
                    Text(hasAPIKey
                         ? "YouTube API key set: fetches embeddable 3–5 min stretch videos, rotating by body area and avoiding repeats."
                         : "No API key: uses the built-in timed routine. Add links above for your own list, or set YTAPIKey in project.yml.")
                }

                Section {
                    Button("Reschedule notifications") {
                        Task { await NotificationScheduler.reschedule() }
                    }
                    if authDenied {
                        Button("Notifications are off — open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: startHour) { rescheduleSoon() }
            .onChange(of: endHour) { rescheduleSoon() }
            .onChange(of: intervalMin) { rescheduleSoon() }
            .onChange(of: activeDaysMask) { rescheduleSoon() }
            .task {
                authDenied = await NotificationScheduler.authStatus() == .denied
            }
        }
    }

    private func addLink() {
        guard let id = YouTubeURL.id(from: linkText) else { return }
        if !userVideos.contains(where: { $0.videoID == id }) {
            ctx.insert(UserVideo(videoID: id, title: "Custom video \(userVideos.count + 1)"))
            try? ctx.save()
        }
        linkText = ""
        // Picked up by VideoStore.setUserVideos() at the start of the next session.
    }

    private func rescheduleSoon() {
        Task { await NotificationScheduler.reschedule() }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("onboarded") private var onboarded = false
    @State private var page = 0

    var body: some View {
        VStack {
            TabView(selection: $page) {
                OnboardPage(symbol: "figure.seated.side",
                            title: "Sitting compresses the sciatic nerve",
                            message: "A 3–5 minute micro-stretch every hour meaningfully lowers lower-back and hip discomfort. This app does one thing: remind you on time and hand you a non-repeating stretch.")
                    .tag(0)
                OnboardPage(symbol: "clock.badge.checkmark",
                            title: "Set your working hours",
                            message: "Reminders fire only during the hours and days you pick — silent the rest of the time. Change it anytime in Settings.")
                    .tag(1)
                OnboardPage(symbol: "bell.badge",
                            title: "Allow notifications",
                            message: "Everything is scheduled locally on your device. No network, no data leaves your phone.")
                    .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < 2 ? "Next" : "Allow notifications & start") {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    Task {
                        _ = await NotificationScheduler.requestAuth()
                        await NotificationScheduler.reschedule()
                        onboarded = true
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent).tint(.teal).controlSize(.large)
            .padding()

            if page == 2 {
                Button("Maybe later") {
                    onboarded = true
                    dismiss()
                }
                .font(.footnote).foregroundStyle(.secondary)
                .padding(.bottom)
            }
        }
    }
}

struct OnboardPage: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 80))
                .foregroundStyle(.teal)
                .symbolRenderingMode(.hierarchical)
            Text(title).font(.title.bold()).multilineTextAlignment(.center)
            Text(message)
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    @State private var drop = false
    private let pieces = Array(0..<40)
    private let emojis = ["🎉", "✨", "🧘", "💚", "🌿"]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces, id: \.self) { i in
                    Text(emojis[i % emojis.count])
                        .font(.system(size: CGFloat.random(in: 16...28)))
                        .position(x: .random(in: 0...geo.size.width),
                                  y: drop ? geo.size.height + 40 : -40)
                        .opacity(drop ? 0 : 1)
                        .animation(.easeIn(duration: .random(in: 1.4...2.4))
                            .delay(.random(in: 0...0.4)), value: drop)
                }
            }
            .onAppear { drop = true }
        }
    }
}
