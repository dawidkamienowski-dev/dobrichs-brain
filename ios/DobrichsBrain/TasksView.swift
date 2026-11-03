import SwiftData
import SwiftUI

struct TasksView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.created) private var tasks: [TaskItem]
    @State private var title = ""
    @State private var hasDue = false
    @State private var due = Date.now.addingTimeInterval(3600)

    var body: some View {
        let now = Date.now
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        let open = tasks.filter { !$0.done }.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
        let done = tasks.filter(\.done).sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) }

        NavigationStack {
            List {
                Section {
                    TextField("Nowe zadanie…", text: $title)
                        .accessibilityIdentifier("taskTitle")
                    Toggle("Przypomnienie", isOn: $hasDue)
                    if hasDue {
                        DatePicker("Kiedy", selection: $due, in: now...)
                    }
                    Button("Dodaj", action: add)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                section("Zaległe", open.filter { ($0.due ?? .distantFuture) < now }, color: .red)
                section("Dziś", open.filter { guard let d = $0.due else { return false }; return d >= now && d < endOfToday })
                section("Później", open.filter { guard let d = $0.due else { return false }; return d >= endOfToday })
                section("Bez terminu", open.filter { $0.due == nil })
                section("Zrobione", Array(done.prefix(30)))

                if tasks.isEmpty {
                    ContentUnavailableView("Brak zadań", systemImage: "checkmark.circle", description: Text("Czysta głowa 🧠"))
                }
            }
            .navigationTitle("Zadania")
        }
    }

    @ViewBuilder
    private func section(_ name: String, _ items: [TaskItem], color: Color = .secondary) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { task in
                    TaskRow(task: task) { toggle(task) }
                        .swipeActions {
                            Button(role: .destructive) { delete(task) } label: {
                                Label("Usuń", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("\(name) · \(items.count)").foregroundStyle(color)
            }
        }
    }

    private func add() {
        let text = title.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let task = TaskItem(title: text, due: hasDue ? due : nil)
        context.insert(task)
        Reminders.schedule(task)
        title = ""
        hasDue = false
    }

    private func toggle(_ task: TaskItem) {
        task.done.toggle()
        task.doneAt = task.done ? .now : nil
        if task.done { Reminders.cancel(task) } else { Reminders.schedule(task) }
    }

    private func delete(_ task: TaskItem) {
        Reminders.cancel(task)
        context.delete(task)
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.done ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .strikethrough(task.done)
                    .foregroundStyle(task.done ? Color.secondary : Color.primary)
                if let due = task.due {
                    Label(due.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()), systemImage: "bell")
                        .font(.caption)
                        .foregroundStyle(!task.done && due < .now ? Color.red : Color.secondary)
                }
            }
        }
    }
}
