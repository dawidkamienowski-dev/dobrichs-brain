import Foundation
import SwiftData

@Model
final class Note {
    var text: String
    var pinned: Bool
    // not "updated": that name clashes with Core Data's NSManagedObject.isUpdated
    var createdAt: Date
    var updatedAt: Date

    init(text: String, pinned: Bool = false, createdAt: Date = .now, updatedAt: Date = .now) {
        self.text = text
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class TaskItem {
    var title: String
    var due: Date?
    var done: Bool
    var doneAt: Date?
    var created: Date
    var notificationID: String

    init(title: String, due: Date? = nil, done: Bool = false, created: Date = .now) {
        self.title = title
        self.due = due
        self.done = done
        self.doneAt = done ? .now : nil
        self.created = created
        self.notificationID = UUID().uuidString
    }
}

@Model
final class WorkEntry {
    /// start of the day the shift belongs to
    var date: Date
    var start: Date?
    var end: Date?
    var breakMinutes: Int
    /// set instead of start/end when only the number of hours was entered
    var manualHours: Double?
    var note: String

    init(day: Date, start: Date? = nil, end: Date? = nil, breakMinutes: Int = 0,
         manualHours: Double? = nil, note: String = "") {
        self.date = Calendar.current.startOfDay(for: day)
        self.start = start
        self.end = end
        self.breakMinutes = breakMinutes
        self.manualHours = manualHours
        self.note = note
    }

    var hours: Double {
        if let manualHours { return manualHours }
        guard let start, let end else { return 0 }
        let minutes = end.timeIntervalSince(start) / 60 - Double(breakMinutes)
        return max(0, minutes) / 60
    }
}

enum Tags {
    private static let regex = try! NSRegularExpression(pattern: "#[\\p{L}\\p{N}_-]+")

    static func of(_ text: String) -> [String] {
        let ns = text as NSString
        var seen = Set<String>()
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range).lowercased() }
            .filter { seen.insert($0).inserted }
    }
}

@Model
final class Habit {
    var name: String
    var icon: String
    var order: Int
    var createdAt: Date
    /// days the habit was done, as "yyyy-MM-dd" in local time
    var doneDays: [String]
    /// daily reminder, minutes after midnight
    var reminderMinutes: Int?
    var notificationID: String

    init(name: String, icon: String, order: Int, reminderMinutes: Int? = nil, doneDays: [String] = []) {
        self.name = name
        self.icon = icon
        self.order = order
        self.createdAt = .now
        self.doneDays = doneDays
        self.reminderMinutes = reminderMinutes
        self.notificationID = UUID().uuidString
    }

    static func key(_ day: Date) -> String { localDay(day, "yyyy-MM-dd") }

    func isDone(_ day: Date) -> Bool { doneDays.contains(Self.key(day)) }

    func toggle(_ day: Date) {
        var days = doneDays
        let k = Self.key(day)
        if let i = days.firstIndex(of: k) { days.remove(at: i) } else { days.append(k) }
        doneDays = days
    }

    /// consecutive days up to today (or yesterday, if today isn't ticked yet)
    var currentStreak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: .now)
        if !isDone(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while isDone(day) {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    var bestStreak: Int {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let days = Set(doneDays).compactMap { f.date(from: $0) }.sorted()
        var best = 0, run = 0
        var prev: Date?
        for d in days {
            if let p = prev, Calendar.current.dateComponents([.day], from: p, to: d).day == 1 { run += 1 } else { run = 1 }
            best = max(best, run)
            prev = d
        }
        return best
    }

    func rate(lastDays: Int) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let done = (0..<lastDays).filter { isDone(cal.date(byAdding: .day, value: -$0, to: today)!) }.count
        return Double(done) / Double(lastDays)
    }
}

func daysText(_ n: Int) -> String { n == 1 ? "1 dzień" : "\(n) dni" }

/// Formats a date in the device's time zone (ISO8601FormatStyle would use GMT and shift the day).
func localDay(_ date: Date, _ pattern: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = pattern
    return f.string(from: date)
}
