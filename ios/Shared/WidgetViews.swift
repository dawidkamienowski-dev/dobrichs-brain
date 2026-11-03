import AppIntents
import SwiftUI
import WidgetKit

/// Widget layout; also shown in the app's "Podgląd widżetów" screen.
struct DayWidgetView: View {
    let summary: DaySummary
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: summary.total) {
                Image(systemName: "brain.head.profile")
            } currentValueLabel: {
                Text("\(summary.percent)")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Twój dzień \(summary.percent)%").font(.headline)
                ProgressView(value: summary.total)
                Text("💧 \(summary.waterML) ml").font(.caption)
            }
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private func ring(size: CGFloat, line: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: line)
            Circle()
                .trim(from: 0, to: summary.total)
                .stroke(summary.total >= 1 ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(summary.percent)%")
                .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }

    private var small: some View {
        VStack(spacing: 8) {
            Text("Twój dzień").font(.caption.bold()).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ring(size: 72, line: 9)
            Button(intent: AddWaterIntent(ml: 250)) {
                Text("💧 +250 ml").font(.caption.bold()).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            ring(size: 96, line: 11)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(summary.parts, id: \.name) { p in
                    HStack {
                        Text(p.name).font(.caption)
                        Spacer()
                        Text(p.detail).font(.caption.bold()).monospacedDigit()
                    }
                    ProgressView(value: p.value)
                        .tint(p.name == "Woda" ? Color.blue : Color.accentColor)
                }
                HStack(spacing: 6) {
                    Button(intent: AddWaterIntent(ml: 250)) { Text("💧 +250") }
                    Button(intent: AddWaterIntent(ml: 500)) { Text("💧 +500") }
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .tint(.blue)
            }
        }
    }
}
