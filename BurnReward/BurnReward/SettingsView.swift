import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var model: DashboardViewModel
    @ObservedObject private var notifications = NotificationService.shared
    @Environment(\.scenePhase) private var scenePhase

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// The streak-reminder time as a Date, bridged to persisted minutes.
    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: notifications.reminderMinutes / 60,
                minute: notifications.reminderMinutes % 60,
                second: 0, of: .now
            ) ?? .now
        } set: { newValue in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            notifications.reminderMinutes = (parts.hour ?? 18) * 60 + (parts.minute ?? 0)
            model.rescheduleStreakReminder()
            model.rescheduleChallengeReminder()
        }
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Settings now lives behind the CHARACTER tab's gear (sheet),
                // so it carries its own Done.
                BRTabHeader("SETTINGS") {
                    Button("Done") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(BRTheme.blueFG)
                }
                settingsList
            }
            .background(BRTheme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .task { await notifications.refreshAuthorization() }
            // Coming back from the iOS Settings app: reflect the honest answer.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await notifications.refreshAuthorization() }
                }
            }
        }
    }

    private var settingsList: some View {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(BRTheme.alertRed)
                            .accessibilityHidden(true)
                        Text("Your quests live in Apple Health. BurnReward reads the workouts your watch saved — nothing is stored on a server.")
                            .font(.footnote)
                            .foregroundStyle(BRTheme.textMuted)
                    }
                    .padding(.vertical, 4)
                    Link(destination: URL(string: "x-apple-health://")!) {
                        Label("Open Health app", systemImage: "arrow.up.forward.app")
                    }
                } header: {
                    Text("HEALTH")
                        .font(.pixel(10))
                        .foregroundStyle(BRTheme.textMuted)
                }
                .listRowBackground(BRTheme.card)

                notificationsSection

                Section {
                    LabeledContent("Version", value: version)
                    Link(destination: URL(string: "https://xcaraballo14.github.io/Apple-Watch---Calories-Burn/privacy-policy.html")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://xcaraballo14.github.io/Apple-Watch---Calories-Burn/")!) {
                        Label("Support", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("ABOUT")
                        .font(.pixel(10))
                        .foregroundStyle(BRTheme.textMuted)
                } footer: {
                    Text("Earn your treats. 🔥")
                        .font(.footnote)
                        .foregroundStyle(BRTheme.textMuted)
                }
                .listRowBackground(BRTheme.card)
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 8, for: .scrollContent)
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: achievementsBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements")
                    Text("Badges, level-ups, and new records — even with the app closed.")
                        .font(.caption)
                        .foregroundStyle(BRTheme.textMuted)
                }
            }
            .tint(BRTheme.neonGreen)

            Toggle(isOn: streakBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak reminder")
                    Text("One gentle nudge, only on days your streak would end.")
                        .font(.caption)
                        .foregroundStyle(BRTheme.textMuted)
                }
            }
            .tint(BRTheme.neonGreen)

            Toggle(isOn: challengeBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Challenge reminder")
                    Text("A heads-up late in the week when you're close to the weekly challenge.")
                        .font(.caption)
                        .foregroundStyle(BRTheme.textMuted)
                }
            }
            .tint(BRTheme.neonGreen)

            if notifications.streakReminderEnabled || notifications.challengeReminderEnabled {
                DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
            }

            if notifications.showDeniedHint {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash")
                            .foregroundStyle(BRTheme.orangeFG)
                            .accessibilityHidden(true)
                        Text("Notifications are off for BurnReward in iOS Settings. Tap to turn them on.")
                            .font(.footnote)
                            .foregroundStyle(BRTheme.orangeFG)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        } header: {
            Text("NOTIFICATIONS")
                .font(.pixel(10))
                .foregroundStyle(BRTheme.textMuted)
        } footer: {
            Text("Reminders are scheduled on your iPhone. Nothing leaves your device.")
                .font(.footnote)
                .foregroundStyle(BRTheme.textMuted)
        }
        .listRowBackground(BRTheme.card)
    }

    private var achievementsBinding: Binding<Bool> {
        Binding {
            notifications.achievementsEnabled
        } set: { on in
            notifications.achievementsEnabled = on
            if on { Task { await notifications.ensureAuthorization() } }
        }
    }

    private var streakBinding: Binding<Bool> {
        Binding {
            notifications.streakReminderEnabled
        } set: { on in
            notifications.streakReminderEnabled = on
            if on { Task { await notifications.ensureAuthorization() } }
            model.rescheduleStreakReminder()
        }
    }

    private var challengeBinding: Binding<Bool> {
        Binding {
            notifications.challengeReminderEnabled
        } set: { on in
            notifications.challengeReminderEnabled = on
            if on { Task { await notifications.ensureAuthorization() } }
            model.rescheduleChallengeReminder()
        }
    }
}

#Preview("Settings") {
    SettingsView(model: DashboardViewModel(sample: true))
}
