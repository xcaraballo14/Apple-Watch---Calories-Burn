import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var model: DashboardViewModel
    /// Present when signed into the guild — enables account deletion.
    var guild: GuildManager? = nil
    @ObservedObject private var notifications = NotificationService.shared
    @ObservedObject private var board = LeaderboardManager.shared
    @ObservedObject private var characterShare = CharacterShare.shared
    @State private var confirmingDelete = false
    @State private var isDeleting = false
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
            .confirmationDialog("Delete your account?",
                                isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) {
                    guard let guild else { return }
                    isDeleting = true
                    Task {
                        let done = await guild.deleteAccount()
                        isDeleting = false
                        if done { dismiss() }   // back to the app in solo mode
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and everything you've shared. It can't be undone. Your on-device quests and Apple Health data stay put.")
            }
            .alert("Account", isPresented: Binding(
                get: { guild?.errorMessage != nil },
                set: { if !$0 { guild?.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { guild?.errorMessage = nil }
            } message: {
                Text(guild?.errorMessage ?? "")
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

                // Only meaningful with a guild account — hidden otherwise so
                // the sheet stays honest for players who never signed in.
                if SupabaseAPI.shared.currentUserID != nil {
                    Section {
                        Toggle(isOn: Binding(get: { characterShare.isSharing },
                                             set: { characterShare.isSharing = $0 })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Show my character to my party", systemImage: "person.text.rectangle")
                                Text("Your party sees your character sheet — class, stats, records, trophies. Turn off to keep it private (they'll see only your name, level, and trophies).")
                                    .font(.caption)
                                    .foregroundStyle(BRTheme.textMuted)
                            }
                        }
                        Toggle(isOn: challengeParticipationBinding) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Join the weekly challenge", systemImage: "flag.checkered")
                                Text("Post your weekly XP to your party's board. Leaving removes it.")
                                    .font(.caption)
                                    .foregroundStyle(BRTheme.textMuted)
                            }
                        }
                        NavigationLink {
                            BlockedPlayersView()
                        } label: {
                            Label("Blocked players", systemImage: "hand.raised")
                        }
                    } header: {
                        Text("GUILD")
                            .font(.pixel(10))
                            .foregroundStyle(BRTheme.textMuted)
                    }
                    .listRowBackground(BRTheme.card)

                    // Account deletion (Apple 5.1.1(v)). Own section so it reads
                    // as the serious, separate action it is.
                    Section {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            HStack {
                                Label("Delete account", systemImage: "trash")
                                    .foregroundStyle(BRTheme.alertRed)
                                Spacer()
                                if isDeleting { ProgressView() }
                            }
                        }
                        .disabled(isDeleting)
                    } header: {
                        Text("ACCOUNT")
                            .font(.pixel(10))
                            .foregroundStyle(BRTheme.textMuted)
                    } footer: {
                        Text("Permanently deletes your account and everything you've shared — profile, character, posts, photos, reactions, and scores. Your on-device quests and Apple Health data are not affected. This can't be undone.")
                            .font(.caption)
                            .foregroundStyle(BRTheme.textMuted)
                    }
                    .listRowBackground(BRTheme.card)
                }

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

    /// Opt into the ⚔️ WEEKLY CHALLENGE board (P3). Off posts nothing; on
    /// publishes this week's XP and keeps it current. Reads through `board` so
    /// the toggle reflects the real state after the async work lands.
    private var challengeParticipationBinding: Binding<Bool> {
        Binding {
            board.isParticipating
        } set: { on in
            Task { await board.setParticipating(on, myWeeklyXP: model.weeklyXP) }
        }
    }
}

#Preview("Settings") {
    SettingsView(model: DashboardViewModel(sample: true))
}
