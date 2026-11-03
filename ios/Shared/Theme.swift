import SwiftUI

/// One design language for the whole app (and widgets):
/// rounded type, continuous corners, a colour per section, Liquid Glass on iOS 26.
enum Theme {
    static let notes = Color.indigo
    static let tasks = Color.orange
    static let habits = Color.pink
    static let water = Color.cyan
    static let work = Color.teal
    static let more = Color.gray

    static let radius: CGFloat = 22
}

/// Coloured rounded-square icon, like in iOS Settings / Health.
struct IconBadge: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

/// Activity-style progress ring.
struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = 72
    var line: CGFloat = 9
    var tint: Color = .accentColor
    var label: String?

    var body: some View {
        let color = progress >= 1 ? Color.green : tint
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(AngularGradient(colors: [color.opacity(0.65), color], center: .center),
                        style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let label {
                Text(label)
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .frame(width: size, height: size)
    }
}

/// Section title with an icon badge, used as List section headers.
struct SectionTitle: View {
    let title: String
    let systemName: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            IconBadge(systemName: systemName, color: color, size: 22)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
        }
        .textCase(nil)
    }
}

extension View {
    /// Soft section-coloured backdrop behind a List, plus the section tint for controls.
    func screenStyle(_ tint: Color) -> some View {
        scrollContentBackground(.hidden)
            .background {
                LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.04), Color(.systemGroupedBackground)],
                               startPoint: .top, endPoint: .init(x: 0.5, y: 0.45))
                    .ignoresSafeArea()
            }
            .tint(tint)
    }

    /// Main action of a screen: Liquid Glass on iOS 26, filled button before.
    @ViewBuilder
    func primaryAction() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
        #else
        buttonStyle(.borderedProminent)
        #endif
    }

    /// Secondary/chip action: glass on iOS 26, tinted bordered before.
    @ViewBuilder
    func secondaryAction() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
        #else
        buttonStyle(.bordered)
        #endif
    }

    /// Card surface outside of Lists (glass on iOS 26).
    @ViewBuilder
    func card(_ radius: CGFloat = Theme.radius) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        #else
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        #endif
    }

    /// iOS 26 tab bar shrinks while scrolling.
    @ViewBuilder
    func minimizingTabBar() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
