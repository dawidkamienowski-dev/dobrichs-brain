import ActivityKit
import SwiftData
import SwiftUI
import WidgetKit

@main
struct DobrichsBrainWidgetBundle: WidgetBundle {
    var body: some Widget {
        DayWidget()
        ShiftLiveActivity()
    }
}

// MARK: - "Twój dzień" widget

struct DayEntry: TimelineEntry {
    let date: Date
    let summary: DaySummary
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: .now, summary: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        // the app reloads us on every change; otherwise refresh at midnight for the new day
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        completion(Timeline(entries: [entry()], policy: .after(midnight)))
    }

    private func entry() -> DayEntry {
        guard let container = try? makeContainer() else { return DayEntry(date: .now, summary: .placeholder) }
        return DayEntry(date: .now, summary: DaySummary.load(ModelContext(container)))
    }
}

struct DayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayWidget", provider: DayProvider()) { entry in
            DayEntryView(entry: entry)
        }
        .configurationDisplayName("Twój dzień")
        .description("Postęp dnia: nawyki, woda i zadania. Woda dodawana jednym kliknięciem.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private struct DayEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        DayWidgetView(summary: entry.summary, family: family)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - work shift Live Activity (lock screen + Dynamic Island)

struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftAttributes.self) { context in
            let start = context.attributes.start
            HStack {
                Image(systemName: "briefcase.fill").font(.title2).foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text("W pracy").font(.headline)
                    Text("od \(start.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    .font(.title.bold())
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
            .padding()
        } dynamicIsland: { context in
            let start = context.attributes.start
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Praca", systemImage: "briefcase.fill").foregroundStyle(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Zmiana od \(start.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "briefcase.fill").foregroundStyle(.blue)
            } compactTrailing: {
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .frame(width: 56)
            } minimal: {
                Image(systemName: "briefcase.fill").foregroundStyle(.blue)
            }
        }
    }
}
