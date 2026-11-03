import ActivityKit
import AppIntents
import Foundation
import SwiftData
import WidgetKit

// Code compiled into both the app and the widget extension.

enum AppGroup {
    static let id = "group.dev.dobrich.brain"
}

func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
    // groupContainer defaults to .automatic: the app group's container when the entitlement is present
    try ModelContainer(for: Note.self, TaskItem.self, WorkEntry.self, Habit.self,
                       configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
}

/// Settings and water, shared with the widget through the app group.
enum SharedDefaults {
    static let store = UserDefaults(suiteName: AppGroup.id) ?? .standard

    static func waterKey(_ day: Date = .now) -> String { "water." + Habit.key(day) }
    static func water(_ day: Date = .now) -> Int { store.integer(forKey: waterKey(day)) }
    static func setWater(_ ml: Int, day: Date = .now) { store.set(ml, forKey: waterKey(day)) }
    static var waterGoal: Int { store.object(forKey: "waterGoal") as? Int ?? 2000 }
}

struct DayPart: Hashable {
    let name: String
    let detail: String
    let value: Double
}

/// "Twój dzień": average of habits, water and today's tasks (each 0...1).
struct DaySummary {
    var parts: [DayPart]
    var waterML: Int
    var waterGoal: Int

    var total: Double { parts.isEmpty ? 0 : parts.map(\.value).reduce(0, +) / Double(parts.count) }
    var percent: Int { Int((total * 100).rounded()) }

    var message: String {
        switch total {
        case 1...: return "Perfekcyjny dzień 🏆"
        case 0.75...: return "Prawie wszystko, dociśnij końcówkę 💪"
        case 0.4...: return "Dobrze idzie, jesteś w połowie"
        case 0.01...: return "Dobry początek, lecimy dalej"
        default: return "Dzień dopiero się zaczyna ☀️"
        }
    }

    static func make(habits: [Habit], tasks: [TaskItem], waterML: Int, waterGoal: Int) -> DaySummary {
        var parts: [DayPart] = []
        if !habits.isEmpty {
            let done = habits.filter { $0.isDone(.now) }.count
            parts.append(DayPart(name: "Nawyki", detail: "\(done)/\(habits.count)", value: Double(done) / Double(habits.count)))
        }
        if waterGoal > 0 {
            parts.append(DayPart(name: "Woda", detail: "\(waterML) ml", value: min(1, Double(waterML) / Double(waterGoal))))
        }
        let today = tasks.filter { $0.due.map { Calendar.current.isDateInToday($0) } ?? false }
        if !today.isEmpty {
            let done = today.filter(\.done).count
            parts.append(DayPart(name: "Zadania", detail: "\(done)/\(today.count)", value: Double(done) / Double(today.count)))
        }
        return DaySummary(parts: parts, waterML: waterML, waterGoal: waterGoal)
    }

    static func load(_ context: ModelContext) -> DaySummary {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        return make(habits: habits, tasks: tasks, waterML: SharedDefaults.water(), waterGoal: SharedDefaults.waterGoal)
    }

    static let placeholder = DaySummary(
        parts: [DayPart(name: "Nawyki", detail: "2/4", value: 0.5), DayPart(name: "Woda", detail: "1250 ml", value: 0.625)],
        waterML: 1250, waterGoal: 2000)
}

/// "+250 ml" button in the widget.
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Dodaj wodę"

    @Parameter(title: "Mililitry", default: 250)
    var ml: Int

    init() {}
    init(ml: Int) { self.ml = ml }

    func perform() async throws -> some IntentResult {
        SharedDefaults.setWater(min(SharedDefaults.water() + ml, 5000))
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Live Activity (lock screen + Dynamic Island) while a work shift is running.
struct ShiftAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {}
    var start: Date
}
