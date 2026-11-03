import SwiftData
import SwiftUI

struct WorkView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkEntry.date, order: .reverse) private var entries: [WorkEntry]
    @AppStorage("shiftStart") private var shiftStart: Double = 0
    @AppStorage("monthlyTarget") private var target: Double = 168
    @AppStorage("hourlyRate") private var rate: Double = 0
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var showAdd = false
    @State private var askBreak = false
    @State private var breakText = "0"

    private var monthEntries: [WorkEntry] {
        entries.filter { Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    var body: some View {
        let list = monthEntries
        let total = list.reduce(0) { $0 + $1.hours }
        let days = Set(list.map(\.date)).count

        NavigationStack {
            List {
                Section { shiftCard }

                Section {
                    HStack {
                        Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                            .buttonStyle(.borderless)
                        Spacer()
                        Text(month.formatted(.dateTime.month(.wide).year()).capitalized)
                            .font(.headline)
                        Spacer()
                        Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(.borderless)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Przepracowane").font(.caption).foregroundStyle(.secondary)
                        Text(total.hoursText)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        if target > 0 {
                            ProgressView(value: min(total / target, 1))
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                            Text("cel \(target.hoursText) · zostało \(max(0, target - total).hoursText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    statRow("Dni w pracy", "\(days)", icon: "calendar", color: .blue)
                    statRow("Średnio dziennie", days > 0 ? (total / Double(days)).hoursText : "–", icon: "chart.bar.fill", color: .purple)
                    if rate > 0 {
                        statRow("Zarobek brutto", pln(total * rate), icon: "banknote.fill", color: .green)
                    }
                }

                Section("Wpisy") {
                    if list.isEmpty {
                        Text("Brak wpisów w tym miesiącu").foregroundStyle(.secondary)
                    }
                    ForEach(list) { entry in
                        WorkRow(entry: entry)
                            .swipeActions {
                                Button(role: .destructive) { context.delete(entry) } label: {
                                    Label("Usuń", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Praca")
            .screenStyle(Theme.work)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: csvFile(list)) { Image(systemName: "square.and.arrow.up") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Dodaj wpis")
                }
            }
            .sheet(isPresented: $showAdd) { AddWorkEntryView() }
            .alert("Ile minut przerwy?", isPresented: $askBreak) {
                TextField("0", text: $breakText).keyboardType(.numberPad)
                Button("Zapisz", action: endShift)
                Button("Anuluj", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var shiftCard: some View {
        if shiftStart > 0 {
            let start = Date(timeIntervalSince1970: shiftStart)
            VStack(spacing: 8) {
                Text("W pracy od \(start.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    Text(durationText(ctx.date.timeIntervalSince(start)))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.work.gradient)
                        .contentTransition(.numericText())
                }
                Button {
                    breakText = "0"
                    askBreak = true
                } label: {
                    Text("Zakończ zmianę").frame(maxWidth: .infinity)
                }
                .primaryAction()
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } else {
            Button {
                shiftStart = Date.now.timeIntervalSince1970
                ShiftActivity.start(.now)
            } label: {
                Label("Zaczynam pracę", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .primaryAction()
            .controlSize(.large)
            .padding(.vertical, 6)
        }
    }

    private func statRow(_ title: String, _ value: String, icon: String, color: Color) -> some View {
        LabeledContent {
            Text(value).monospacedDigit()
        } label: {
            Label { Text(title) } icon: { IconBadge(systemName: icon, color: color) }
        }
    }

    private func endShift() {
        let start = Date(timeIntervalSince1970: shiftStart)
        context.insert(WorkEntry(day: start, start: start, end: .now, breakMinutes: Int(breakText) ?? 0))
        shiftStart = 0
        ShiftActivity.end()
    }

    private func shiftMonth(_ delta: Int) {
        month = Calendar.current.date(byAdding: .month, value: delta, to: month)!
    }

    private func csvFile(_ list: [WorkEntry]) -> URL {
        let time: (Date?) -> String = { $0.map { $0.formatted(date: .omitted, time: .shortened) } ?? "" }
        var rows = ["Data;Od;Do;Przerwa (min);Godziny;Notatka"]
        for e in list.reversed() {
            let fields = [localDay(e.date, "yyyy-MM-dd"), time(e.start), time(e.end),
                          e.breakMinutes > 0 ? "\(e.breakMinutes)" : "",
                          e.hours.formatted(.number.precision(.fractionLength(0...2))), e.note]
            rows.append(fields.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ";"))
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("praca-\(localDay(month, "yyyy-MM")).csv")
        try? ("\u{FEFF}" + rows.joined(separator: "\r\n")).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

private struct WorkRow: View {
    let entry: WorkEntry

    private var detail: String? {
        guard let s = entry.start, let e = entry.end else { return nil }
        var text = "\(s.formatted(date: .omitted, time: .shortened))–\(e.formatted(date: .omitted, time: .shortened))"
        if entry.breakMinutes > 0 { text += ", przerwa \(entry.breakMinutes) min" }
        return text
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month()))
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                if !entry.note.isEmpty {
                    Text(entry.note).font(.caption)
                }
            }
            Spacer()
            Text(entry.hours.hoursText).bold().monospacedDigit()
        }
    }
}

private struct AddWorkEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date.now
    @State private var byHours = false
    @State private var from = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now)!
    @State private var to = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!
    @State private var breakMinutes = 0
    @State private var hours: Double = 8
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Dzień", selection: $day, displayedComponents: .date)
                Picker("Sposób", selection: $byHours) {
                    Text("Od–do").tag(false)
                    Text("Liczba godzin").tag(true)
                }
                .pickerStyle(.segmented)

                if byHours {
                    LabeledContent("Godziny") {
                        TextField("8", value: $hours, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    DatePicker("Od", selection: $from, displayedComponents: .hourAndMinute)
                    DatePicker("Do", selection: $to, displayedComponents: .hourAndMinute)
                    Stepper("Przerwa: \(breakMinutes) min", value: $breakMinutes, in: 0...240, step: 5)
                }
                TextField("Notatka (opcjonalnie)", text: $note)
            }
            .navigationTitle("Nowy wpis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Zapisz", action: save) }
            }
        }
    }

    private func onDay(_ time: Date) -> Date {
        let cal = Calendar.current
        let t = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: day)!
    }

    private func save() {
        if byHours {
            context.insert(WorkEntry(day: day, manualHours: hours, note: note))
        } else {
            let start = onDay(from)
            var end = onDay(to)
            if end <= start { end = end.addingTimeInterval(86_400) } // night shift past midnight
            context.insert(WorkEntry(day: day, start: start, end: end, breakMinutes: breakMinutes, note: note))
        }
        dismiss()
    }
}
