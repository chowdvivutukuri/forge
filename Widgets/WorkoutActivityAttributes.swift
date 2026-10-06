#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// The lock-screen / Dynamic Island workout card. Compiled into both the app and the widget extension.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        /// "Set 2 of 4"
        var setLabel: String
        /// "135 lb × 8", or "" when there's nothing to show
        var detail: String
        var completedSets: Int
        var totalSets: Int
        /// When the current rest ends; nil when not resting.
        var restEnd: Date?
        var abhi: Bool
    }

    var title: String
    var startedAt: Date
}
#endif
