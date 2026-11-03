import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

@main
struct DobrichsBrainApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer

    init() {
        // "-demo" (used by UI tests for screenshots): in-memory store with sample data
        let demo = ProcessInfo.processInfo.arguments.contains("-demo")
        do {
            container = try makeContainer(inMemory: demo)
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
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("shiftStart") private var shiftStart: Double = 0

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
        .onAppear {
            // bring back the Live Activity if a shift is running (e.g. after the phone restarted)
            if shiftStart > 0 { ShiftActivity.start(Date(timeIntervalSince1970: shiftStart)) }
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active { refreshWidgets(context) }
        }
    }
}
