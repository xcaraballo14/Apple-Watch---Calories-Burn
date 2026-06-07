import Foundation
import HealthKit

/// The kind of activity the user is doing to burn their reward calories.
/// Maps onto a real `HKWorkoutActivityType` so the saved workout is categorized
/// correctly in Health (instead of everything landing under "Other").
enum WorkoutType: String, CaseIterable, Identifiable {
    case walk, run, bike, strength, other

    var id: String { rawValue }

    /// Short retro label shown under each icon.
    var label: String {
        switch self {
        case .walk:     "WALK"
        case .run:      "RUN"
        case .bike:     "BIKE"
        case .strength: "LIFT"
        case .other:    "OTHER"
        }
    }

    /// SF Symbol used in the picker.
    var icon: String {
        switch self {
        case .walk:     "figure.walk"
        case .run:      "figure.run"
        case .bike:     "figure.outdoor.cycle"
        case .strength: "dumbbell.fill"
        case .other:    "bolt.heart.fill"
        }
    }

    var activityType: HKWorkoutActivityType {
        switch self {
        case .walk:     .walking
        case .run:      .running
        case .bike:     .cycling
        case .strength: .traditionalStrengthTraining
        case .other:    .other
        }
    }

    /// Outdoor where it makes sense so distance/route can be captured later.
    var locationType: HKWorkoutSessionLocationType {
        switch self {
        case .walk, .run, .bike: .outdoor
        case .strength, .other:  .unknown
        }
    }
}
