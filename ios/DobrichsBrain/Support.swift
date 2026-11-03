import Foundation
import SwiftData
import UserNotifications

// MARK: - formatting

extension Double {
    var hoursText: String { formatted(.number.precision(.fractionLength(0...2))) + " h" }
}

func pln(_ value: Double) -> String {
    value.formatted(.currency(code: "PLN"))
}

func durationText(_ seconds: TimeInterval) -> String {
    let m = max(0, Int(seconds / 60))
    return "\(m / 60)h \(String(format: "%02d", m % 60))m"
}

/// Formats a date in the device's time zone (ISO8601FormatStyle would use GMT and shift the day).
func localDay(_ date: Date, _ pattern: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = pattern
    return f.string(from: date)
}

// MARK: - local notifications

enum Reminders {
    static func schedule(_ task: TaskItem) {
        guard let due = task.due, due > .now, !task.done else { return }
        let id = task.notificationID
        let title = task.title
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Dobrich’s Brain"
            content.body = title
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    static func cancel(_ task: TaskItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.notificationID])
    }
}

// MARK: - import of the web app's JSON backup

struct WebBackup: Decodable {
    struct N: Decodable { var text: String; var pinned: Bool?; var created: String?; var updated: String? }
    struct T: Decodable { var title: String; var due: String?; var done: Bool?; var created: String? }
    struct W: Decodable { var date: String; var start: String?; var end: String?; var breakMin: Int?; var hours: Double?; var note: String? }
    struct S: Decodable { var target: Double?; var rate: Double? }

    var notes: [N]
    var tasks: [T]
    var work: [W]
    var settings: S?

    private static func iso(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    private static func local(_ day: String, _ time: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: "\(day) \(time)")
    }

    /// Inserts everything into the context; returns a summary for the user.
    func importInto(_ context: ModelContext) -> String {
        for n in notes {
            context.insert(Note(text: n.text, pinned: n.pinned ?? false,
                                createdAt: Self.iso(n.created) ?? .now, updatedAt: Self.iso(n.updated) ?? .now))
        }
        for t in tasks {
            let item = TaskItem(title: t.title, due: Self.iso(t.due), done: t.done ?? false,
                                created: Self.iso(t.created) ?? .now)
            context.insert(item)
            Reminders.schedule(item)
        }
        var workCount = 0
        for w in work {
            guard let day = Self.local(w.date, "12:00") else { continue }
            if let h = w.hours {
                context.insert(WorkEntry(day: day, manualHours: h, note: w.note ?? ""))
            } else if let s = w.start, let e = w.end, let start = Self.local(w.date, s), var end = Self.local(w.date, e) {
                if end < start { end = end.addingTimeInterval(86_400) } // night shift
                context.insert(WorkEntry(day: day, start: start, end: end, breakMinutes: w.breakMin ?? 0, note: w.note ?? ""))
            } else { continue }
            workCount += 1
        }
        if let target = settings?.target { UserDefaults.standard.set(target, forKey: "monthlyTarget") }
        if let rate = settings?.rate { UserDefaults.standard.set(rate, forKey: "hourlyRate") }
        return "Zaimportowano: \(notes.count) notatek, \(tasks.count) zadań, \(workCount) wpisów pracy."
    }
}

// MARK: - sample data for screenshots

enum DemoData {
    static func seed(_ context: ModelContext) {
        let cal = Calendar.current
        let now = Date.now
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now))!
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }

        context.insert(Note(text: "Pomysł na skrypt MTA: system pracy kuriera #mta #pomysly", pinned: true))
        context.insert(Note(text: "Kod do bramy: 4521 #dom", updatedAt: now.addingTimeInterval(-3600)))
        context.insert(Note(text: "Kupić prezent dla mamy na urodziny – perfumy? #prezenty", updatedAt: now.addingTimeInterval(-86_400)))

        context.insert(TaskItem(title: "Zapłacić za serwer", due: at(-1, 10)))
        context.insert(TaskItem(title: "Oddzwonić do szefa", due: at(0, 23, 30)))
        context.insert(TaskItem(title: "Wizyta u dentysty", due: at(5, 15, 30)))
        context.insert(TaskItem(title: "Kupić baterie"))
        context.insert(TaskItem(title: "Wymienić olej", done: true))

        let firstOfMonth = cal.dateInterval(of: .month, for: now)!.start
        let daysSoFar = cal.dateComponents([.day], from: firstOfMonth, to: cal.startOfDay(for: now)).day ?? 0
        for offset in stride(from: -daysSoFar, to: 0, by: 1) {
            let day = at(offset, 0)
            if cal.isDateInWeekend(day) { continue }
            let late = offset % 3 == 0
            context.insert(WorkEntry(day: day, start: at(offset, late ? 14 : 7), end: at(offset, late ? 22 : 15, 30), breakMinutes: 30))
        }

        // habits: done-pattern over the last 40 days (index 0 = today)
        let habits: [(String, String, (Int) -> Bool)] = [
            ("Siłownia", "💪", { $0 % 7 == 1 || $0 % 7 == 3 || $0 % 7 == 5 }),
            ("Medytacja", "🧘", { $0 >= 1 && $0 <= 12 || $0 >= 15 }),
            ("Czytanie 10 min", "📚", { $0 % 3 != 2 }),
            ("Bez papierosów", "🚭", { $0 <= 20 }),
        ]
        for (i, h) in habits.enumerated() {
            let days = (0..<40).filter(h.2).map { Habit.key(at(-$0, 12)) }
            context.insert(Habit(name: h.0, icon: h.1, order: i, reminderMinutes: i == 1 ? 9 * 60 : nil, doneDays: days))
        }

        context.insert(WaterDay(day: Habit.key(now), ml: 1250))
        UserDefaults.standard.set(2000, forKey: "waterGoal")

        UserDefaults.standard.set(168.0, forKey: "monthlyTarget")
        UserDefaults.standard.set(32.5, forKey: "hourlyRate")
        UserDefaults.standard.set(now.addingTimeInterval(-2 * 3600 - 15 * 60).timeIntervalSince1970, forKey: "shiftStart")
    }
}
