import SwiftUI
import SwiftData
import UserNotifications

@main
struct StretchBreakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .modelContainer(for: [VideoStat.self, SessionLog.self, UserVideo.self])
        }
    }
}

/// Small shared UI state. Singleton so the notification delegate can poke it.
final class AppModel: ObservableObject {
    static let shared = AppModel()
    @Published var pendingStart = false                       // jump straight into a session
    @Published var showOnboarding = !Cfg.onboarded
    private init() {}
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.registerCategory()
        Task { @MainActor in VideoStore.shared.prefetch() }   // warm the pool before the first tap
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        switch response.actionIdentifier {
        case "SNOOZE":
            await NotificationScheduler.snooze()
        case "SKIP":
            NotificationScheduler.cancelToday()
        case "START", UNNotificationDefaultActionIdentifier:
            await MainActor.run { AppModel.shared.pendingStart = true }
        default:
            break
        }
    }
}
