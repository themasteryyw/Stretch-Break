import Foundation
import SwiftData

// MARK: - Enums

enum BodyArea: String, Codable, CaseIterable, Identifiable {
    case piriformis, glutes, hipFlexors, hamstrings, lowerBack, thoracic, neck
    case shoulders, chest, wristsForearms, quads, calvesAnkles
    var id: String { rawValue }
    var label: String {
        switch self {
        case .piriformis:     t(.areaPiriformis)
        case .glutes:         t(.areaGlutes)
        case .hipFlexors:     t(.areaHipFlexors)
        case .hamstrings:     t(.areaHamstrings)
        case .lowerBack:      t(.areaLowerBack)
        case .thoracic:       t(.areaThoracic)
        case .neck:           t(.areaNeck)
        case .shoulders:      t(.areaShoulders)
        case .chest:          t(.areaChest)
        case .wristsForearms: t(.areaWristsForearms)
        case .quads:          t(.areaQuads)
        case .calvesAnkles:   t(.areaCalvesAnkles)
        }
    }
}

enum StretchMode: String, CaseIterable, Identifiable {
    case video, timer
    var id: String { rawValue }

    var label: String {
        switch self {
        case .video: t(.modeVideo)
        case .timer: t(.modeTimer)
        }
    }
}

enum StretchConfig {
    static let videoTargetSec = 300
    static let videoDurationBand: ClosedRange<Int> = 240...600
    static let timerMinutesRange = 1...30
    static let defaultTimerMinutes = 5
}

enum Intensity: String, Codable, CaseIterable {
    case gentle, moderate
    var label: String { self == .gentle ? t(.intensityGentle) : t(.intensityModerate) }
}

enum Feeling: Int, Codable, CaseIterable, Identifiable {
    case bad = 1, meh = 2, good = 3, love = 4
    var id: Int { rawValue }
    var emoji: String { ["😖", "😐", "🙂", "😍"][rawValue - 1] }
    var label: String {
        [t(.feelingDislike), t(.feelingMeh), t(.feelingGood), t(.feelingLoveIt)][rawValue - 1]
    }
}

enum FeedbackTag: String, Codable, CaseIterable, Identifiable {
    case tooHard, justRight, tooEasy
    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .tooHard:   "😮‍💨"
        case .justRight: "👌"
        case .tooEasy:   "😴"
        }
    }
    var label: String {
        switch self {
        case .tooHard:   t(.feedbackTooHard)
        case .justRight: t(.feedbackJustRight)
        case .tooEasy:   t(.feedbackTooEasy)
        }
    }
}

// MARK: - Value type used by the recommender

struct StretchVideo: Codable, Identifiable, Hashable {
    let id: String                 // YouTube video ID
    let title: String
    let channel: String
    let durationSec: Int
    let areas: [BodyArea]
    let intensity: Intensity
    var source: String = "catalog"
}

// MARK: - Persisted models (SwiftData)

@Model final class VideoStat {
    @Attribute(.unique) var videoID: String
    var timesPlayed: Int
    var lastPlayedAt: Date?
    var feelingRaw: Int?
    var feedbackRaw: String?
    var isBroken: Bool

    init(videoID: String) {
        self.videoID = videoID
        self.timesPlayed = 0
        self.lastPlayedAt = nil
        self.feelingRaw = nil
        self.feedbackRaw = nil
        self.isBroken = false
    }

    var feeling: Feeling? { feelingRaw.flatMap(Feeling.init) }
    var feedback: FeedbackTag? { feedbackRaw.flatMap(FeedbackTag.init) }
}

@Model final class SessionLog {
    var date: Date
    var videoID: String
    var videoTitle: String
    var completedSec: Int
    var painBefore: Int?
    var painAfter: Int?
    var feelingRaw: Int?
    var focusArea: String?          // which body area the check-in asked about

    init(date: Date = .now, videoID: String, videoTitle: String, completedSec: Int,
         painBefore: Int? = nil, painAfter: Int? = nil, feelingRaw: Int? = nil,
         focusArea: String? = nil) {
        self.date = date
        self.videoID = videoID
        self.videoTitle = videoTitle
        self.completedSec = completedSec
        self.painBefore = painBefore
        self.painAfter = painAfter
        self.feelingRaw = feelingRaw
        self.focusArea = focusArea
    }
}

/// Body areas the discomfort check-in rotates through, so consecutive prompts differ.
enum FocusArea: String, CaseIterable {
    case lowerBack, leftHip, rightHip, hamstrings, neckShoulders, piriformis
    case upperBack, chest, wristsForearms, quads, calvesAnkles
    var label: String {
        switch self {
        case .lowerBack:      t(.focusLowerBack)
        case .leftHip:        t(.focusLeftHip)
        case .rightHip:       t(.focusRightHip)
        case .hamstrings:     t(.focusHamstrings)
        case .neckShoulders:  t(.focusNeckShoulders)
        case .piriformis:     t(.focusPiriformis)
        case .upperBack:      t(.focusUpperBack)
        case .chest:          t(.focusChest)
        case .wristsForearms: t(.focusWristsForearms)
        case .quads:          t(.focusQuads)
        case .calvesAnkles:   t(.focusCalvesAnkles)
        }
    }
    static func at(_ cursor: Int) -> FocusArea {
        allCases[((cursor % allCases.count) + allCases.count) % allCases.count]
    }

    var relatedBodyAreas: [BodyArea] {
        switch self {
        case .lowerBack:      [.lowerBack]
        case .leftHip:        [.hipFlexors, .glutes, .piriformis]
        case .rightHip:       [.hipFlexors, .glutes, .piriformis]
        case .hamstrings:     [.hamstrings]
        case .neckShoulders:  [.neck, .shoulders]
        case .piriformis:     [.piriformis, .glutes]
        case .upperBack:      [.thoracic]
        case .chest:          [.chest]
        case .wristsForearms: [.wristsForearms]
        case .quads:          [.quads, .hipFlexors]
        case .calvesAnkles:   [.calvesAnkles]
        }
    }
}

/// A YouTube link the user pasted in Settings.
@Model final class UserVideo {
    @Attribute(.unique) var videoID: String
    var title: String
    var addedAt: Date

    init(videoID: String, title: String) {
        self.videoID = videoID
        self.title = title
        self.addedAt = .now
    }
}

// MARK: - Offline fallback routine

struct RoutineMove: Codable, Identifiable {
    var id: String { key }
    let key: String
    let symbol: String        // SF Symbol
    let seconds: Int
    let name: [String: String] // "en" / "zh"
    let cue: [String: String]

    var localizedName: String { name[AppLanguage.current.rawValue] ?? name["en"] ?? key }
    var localizedCue: String { cue[AppLanguage.current.rawValue] ?? cue["en"] ?? "" }
}
