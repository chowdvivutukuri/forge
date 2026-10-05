import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ForgeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}

private func accent(_ abhi: Bool) -> Color {
    abhi ? Color(red: 0.70, green: 0.45, blue: 1.0) : Color(red: 0.95, green: 0.45, blue: 0.18)
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(s.setLabel, systemImage: "dumbbell.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent(s.abhi))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestOrElapsed(state: s, startedAt: context.attributes.startedAt)
                        .font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.exerciseName).font(.headline).lineLimit(1)
                        if !s.detail.isEmpty { Text(s.detail).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(accent(s.abhi))
            } compactTrailing: {
                if let end = s.restEnd, end > .now {
                    Text(timerInterval: Date.now...end, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                } else {
                    Text("\(s.completedSets)/\(s.totalSets)").monospacedDigit()
                }
            } minimal: {
                Image(systemName: "dumbbell.fill").foregroundStyle(accent(s.abhi))
            }
        }
    }
}

private struct RestOrElapsed: View {
    let state: WorkoutActivityAttributes.ContentState
    let startedAt: Date

    var body: some View {
        if let end = state.restEnd, end > .now {
            HStack(spacing: 4) {
                Text("Rest")
                Text(timerInterval: Date.now...end, countsDown: true).monospacedDigit()
            }
        } else {
            Text(startedAt, style: .timer).monospacedDigit()
        }
    }
}

private struct LockScreenView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(attributes.title, systemImage: "dumbbell.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent(state.abhi))
                    .lineLimit(1)
                Spacer()
                Text(attributes.startedAt, style: .timer)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 70, alignment: .trailing)
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.exerciseName).font(.headline).foregroundStyle(.white).lineLimit(1)
                    Text(state.detail.isEmpty ? state.setLabel : "\(state.setLabel) · \(state.detail)")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                }
                Spacer()
                if let end = state.restEnd, end > .now {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("REST").font(.caption2.weight(.bold)).foregroundStyle(accent(state.abhi))
                        Text(timerInterval: Date.now...end, countsDown: true)
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90, alignment: .trailing)
                    }
                }
            }
            ProgressView(value: Double(state.completedSets), total: Double(max(1, state.totalSets)))
                .tint(accent(state.abhi))
        }
        .padding()
    }
}
