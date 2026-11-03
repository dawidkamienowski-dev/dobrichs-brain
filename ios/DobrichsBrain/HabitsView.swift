import SwiftData
import SwiftUI
import UserNotifications

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

enum HabitReminders {
    static func schedule(_ habit: Habit) {
        cancel(habit)
        guard let minutes = habit.reminderMinutes else { return }
        let id = habit.notificationID
        let body = "\(habit.icon) \(habit.name)"
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Czas na nawyk"
            content.body = body
            content.sound = .default
            var time = DateComponents()
            time.hour = minutes / 60
            time.minute = minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    static func cancel(_ habit: Habit) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [habit.notificationID])
    }
}

@Model
final class WaterDay {
    /// "yyyy-MM-dd", local time
    var day: String
    var ml: Int

    init(day: String, ml: Int = 0) {
        self.day = day
        self.ml = ml
    }
}

// MARK: - list

struct HabitsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var water: [WaterDay]
    @Query private var tasks: [TaskItem]
    @AppStorage("waterGoal") private var waterGoal: Int = 2000
    @State private var showAdd = false

    /// each part 0...1; the day bar is their average
    private func dayParts(waterML: Int) -> [DayPart] {
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
        return parts
    }

    var body: some View {
        let todayKey = Habit.key(.now)
        let waterML = water.first { $0.day == todayKey }?.ml ?? 0

        NavigationStack {
            List {
                Section { DaySummaryCard(parts: dayParts(waterML: waterML)) }
                Section { WaterCard(ml: waterML, goal: waterGoal) }

                Section {
                    ForEach(habits) { habit in
                        NavigationLink(value: habit) { HabitRow(habit: habit) }
                            .swipeActions {
                                Button(role: .destructive) {
                                    HabitReminders.cancel(habit)
                                    context.delete(habit)
                                } label: { Label("Usuń", systemImage: "trash") }
                            }
                    }
                }

                if habits.isEmpty {
                    ContentUnavailableView("Brak nawyków", systemImage: "flame",
                                           description: Text("Dodaj pierwszy nawyk przyciskiem +"))
                }
            }
            .navigationTitle("Nawyki")
            .navigationDestination(for: Habit.self) { HabitDetailView(habit: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Dodaj nawyk")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddHabitView(nextOrder: (habits.map(\.order).max() ?? -1) + 1)
            }
        }
    }
}

struct DayPart {
    let name: String
    let detail: String
    let value: Double
}

private struct DaySummaryCard: View {
    let parts: [DayPart]

    private var total: Double {
        parts.isEmpty ? 0 : parts.map(\.value).reduce(0, +) / Double(parts.count)
    }

