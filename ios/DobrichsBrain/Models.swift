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
