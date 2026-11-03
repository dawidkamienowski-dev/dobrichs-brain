import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

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

// MARK: - list

struct HabitsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var tasks: [TaskItem]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                DaySections(habits: habits, tasks: tasks)

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
            .screenStyle(Theme.habits)
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

/// "Twój dzień" + water card. Water lives in the shared app-group defaults so the widget's +250 ml button can change it.
private struct DaySections: View {
    let habits: [Habit]
    let tasks: [TaskItem]
    @AppStorage private var waterML: Int
    @AppStorage("waterGoal", store: SharedDefaults.store) private var waterGoal: Int = 2000

    init(habits: [Habit], tasks: [TaskItem]) {
        self.habits = habits
        self.tasks = tasks
        _waterML = AppStorage(wrappedValue: 0, SharedDefaults.waterKey(), store: SharedDefaults.store)
    }

    var body: some View {
        let summary = DaySummary.make(habits: habits, tasks: tasks, waterML: waterML, waterGoal: waterGoal)
        Section { DaySummaryCard(summary: summary) }
        Section { WaterCard(ml: $waterML, goal: waterGoal) }
    }
}

private struct DaySummaryCard: View {
    let summary: DaySummary

    private func partColor(_ name: String) -> Color {
        switch name {
        case "Woda": return Theme.water
        case "Zadania": return Theme.tasks
        default: return Theme.habits
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                ProgressRing(progress: summary.total, size: 96, line: 12, tint: Theme.habits, label: "\(summary.percent)%")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Twój dzień").font(.title3.bold())
                    ForEach(summary.parts, id: \.name) { p in
                        HStack(spacing: 8) {
                            Circle().fill(partColor(p.name)).frame(width: 8, height: 8)
                            Text(p.name).font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(p.detail).font(.subheadline.bold()).monospacedDigit()
                        }
                    }
                }
            }
            Text(summary.message).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct WaterCard: View {
    @Binding var ml: Int
    let goal: Int

    private var maxML: Int { max(goal * 3 / 2, 1000) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text("Woda").font(.headline)
                } icon: {
                    IconBadge(systemName: "drop.fill", color: Theme.water)
                }
                Spacer()
                Text("\(ml) / \(goal) ml").bold().monospacedDigit()
            }
            Slider(value: Binding(get: { Double(ml) }, set: { ml = max(0, min(Int($0), maxML)) }),
                   in: 0...Double(maxML), step: 50) { editing in
                if !editing { WidgetCenter.shared.reloadAllTimelines() }
            }
            .tint(Theme.water)
            .accessibilityIdentifier("waterSlider")
            HStack(spacing: 8) {
                ForEach([250, 500], id: \.self) { amount in
                    Button {
                        ml = min(ml + amount, maxML)
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        Text("+\(amount) ml")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(Theme.water)
                            .background(Capsule().fill(Theme.water.opacity(0.16)))
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
                if goal > 0 && ml >= goal {
                    Text("Cel osiągnięty 💧").font(.caption.bold()).foregroundStyle(Theme.water)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HabitRow: View {
    let habit: Habit
    @Environment(\.modelContext) private var context

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
                            .fill(habit.isDone(day) ? Theme.habits : Color.secondary.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                }
                if streak > 0 {
                    Text("🔥 \(daysText(streak)) z rzędu").font(.caption).foregroundStyle(.orange).lineLimit(1).fixedSize()
                }
            }
            Spacer()
            Button {
                habit.toggle(.now)
                refreshWidgets(context)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 34))
                    .foregroundStyle(done ? Color.green : Theme.habits.opacity(0.5))
                    .symbolEffect(.bounce, value: done)
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
        .screenStyle(Theme.habits)
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
                            .background(Circle().fill(done ? Theme.habits : Color.clear))
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
