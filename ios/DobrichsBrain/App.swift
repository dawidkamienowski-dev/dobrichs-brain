import SwiftData
import SwiftUI
import UserNotifications

@main
struct DobrichsBrainApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer

    init() {
        // "-demo" (used by UI tests for screenshots): in-memory store with sample data
        let demo = ProcessInfo.processInfo.arguments.contains("-demo")
        let config = ModelConfiguration(isStoredInMemoryOnly: demo)
        do {
            container = try ModelContainer(for: Note.self, TaskItem.self, WorkEntry.self, Habit.self, configurations: config)
        } catch {
            fatalError("Nie udało się otworzyć bazy: \(error)")
        }
        if demo { DemoData.seed(container.mainContext) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: "pl_PL"))
        }
        .modelContainer(container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // show reminders also while the app is open
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

struct RootView: View {
    @Query(filter: #Predicate<TaskItem> { $0.done == false }) private var openTasks: [TaskItem]

    private var urgentCount: Int {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        return openTasks.filter { ($0.due ?? .distantFuture) < endOfToday }.count
    }

    var body: some View {
        TabView {
            NotesView()
                .tabItem { Label("Notatki", systemImage: "brain.head.profile") }
            TasksView()
                .tabItem { Label("Zadania", systemImage: "checklist") }
                .badge(urgentCount)
            HabitsView()
                .tabItem { Label("Nawyki", systemImage: "flame") }
            WorkView()
                .tabItem { Label("Praca", systemImage: "clock") }
            SettingsView()
                .tabItem { Label("Więcej", systemImage: "gearshape") }
        }
    }
}
