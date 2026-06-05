import WidgetKit
import SwiftUI

// MARK: - Palette (kept local so the widget target stays self-contained)

private enum Palette {
    static let green  = Color(red: 0.00, green: 1.00, blue: 0.53) // #00ff88
    static let yellow = Color(red: 1.00, green: 0.84, blue: 0.00) // #ffd700
    static let orange = Color(red: 1.00, green: 0.42, blue: 0.21) // #ff6b35
    static let ramp   = Gradient(colors: [orange, yellow, green])
}

// MARK: - Timeline

struct BurnRewardEntry: TimelineEntry {
    let date: Date
    let snapshot: BurnRewardSnapshot
}

struct BurnRewardProvider: TimelineProvider {
    func placeholder(in context: Context) -> BurnRewardEntry {
        BurnRewardEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (BurnRewardEntry) -> Void) {
        let snap = context.isPreview ? .sample : BurnRewardShared.load()
        completion(BurnRewardEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BurnRewardEntry>) -> Void) {
        let entry = BurnRewardEntry(date: Date(), snapshot: BurnRewardShared.load())
        // The app pushes reloads whenever calories change; refresh hourly as a fallback.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct BurnRewardComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BurnRewardComplication", provider: BurnRewardProvider()) { entry in
            BurnRewardComplicationView(entry: entry)
        }
        .configurationDisplayName("EXP Progress")
        .description("Track calories burned toward your reward.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

// MARK: - Views

struct BurnRewardComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BurnRewardEntry

    private var snapshot: BurnRewardSnapshot { entry.snapshot }
    private var percent: Int { Int(snapshot.progress * 100) }

    var body: some View {
        switch family {
        case .accessoryCircular:     circular
        case .accessoryCorner:       corner
        case .accessoryInline:       inline
        case .accessoryRectangular:  rectangular
        default:                     circular
        }
    }

    // Ring with percentage in the middle, flame on the rim.
    private var circular: some View {
        Gauge(value: snapshot.progress) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(percent)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Palette.ramp)
    }

    // Corner of the watch face: flame icon with a curved gauge label.
    private var corner: some View {
        Image(systemName: "flame.fill")
            .font(.title)
            .foregroundStyle(Palette.orange)
            .widgetLabel {
                Gauge(value: snapshot.progress) {
                    Text("EXP")
                } currentValueLabel: {
                    Text("\(percent)%")
                }
                .tint(Palette.ramp)
            }
    }

    // Single line of text along an edge of the face.
    private var inline: some View {
        if snapshot.isActive {
            return Label("\(snapshot.caloriesBurned)/\(snapshot.totalGoal) CAL",
                         systemImage: "flame.fill")
        } else {
            return Label("Pick a reward", systemImage: "flame.fill")
        }
    }

    // Largest accessory: title, calories and a linear bar.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(snapshot.emoji)
                Text(snapshot.isActive ? "\(snapshot.caloriesLeft) CAL LEFT" : "BURNREWARD")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Gauge(value: snapshot.progress) {
                EmptyView()
            } currentValueLabel: {
                Text("\(snapshot.caloriesBurned) / \(snapshot.totalGoal)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(Palette.ramp)
        }
    }
}
