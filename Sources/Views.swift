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
        case .teal: t(.themeTeal)
        case .blush: t(.themeBlush)
        case .latte: t(.themeLatte)
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(t(.tabToday), systemImage: "figure.cooldown") }
            HistoryView()
                .tabItem { Label(t(.tabHistory), systemImage: "chart.xyaxis.line") }
            SettingsView()
                .tabItem { Label(t(.tabSettings), systemImage: "gearshape") }
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
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
                                Text(t(.standUpsToday))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 16)

                    HStack(spacing: 14) {
                        StatCard(icon: "flame.fill", tint: .orange,
                                 value: "\(streak)", label: t(.dayStreak))
                        StatCard(icon: "clock.fill", tint: theme,
                                 value: "\(weekMinutes)", label: t(.minThisWeek))
                    }

                    Button {
                        model.pendingStart = true
                    } label: {
                        Label(t(.stretchNowButton), systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme)
                    .controlSize(.large)

                    Group {
                        if !notifAuthorized {
                            Text(t(.notifOffWarning))
                                .foregroundStyle(.red)
                        } else if let next {
                            Text(t(.nextReminder, next.formatted(date: .omitted, time: .shortened)))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(t(.outsideReminderHours))
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
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

    struct RepeatInfo {
        let videoID: String; let title: String
        let area: String        // localized display label
        let areaKey: String?    // FocusArea.rawValue — stable across a language switch
        let score: Int
    }

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
            ProgressView(t(.loadingStretch))

        case .repeatOffer:
            if let info = repeatInfo {
                RepeatOfferView(info: info,
                                repeatIt: { acceptRepeat(info) },
                                somethingNew: { declineRepeat() })
            }

        case .painBefore:
            PainView(title: t(.painBeforeTitle, area.label), value: $painBefore,
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
                            Label(t(.nextVideoButton), systemImage: "forward.fill")
                        }
                        .buttonStyle(.bordered)

                        Button(t(.doneEndEarlyButton)) { step = .rating }
                            .buttonStyle(.borderedProminent).tint(.teal)
                    }

                    Button {
                        if let url = URL(string: "https://www.youtube.com/watch?v=\(video.id)") {
                            openURL(url)
                        }
                    } label: {
                        Label(t(.openInYouTubeButton), systemImage: "arrow.up.forward.app")
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
            PainView(title: t(.painAfterTitle, area.label), value: $painAfter,
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
            StretchVideo(id: $0.videoID, title: $0.title, channel: t(.channelYourList),
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
        // `focusArea` is stored as a FocusArea.rawValue (language-independent); resolve it
        // to today's localized label for display, falling back gracefully if it doesn't match
        // any known case (e.g. an older log written before this field existed).
        let key = last.focusArea
        let displayLabel = key.flatMap { FocusArea(rawValue: $0)?.label } ?? key ?? area.label
        return RepeatInfo(videoID: last.videoID, title: last.videoTitle,
                          area: displayLabel, areaKey: key, score: score)
    }

    private func acceptRepeat(_ info: RepeatInfo) {
        // keep the check-in focused on the sore area, not the rotation
        if let key = info.areaKey, let matched = FocusArea(rawValue: key) {
            area = matched
        }
        video = pool.first { $0.id == info.videoID }
            ?? StretchVideo(id: info.videoID, title: info.title, channel: t(.channelRepeat),
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
            focusArea: askPain ? area.rawValue : nil)   // stable across a language switch; resolved to a label on read
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        VStack(spacing: 24) {
            if moves.indices.contains(index) {
                let move = moves[index]
                Text(t(.moveCounter, index + 1, moves.count))
                    .font(.caption).foregroundStyle(.secondary)
                Image(systemName: move.symbol)
                    .font(.system(size: 90))
                    .foregroundStyle(theme)
                    .symbolRenderingMode(.hierarchical)
                Text(move.localizedName).font(.title2.bold()).multilineTextAlignment(.center)
                Text(move.localizedCue)
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Text("\(remaining)s")
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                HStack {
                    Button(t(.skipThisOneButton)) { nextMove() }
                        .buttonStyle(.bordered)
                    Button(t(.endButton)) { onDone() }
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme)
                .symbolRenderingMode(.hierarchical)
            Text(t(.repeatLastTime, info.area, info.score))
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(t(.repeatQuestion))
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(info.title)
                .font(.footnote).foregroundStyle(.secondary)
                .lineLimit(2).multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button(t(.repeatItButton)) { repeatIt() }
                .buttonStyle(.borderedProminent).tint(theme).controlSize(.large)
            Button(t(.somethingNewButton)) { somethingNew() }
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text(t(.howWasThat)).font(.title2.bold())

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
            Button(t(.submitButton)) { onSubmit() }
                .buttonStyle(.borderedProminent).tint(theme).controlSize(.large)
                .disabled(feeling == nil)
            Button(t(.skipButton)) { onSubmit() }
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var theme: Color { AppTheme(rawValue: themeColorRaw)?.color ?? .teal }

    // Cute pop-in / bounce / sparkle-spin animation state.
    @State private var iconIn = false
    @State private var iconBounce = false
    @State private var sparkleSpin = false

    private var headline: String {
        if milestone { t(.rewardMilestoneHeadline, streak) }
        else if today == 1 { t(.rewardFirstTodayHeadline) }
        else { t(.rewardGenericHeadline) }
    }

    private var message: String {
        milestone ? t(.rewardMilestoneMessage) : t(.rewardGenericMessage)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                if !reduceMotion {
                    ForEach(0..<6, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.opacity(0.75))
                            .offset(y: -56)
                            .rotationEffect(.degrees(Double(i) / 6 * 360 + (sparkleSpin ? 360 : 0)))
                            .opacity(iconIn ? 1 : 0)
                    }
                }
                Image(systemName: milestone ? "star.circle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(theme)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(iconIn ? (iconBounce ? 1.08 : 1.0) : 0.4)
                    .rotationEffect(.degrees(iconIn ? 0 : -25))
            }
            .frame(height: 96)
            .onAppear {
                guard !reduceMotion else { iconIn = true; return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { iconIn = true }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(0.5)) {
                    iconBounce = true
                }
                withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                    sparkleSpin = true
                }
            }

            Text(headline).font(.title2.bold()).multilineTextAlignment(.center)
                .opacity(iconIn ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.1), value: iconIn)
            Text(message)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(iconIn ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.16), value: iconIn)

            HStack(spacing: 28) {
                RewardStat(value: "\(streak)", label: t(.rewardStreakLabel), tint: theme)
                RewardStat(value: "\(today)", label: t(.rewardTodayLabel), tint: theme)
            }
            .padding(.top, 8)
            .opacity(iconIn ? 1 : 0)
            .animation(.easeOut(duration: 0.35).delay(0.22), value: iconIn)

            Spacer()
            Button(t(.rewardDoneButton)) { onDone() }
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
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
                Text(t(.painNone)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(t(.painSevere)).font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal)
            Spacer()
            Button(t(.submitButton)) { submit() }
                .buttonStyle(.borderedProminent).tint(theme).controlSize(.large)
            Button(t(.skipButton)) { skip() }
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
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
                Section(t(.historyChartTitle)) {
                    Chart(dailyCounts, id: \.day) { item in
                        BarMark(x: .value("Date", item.day, unit: .day),
                                y: .value("Count", item.count))
                            .foregroundStyle(theme)
                    }
                    .frame(height: 160)
                }

                if painPoints.count >= 2 {
                    Section(t(.historyPainTrendTitle)) {
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

                Section(t(.historyRecentSection)) {
                    if logs.isEmpty {
                        Text(t(.historyNoLogsYet))
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
            .navigationTitle(t(.historyNavTitle))
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
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
                Section(t(.sectionReminderHours)) {
                    Stepper(t(.stepperStart, startHour), value: $startHour, in: 0...22)
                    Stepper(t(.stepperEnd, endHour), value: $endHour, in: (startHour + 1)...23)
                    Picker(t(.intervalLabel), selection: $intervalMin) {
                        ForEach([30, 45, 60, 90, 120], id: \.self) { Text(t(.minUnit, $0)).tag($0) }
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

                Section(t(.sectionGoalPrompts)) {
                    Stepper(t(.dailyGoal, goalPerDay), value: $goalPerDay, in: 3...16)
                    Toggle(t(.askDiscomfortToggle), isOn: $askPain)
                }

                Section {
                    Picker(t(.sectionLanguage), selection: $appLanguageRaw) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.label).tag(lang.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(t(.sectionLanguage))
                } footer: {
                    Text(t(.languageFooter))
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
                    Text(t(.sectionAppearance))
                } footer: {
                    Text(t(.appearanceFooter))
                }

                Section {
                    HStack {
                        TextField(t(.pasteYoutubeLinkPlaceholder), text: $linkText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(t(.addButton)) { addLink() }
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
                    Text(t(.sectionVideoSources))
                } footer: {
                    Text(hasAPIKey ? t(.videoSourcesFooterWithKey) : t(.videoSourcesFooterNoKey))
                }

                Section {
                    Button(t(.rescheduleNotifButton)) {
                        Task { await NotificationScheduler.reschedule() }
                    }
                    if authDenied {
                        Button(t(.notifOffOpenSettings)) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(t(.settingsNavTitle))
            .onChange(of: startHour) { rescheduleSoon() }
            .onChange(of: endHour) { rescheduleSoon() }
            .onChange(of: intervalMin) { rescheduleSoon() }
            .onChange(of: activeDaysMask) { rescheduleSoon() }
            .onChange(of: appLanguageRaw) {
                NotificationScheduler.registerCategory()   // pick up new action-button titles
                rescheduleSoon()                           // and new prompt strings
            }
            .task {
                authDenied = await NotificationScheduler.authStatus() == .denied
            }
        }
    }

    private func addLink() {
        guard let id = YouTubeURL.id(from: linkText) else { return }
        if !userVideos.contains(where: { $0.videoID == id }) {
            ctx.insert(UserVideo(videoID: id, title: t(.customVideoTitle, userVideos.count + 1)))
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.current.rawValue
    @State private var page = 0

    var body: some View {
        VStack {
            TabView(selection: $page) {
                OnboardPage(symbol: "figure.seated.side",
                            title: t(.onboard1Title),
                            message: t(.onboard1Message))
                    .tag(0)
                OnboardPage(symbol: "clock.badge.checkmark",
                            title: t(.onboard2Title),
                            message: t(.onboard2Message))
                    .tag(1)
                OnboardPage(symbol: "bell.badge",
                            title: t(.onboard3Title),
                            message: t(.onboard3Message))
                    .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < 2 ? t(.nextButton) : t(.allowNotifStartButton)) {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    Task {
                        _ = await NotificationScheduler.requestAuth()
                        NotificationScheduler.registerCategory()
                        await NotificationScheduler.reschedule()
                        onboarded = true
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent).tint(.teal).controlSize(.large)
            .padding()

            if page == 2 {
                Button(t(.maybeLaterButton)) {
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
