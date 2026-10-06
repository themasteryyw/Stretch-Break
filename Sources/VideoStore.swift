import Foundation

/// Prefetches and caches the YouTube video pool so a session starts with no wait.
/// - Loads last session's pool from disk on launch (instant).
/// - Refreshes in the background on app open / foreground when older than `ttl`.
/// - `ready()` returns immediately if a pool is cached, otherwise awaits the in-flight fetch.
@MainActor
final class VideoStore: ObservableObject {
    static let shared = VideoStore()

    @Published private(set) var videos: [StretchVideo] = []
    @Published private(set) var isRefreshing = false

    private var fetchedAt: Date?
    private var cachedLanguage: AppLanguage?
    private var userVideos: [StretchVideo] = []
    private var task: Task<Void, Never>?
    private let ttl: TimeInterval = 6 * 3600

    private init() { loadCache() }

    private var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "YTAPIKey") as? String) ?? ""
    }

    private var remoteOnly: [StretchVideo] { videos.filter { $0.source == "youtube" } }

    /// Merge the user's pasted links into the pool (called when that list changes).
    func setUserVideos(_ list: [StretchVideo]) {
        userVideos = list
        rebuild(remote: remoteOnly)
    }

    /// Kick a background refresh. Cheap no-op when the cache is still fresh.
    func prefetch(force: Bool = false) {
        guard !apiKey.isEmpty else { return }
        if cachedLanguage != AppLanguage.current, !remoteOnly.isEmpty {
            task?.cancel(); task = nil
            rebuild(remote: [])
            fetchedAt = nil
        }
        guard task == nil else { return }
        let stillFresh = !force
            && !remoteOnly.isEmpty
            && (fetchedAt.map { Date().timeIntervalSince($0) < ttl } ?? false)
        if stillFresh { return }

        task = Task {
            isRefreshing = true
            let language = AppLanguage.current
            let pool = await YouTubeProvider(apiKey: apiKey).pool()
            isRefreshing = false
            task = nil
            guard !pool.isEmpty, !Task.isCancelled, language == AppLanguage.current else { return }
            fetchedAt = Date()
            cachedLanguage = language
            rebuild(remote: pool)
            saveCache(pool, language: language)
            PlayerWarmer.shared.warm(from: videos, avoiding: [])
        }
    }

    /// A usable pool for starting a session — instant if cached.
    func ready() async -> [StretchVideo] {
        if !videos.isEmpty { return videos }
        prefetch()
        await task?.value
        return videos
    }

    private func rebuild(remote: [StretchVideo]) {
        var seen = Set<String>()
        videos = (userVideos + remote).filter { seen.insert($0.id).inserted }
    }

    // MARK: - Disk cache

    private struct Cache: Codable { let fetchedAt: Date; let videos: [StretchVideo]; let language: String? }

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("video_cache.json")
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(Cache.self, from: data) else { return }
        fetchedAt = cache.fetchedAt
        cachedLanguage = cache.language.flatMap(AppLanguage.init(rawValue:)) ?? .en
        videos = cache.videos
        if !videos.isEmpty { PlayerWarmer.shared.warm(from: videos, avoiding: []) }
    }

    private func saveCache(_ remote: [StretchVideo], language: AppLanguage) {
        guard let data = try? JSONEncoder().encode(Cache(fetchedAt: Date(), videos: remote, language: language.rawValue)) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
