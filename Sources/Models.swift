import Foundation
import SwiftData

// MARK: - Enums

enum BodyArea: String, Codable, CaseIterable, Identifiable {
    case piriformis, glutes, hipFlexors, hamstrings, lowerBack, thoracic, neck
    var id: String { rawValue }
    var label: String {
        switch self {
        case .piriformis: "Piriformis"
        case .glutes:      "Glutes"
        case .hipFlexors:  "Hip flexors"
        case .hamstrings:  "Hamstrings"
        case .lowerBack:   "Lower back"
        case .thoracic:    "Thoracic spine"
        case .neck:        "Neck"
        }
    }
}

enum Intensity: String, Codable, CaseIterable {
    case gentle, moderate
    var label: String { self == .gentle ? "Gentle" : "Moderate" }
}

enum Feeling: Int, Codable, CaseIterable, Identifiable {
    case bad = 1, meh = 2, good = 3, love = 4
    var id: Int { rawValue }
    var emoji: String { ["😖", "😐", "🙂", "😍"][rawValue - 1] }
    var label: String { ["Dislike", "Meh", "Good", "Love it"][rawValue - 1] }
}

enum FeedbackTag: String, Codable, CaseIterable, Identifiable {
    case tooHard, justRight, tooEasy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .tooHard:   "Too hard"
        case .justRight: "Just right"
        case .tooEasy:   "Too easy"
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
    var label: String {
        switch self {
        case .lowerBack:     "lower back"
        case .leftHip:       "left hip / glute"
        case .rightHip:      "right hip / glute"
        case .hamstrings:    "hamstrings"
        case .neckShoulders: "neck & shoulders"
        case .piriformis:    "deep glute (piriformis)"
        }
    }
    static func at(_ cursor: Int) -> FocusArea {
        allCases[((cursor % allCases.count) + allCases.count) % allCases.count]
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
    var id: String { name }
    let name: String
    let symbol: String        // SF Symbol
    let seconds: Int
    let cue: String
}
