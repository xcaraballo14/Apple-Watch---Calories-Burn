import Combine
import Foundation
import SwiftUI
import UIKit
import UserNotifications

/// Local-notification layer — the "app is closed" half of C6. Everything is
/// scheduled on this iPhone with UNUserNotificationCenter: no server, no push
/// certificates, nothing leaves the device.
///
/// Two channels, individually toggleable in Settings:
/// - **Achievements** — badge unlocks + level-ups, posted only when they're
///   detected while the app is backgrounded (quest-end mirroring background-
///   launches the app, which is exactly that moment). In the foreground the
///   in-app toast owns the celebration, so nothing posts twice.
/// - **Streak reminder** — one nudge at a user-picked time, only on a day an
///   active streak (≥ 2 days) would otherwise end, canceled the moment a quest
///   is earned that day. It never rolls over to tomorrow with stale copy and
///   never fires after a streak has already broken — encouragement, not guilt.
///
/// Note: unlike HealthKit, `getNotificationSettings` reports honestly, so the
/// Settings UI is allowed to reflect the real authorization state.
@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    // MARK: - Preferences (persisted; @Published so Settings stays live)

    @Published var achievementsEnabled: Bool {
        didSet { defaults.set(achievementsEnabled, forKey: Keys.achievements) }
    }
    @Published var streakReminderEnabled: Bool {
        didSet { defaults.set(streakReminderEnabled, forKey: Keys.streak) }
    }
    @Published var challengeReminderEnabled: Bool {
        didSet { defaults.set(challengeReminderEnabled, forKey: Keys.challenge) }
    }
    /// Minutes from midnight for the streak reminder (default 18:00).
    @Published var reminderMinutes: Int {
        didSet { defaults.set(reminderMinutes, forKey: Keys.reminderMinutes) }
    }
    /// Mirrors the real system permission; refreshed on demand.
    @Published private(set) var authStatus: UNAuthorizationStatus = .notDetermined

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let achievements = "br.notifyAchievements"
        static let streak = "br.notifyStreak"
        static let challenge = "br.notifyChallenge"
        static let reminderMinutes = "br.notifyStreakMinutes"
    }

    private init() {
        achievementsEnabled = defaults.bool(forKey: Keys.achievements)
        streakReminderEnabled = defaults.bool(forKey: Keys.streak)
        challengeReminderEnabled = defaults.bool(forKey: Keys.challenge)
        let stored = defaults.integer(forKey: Keys.reminderMinutes)
        reminderMinutes = stored > 0 ? stored : 18 * 60
    }

    /// True when a channel is on but iOS-level permission is denied — drives
    /// the "turned off in iOS Settings" hint row.
    var showDeniedHint: Bool {
        (achievementsEnabled || streakReminderEnabled || challengeReminderEnabled)
            && authStatus == .denied
    }

    // MARK: - Authorization

    func refreshAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
    }

    /// Called when a channel is switched on: ask the system once if it hasn't
    /// been asked, then reflect whatever the honest answer is.
    func ensureAuthorization() async {
        await refreshAuthorization()
        guard authStatus == .notDetermined else { return }
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
        await refreshAuthorization()
    }

    private var isAuthorized: Bool {
        authStatus == .authorized || authStatus == .provisional
    }

    // MARK: - Achievements (event-driven)

    func postBadgeUnlocks(_ badges: [Badge]) {
        guard achievementsEnabled, canPostNow else { return }
        for badge in badges {
            post(
                id: "br.badge.\(badge.id)",
                title: "Badge earned: \(badge.name) \(badge.emoji)",
                body: badge.requirement
            )
        }
    }

    func postLevelUp(level: Int, title rankTitle: String) {
        guard achievementsEnabled, canPostNow else { return }
        post(
            id: "br.level.\(level)",
            title: "Level \(level) reached! ⬆️",
            body: "You're now a \(rankTitle)."
        )
    }

    /// Personal-record break — rides the achievements channel.
    func postRecordBreak(id: String, title: String, body: String) {
        guard achievementsEnabled, canPostNow else { return }
        post(id: "br.\(id)", title: title, body: body)
    }

    /// Achievements only post while the app is backgrounded — in the
    /// foreground the badge toast owns the moment.
    private var canPostNow: Bool {
        UIApplication.shared.applicationState != .active
    }

    private func post(id: String, title: String, body: String) {
        Task {
            await refreshAuthorization()
            guard isAuthorized else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: id, content: content, trigger: nil)
            )
        }
    }

    // MARK: - Streak reminder (scheduled, today-only)

    private static let streakReminderID = "br.streakReminder"

    /// Recomputed on every quest-list change and on Settings edits. Removes the
    /// pending reminder, then schedules one for later **today** only when the
    /// streak is alive (≥ 2), nothing is earned yet today, the chosen time is
    /// still ahead, and the channel is on.
    func rescheduleStreakReminder(streakDays: Int, earnedToday: Bool, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.streakReminderID])

        guard streakReminderEnabled,
              streakDays >= GameBalance.streakReminderMinDays,
              !earnedToday else { return }

        let calendar = Calendar.current
        guard let fireDate = calendar.date(
            bySettingHour: reminderMinutes / 60,
            minute: reminderMinutes % 60,
            second: 0, of: now
        ), fireDate > now else { return }   // time already passed → stay silent today

        Task {
            await refreshAuthorization()
            guard isAuthorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "\(streakDays)-day streak 🔥"
            content.body = "One quest today keeps it going."
            content.sound = .default
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate
            )
            try? await center.add(UNNotificationRequest(
                identifier: Self.streakReminderID,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }
    }

    // MARK: - Weekly challenge reminder (scheduled, last full day of the week)

    private static let challengeReminderID = "br.challengeReminder"

    /// One heads-up on the week's last full day at the shared reminder time —
    /// only when the challenge is at least half done but not finished (someone
    /// who never engaged this week gets silence, not homework). Recomputed on
    /// every quest-list change; completing the challenge cancels it.
    func rescheduleChallengeReminder(_ challenge: WeeklyChallenge?, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.challengeReminderID])

        guard challengeReminderEnabled,
              let challenge,
              !challenge.isComplete,
              challenge.fraction >= GameBalance.challengeReminderMinFraction else { return }

        let calendar = Calendar.current
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: challenge.weekEnd),
              let fireDate = calendar.date(
                  bySettingHour: reminderMinutes / 60,
                  minute: reminderMinutes % 60,
                  second: 0, of: lastDay
              ), fireDate > now else { return }   // window passed → silent this week

        let remaining = challenge.goal - challenge.progress
        Task {
            await refreshAuthorization()
            guard isAuthorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "\(challenge.emoji) \(challenge.name)"
            content.body = "You're \(remaining.formatted()) \(challenge.unitLabel(for: remaining)) from this week's challenge."
            content.sound = .default
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate
            )
            try? await center.add(UNNotificationRequest(
                identifier: Self.challengeReminderID,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }
    }
}