    private var message: String {
        switch total {
        case 1...: return "Perfekcyjny dzień 🏆"
        case 0.75...: return "Prawie wszystko, dociśnij końcówkę 💪"
        case 0.4...: return "Dobrze idzie, jesteś w połowie"
        case 0.01...: return "Dobry początek, lecimy dalej"
        default: return "Dzień dopiero się zaczyna ☀️"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Twój dzień").font(.headline)
                Spacer()
                Text("\(Int((total * 100).rounded()))%")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            ProgressView(value: total)
                .tint(total >= 1 ? Color.green : Color.accentColor)
                .scaleEffect(x: 1, y: 2.5, anchor: .center)
                .padding(.vertical, 4)
            HStack(alignment: .top) {
                ForEach(parts, id: \.name) { p in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.caption).foregroundStyle(.secondary)
                        Text(p.detail).font(.caption.bold()).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct WaterCard: View {
    let ml: Int
    let goal: Int
    @Environment(\.modelContext) private var context

    private var maxML: Int { max(goal * 3 / 2, 1000) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Woda", systemImage: "drop.fill").font(.headline).foregroundStyle(.blue)
                Spacer()
                Text("\(ml) / \(goal) ml").bold().monospacedDigit()
            }
            Slider(value: Binding(get: { Double(ml) }, set: { set(Int($0)) }),
                   in: 0...Double(maxML), step: 50)
                .tint(.blue)
                .accessibilityIdentifier("waterSlider")
            HStack(spacing: 8) {
                ForEach([250, 500], id: \.self) { amount in
                    Button { set(ml + amount) } label: {
                        Text("+\(amount) ml")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
                if goal > 0 && ml >= goal {
                    Text("Cel osiągnięty 💧").font(.caption).foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func set(_ value: Int) {
        let key = Habit.key(.now)
        let clamped = max(0, min(value, maxML))
        let descriptor = FetchDescriptor<WaterDay>(predicate: #Predicate { $0.day == key })
        if let entry = try? context.fetch(descriptor).first {
            entry.ml = clamped
        } else {
            context.insert(WaterDay(day: key, ml: clamped))
        }
    }
}

private struct HabitRow: View {
    let habit: Habit

    private var lastWeek: [Date] {
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<7).reversed().map { Calendar.current.date(byAdding: .day, value: -$0, to: today)! }
    }

    var body: some View {
        let done = habit.isDone(.now)
        let streak = habit.currentStreak

        HStack(spacing: 12) {
            Text(habit.icon).font(.largeTitle)
            VStack(alignment: .leading, spacing: 5) {
                Text(habit.name).font(.headline)
                HStack(spacing: 4) {
                    ForEach(lastWeek, id: \.self) { day in
                        Circle()
                            .fill(habit.isDone(day) ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                }
                if streak > 0 {
                    Text("🔥 \(daysText(streak)) z rzędu").font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            Button { habit.toggle(.now) } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 34))
                    .foregroundStyle(done ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Odhacz \(habit.name)")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - detail

private struct HabitDetailView: View {
    @Bindable var habit: Habit
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var remind = false
    @State private var time = Date.now

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // Monday
        return c
    }

    var body: some View {
        List {
            Section {
                HStack {
                    stat("Obecna passa", daysText(habit.currentStreak))
                    stat("Najdłuższa", daysText(habit.bestStreak))
                    stat("30 dni", "\(Int((habit.rate(lastDays: 30) * 100).rounded()))%")
                }
            }

            Section {
                HStack {
                    Button { month = calendar.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.borderless)
                    Spacer()
                    Text(month.formatted(.dateTime.month(.wide).year()).capitalized).font(.headline)
                    Spacer()
                    Button { month = calendar.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.borderless)
                }
                monthGrid
            } footer: {
                Text("Dotknij dnia, żeby go odhaczyć albo cofnąć.")
            }

            Section("Przypomnienie") {
                Toggle("Codziennie", isOn: $remind)
                if remind {
                    DatePicker("Godzina", selection: $time, displayedComponents: .hourAndMinute)
                }
            }
        }
        .navigationTitle("\(habit.icon) \(habit.name)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            remind = habit.reminderMinutes != nil
            if let m = habit.reminderMinutes {
                time = Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: .now)!
            }
        }
        .onChange(of: remind) { updateReminder() }
        .onChange(of: time) { updateReminder() }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var monthGrid: some View {
        let cal = calendar
        let days = cal.range(of: .day, in: .month, for: month)!.count
        let offset = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let today = cal.startOfDay(for: .now)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
            ForEach(["Pn", "Wt", "Śr", "Cz", "Pt", "So", "Nd"], id: \.self) {
                Text($0).font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(0..<(offset + days), id: \.self) { i in
                if i < offset {
                    Color.clear.frame(height: 36)
                } else {
                    let day = cal.date(byAdding: .day, value: i - offset, to: month)!
                    let done = habit.isDone(day)
                    let future = day > today
                    Button { habit.toggle(day) } label: {
                        Text("\(i - offset + 1)")
                            .font(.callout.weight(cal.isDate(day, inSameDayAs: today) ? .bold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Circle().fill(done ? Color.accentColor : Color.clear))
                            .foregroundStyle(done ? Color.white : (future ? Color.secondary : Color.primary))
                    }
                    .buttonStyle(.borderless)
                    .disabled(future)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func updateReminder() {
        if remind {
            let t = Calendar.current.dateComponents([.hour, .minute], from: time)
            habit.reminderMinutes = (t.hour ?? 0) * 60 + (t.minute ?? 0)
        } else {
            habit.reminderMinutes = nil
        }
        HabitReminders.schedule(habit)
    }
}

// MARK: - add

private struct AddHabitView: View {
    let nextOrder: Int
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = "💪"
    @State private var remind = false
    @State private var time = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now)!

    private let icons = ["💪", "💧", "📚", "🏃", "🧘", "🚭", "🥗", "😴", "🦷", "💊", "🧠", "💰", "🚶", "🙏", "📵", "✍️"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nazwa, np. Siłownia", text: $name)
                Section("Ikona") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(icons, id: \.self) { i in
                            Button { icon = i } label: {
                                Text(i).font(.title2)
                                    .frame(width: 38, height: 38)
                                    .background(RoundedRectangle(cornerRadius: 8)
                                        .fill(icon == i ? Color.accentColor.opacity(0.25) : Color.clear))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Section {
                    Toggle("Codzienne przypomnienie", isOn: $remind)
                    if remind {
                        DatePicker("Godzina", selection: $time, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("Nowy nawyk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dodaj", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        var minutes: Int?
        if remind {
            let t = Calendar.current.dateComponents([.hour, .minute], from: time)
            minutes = (t.hour ?? 0) * 60 + (t.minute ?? 0)
        }
        let habit = Habit(name: name.trimmingCharacters(in: .whitespaces), icon: icon, order: nextOrder, reminderMinutes: minutes)
        context.insert(habit)
        HabitReminders.schedule(habit)
        dismiss()
    }
}
