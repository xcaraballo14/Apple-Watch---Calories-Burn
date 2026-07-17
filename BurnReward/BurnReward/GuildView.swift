import AuthenticationServices
import SwiftUI

/// UI state for the GUILD tab. Real transitions come from SupabaseAPI at
/// wiring time; the demo flags below seed each state so the simulator can
/// screenshot every screen without tap automation.
enum GuildState {
    case signedOut
    case needsUsername
    case ready(profile: SocialProfile, friends: [SocialProfile], incoming: [SocialProfile])
}

/// The social pillar: sign in, claim a name, run your party. Everything here
/// is opt-in and account-based — the core loop never needs it.
struct GuildView: View {
    @State private var state: GuildState
    @State private var showAddFriend = false
    @State private var claimText = ""

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-BRDemoGuild") || arguments.contains("-BRDemoAddFriend") {
            _state = State(initialValue: .ready(
                profile: Self.demoMe,
                friends: Self.demoFriends,
                incoming: Self.demoIncoming
            ))
        } else if arguments.contains("-BRDemoGuildClaim") {
            _state = State(initialValue: .needsUsername)
            _claimText = State(initialValue: "xavier_pr")
        } else {
            _state = State(initialValue: .signedOut)
        }
        // `-BRDemoAddFriend` presents the recruit sheet at launch (the
        // simulator has no tap automation).
        if arguments.contains("-BRDemoAddFriend") {
            _showAddFriend = State(initialValue: true)
        }
    }

    /// The splash carries its own big wordmark — no header on top of it.
    private var showsHeader: Bool {
        if case .signedOut = state { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showsHeader {
                    BRTabHeader("GUILD") { }
                }
                ZStack {
                    BRTheme.bg.ignoresSafeArea()
                    switch state {
                    case .signedOut:      signedOutView
                    case .needsUsername:  claimUsernameView
                    case .ready(let me, let friends, let incoming):
                        guildHome(me: me, friends: friends, incoming: incoming)
                    }
                }
            }
            .background(BRTheme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddFriend) { AddFriendSheet() }
        }
    }

    // MARK: - Signed out (Xavier's splash design, 2026-07-16)

    private var signedOutView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero — castle + wordmark
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        Text("✦")
                            .font(.pixel(12))
                            .foregroundStyle(BRTheme.yellowFG)
                        Text("GUILD")
                            .font(.pixel(34))
                            .foregroundStyle(BRTheme.greenFG)
                            .shadow(color: BRTheme.greenFG.opacity(0.55), radius: 10)
                        Text("✦")
                            .font(.pixel(12))
                            .foregroundStyle(BRTheme.yellowFG)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Guild")
                    .accessibilityAddTraits(.isHeader)
                    Text("ADVENTURE TOGETHER. GET STRONGER.")
                        .font(.pixel(8))
                        .foregroundStyle(BRTheme.textMuted)
                    if let castle = UIImage(named: "guild_castle") {
                        Image(uiImage: castle)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding(.top, 6)
                            .accessibilityHidden(true)
                    }
                }

                // Join panel — the three promises, in Xavier's art
                guildPanel {
                    VStack(spacing: 4) {
                        Text("JOIN THE GUILD")
                            .font(.pixel(14))
                            .foregroundStyle(BRTheme.greenFG)
                        Text("Level up together. Conquer more.")
                            .font(.footnote)
                            .foregroundStyle(BRTheme.textMuted)
                        HStack(alignment: .top, spacing: 10) {
                            featureCard("guild_sword", "SHARE QUESTS",
                                        "Share your quests and trophies.")
                            featureCard("guild_group", "BUILD YOUR PARTY",
                                        "Recruit friends to your party.")
                            featureCard("guild_big_trophy", "CLIMB THE BOARDS",
                                        "Compete on weekly leaderboards.")
                        }
                        .padding(.top, 12)
                    }
                }

                // Preview panel — sample board, honestly labeled
                guildPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("WHAT AWAITS INSIDE")
                                .font(.pixel(10))
                                .foregroundStyle(BRTheme.greenFG)
                            Spacer()
                            Text("PREVIEW")
                                .font(.pixel(7))
                                .foregroundStyle(BRTheme.textMuted)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 7)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(BRTheme.weekBorder, lineWidth: 1)
                                )
                        }
                        previewRow(rank: 1, art: "gold_trophy",
                                   name: "Iron Warriors", xp: "89,450 XP")
                        previewRow(rank: 2, art: "silver_trophy",
                                   name: "Cardio Kings", xp: "76,200 XP")
                        previewRow(rank: 3, art: "copper_trophy",
                                   name: "Pixel Pioneers", xp: "64,310 XP")
                        Text("Sample board — your party's real one starts when you join.")
                            .font(.caption2)
                            .foregroundStyle(BRTheme.textMuted)
                    }
                }

                // Privacy panel
                guildPanel {
                    HStack(spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(BRTheme.textMuted)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("YOUR HEALTH. YOUR DATA.")
                                .font(.pixel(9))
                                .foregroundStyle(BRTheme.greenFG)
                            Text("Your health data never leaves your device.\nYou choose exactly what to share.")
                                .font(.caption)
                                .foregroundStyle(BRTheme.textMuted)
                        }
                        Spacer(minLength: 0)
                    }
                }

                SignInWithAppleButton(.signIn) { _ in
                    // Wiring round: configure nonce + requested scopes.
                } onCompletion: { _ in
                    // Wiring round: SupabaseAPI.signInWithApple.
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .padding(.top, 4)
                .accessibilityLabel("Sign in with Apple")

                Text("One tap. Apple hides your email. No password.")
                    .font(.caption)
                    .foregroundStyle(BRTheme.textMuted)
            }
            .padding(16)
        }
    }

    private func guildPanel(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BRTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(BRTheme.weekBorder, lineWidth: 1)
                    )
            )
    }

    private func featureCard(_ asset: String, _ title: String, _ caption: String) -> some View {
        VStack(spacing: 8) {
            Group {
                if let art = UIImage(named: asset) {
                    Image(uiImage: art)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(6)
                } else {
                    Color.clear
                }
            }
            .frame(height: 82)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(BRTheme.darkIsland)
            )
            .accessibilityHidden(true)

            Text(title)
                .font(.pixel(7))
                .foregroundStyle(BRTheme.greenFG)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(BRTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func previewRow(rank: Int, art: String, name: String, xp: String) -> some View {
        HStack(spacing: 10) {
            Group {
                if let trophy = UIImage(named: art) {
                    Image(uiImage: trophy)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(width: 26, height: 26)
            .accessibilityHidden(true)
            Text("\(rank)")
                .font(.pixel(10))
                .foregroundStyle(BRTheme.yellowFG)
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BRTheme.textPrimary)
            Spacer()
            Text(xp)
                .font(.pixel(9))
                .foregroundStyle(BRTheme.textMuted)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Username claim

    private var claimUsernameView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("⚔️")
                    .font(.system(size: 52))
                    .padding(.top, 40)
                    .accessibilityHidden(true)
                Text("CLAIM YOUR NAME")
                    .font(.pixel(15))
                    .foregroundStyle(BRTheme.greenFG)
                    .padding(.top, 18)
                Text("This is how your party finds you. Lowercase letters, numbers, and underscores.")
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)

                TextField("username", text: $claimText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BRTheme.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(BRTheme.greenFG, lineWidth: 1.5)
                            )
                    )
                    .padding(.horizontal, 40)
                    .padding(.top, 22)
                    .accessibilityLabel("Choose your username")

                Text("3–16 characters · a–z 0–9 _")
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.textMuted)
                    .padding(.top, 10)

                Button {
                    // Wiring round: insert profile row (username availability
                    // enforced by the unique index; 409 → taken).
                } label: {
                    Text("CLAIM IT")
                        .font(.pixel(11))
                        .foregroundStyle(BRTheme.onNeonGreen)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(BRTheme.neonGreen)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.top, 22)
                .accessibilityLabel("Claim this username")
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Guild home (signed in)

    private func guildHome(me: SocialProfile, friends: [SocialProfile], incoming: [SocialProfile]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                guildCard(me: me, friendCount: friends.count)

                if !incoming.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        PixelSectionLabel(text: "KNOCKING AT THE GATE")
                        ForEach(incoming) { requester in
                            requestRow(requester)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        PixelSectionLabel(text: "PARTY MEMBERS")
                        Spacer()
                        Text("\(friends.count)")
                            .font(.pixel(10))
                            .foregroundStyle(BRTheme.textMuted)
                    }
                    if friends.isEmpty {
                        Text("No party members yet. Every guild starts with one brave recruit.")
                            .font(.footnote)
                            .foregroundStyle(BRTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BRTheme.card))
                    } else {
                        ForEach(friends) { friend in
                            friendRow(friend)
                        }
                    }
                }

                Button {
                    showAddFriend = true
                } label: {
                    Label("RECRUIT A FRIEND", systemImage: "person.badge.plus")
                        .font(.pixel(10))
                        .foregroundStyle(BRTheme.onNeonGreen)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(BRTheme.neonGreen)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Recruit a friend by username")
            }
            .padding(16)
        }
    }

    private func guildCard(me: SocialProfile, friendCount: Int) -> some View {
        HStack(spacing: 12) {
            GuildAvatar(profile: me, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("@\(me.username)")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BRTheme.textPrimary)
                Text("LVL \(me.level) · \(me.title)")
                    .font(.pixel(8))
                    .foregroundStyle(BRTheme.yellowFG)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(friendCount)")
                    .font(.pixel(14))
                    .foregroundStyle(BRTheme.greenFG)
                Text("PARTY")
                    .font(.pixel(6))
                    .foregroundStyle(BRTheme.textMuted)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BRTheme.darkIsland)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(BRTheme.gold, lineWidth: 1.5)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your guild card: \(me.username), level \(me.level) \(me.title), \(friendCount) party members.")
    }

    private func friendRow(_ friend: SocialProfile) -> some View {
        NavigationLink(value: friend) {
            HStack(spacing: 12) {
                GuildAvatar(profile: friend, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(friend.username)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(BRTheme.textPrimary)
                    Text("LVL \(friend.level) · \(friend.title)")
                        .font(.pixel(7))
                        .foregroundStyle(BRTheme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BRTheme.textMuted)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BRTheme.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(friend.username), level \(friend.level) \(friend.title). Opens their profile.")
    }

    private func requestRow(_ requester: SocialProfile) -> some View {
        HStack(spacing: 12) {
            GuildAvatar(profile: requester, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(requester.username)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BRTheme.textPrimary)
                Text("LVL \(requester.level) · \(requester.title)")
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.textMuted)
            }
            Spacer()
            Button {
                // Wiring round: accept (status → accepted).
            } label: {
                Text("ACCEPT")
                    .font(.pixel(8))
                    .foregroundStyle(BRTheme.onNeonGreen)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(BRTheme.neonGreen))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Accept \(requester.username)")
            Button {
                // Wiring round: decline (delete row).
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BRTheme.textMuted)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(BRTheme.track))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decline \(requester.username)")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BRTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(BRTheme.gold.opacity(0.6), lineWidth: 1)
                )
        )
    }

    // MARK: - Demo data (screenshots only; ProcessInfo-gated)

    private static let demoMe = SocialProfile(
        id: UUID(), username: "xavier_pr", avatarKind: "pixel", avatarRef: "flame",
        level: 6, title: "SNACK SLAYER",
        badgeIDs: ["first_burn", "decade", "spark", "inferno"]
    )
    private static let demoFriends = [
        SocialProfile(id: UUID(), username: "mika_runs", avatarKind: "pixel", avatarRef: "bolt",
                      level: 8, title: "DUNGEON DINER", badgeIDs: ["first_burn", "trailblazer"]),
        SocialProfile(id: UUID(), username: "carlos_lifts", avatarKind: "pixel", avatarRef: "sword",
                      level: 4, title: "TREAT APPRENTICE", badgeIDs: ["first_burn"]),
        SocialProfile(id: UUID(), username: "ana_walks", avatarKind: "pixel", avatarRef: "boot",
                      level: 11, title: "FEAST PHANTOM", badgeIDs: ["first_burn", "legend"]),
    ]
    private static let demoIncoming = [
        SocialProfile(id: UUID(), username: "pedro_bikes", avatarKind: "pixel", avatarRef: "wheel",
                      level: 3, title: "SNACK ROOKIE", badgeIDs: []),
    ]
}

/// Pixel avatar placeholder: initial-on-dark circle until Xavier's avatar art
/// set lands (photo avatars come with the SCA gate at wiring time).
struct GuildAvatar: View {
    let profile: SocialProfile
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(BRTheme.tintGreen)
                .overlay(Circle().strokeBorder(BRTheme.greenFG, lineWidth: 1.5))
            Text(String(profile.username.prefix(1)).uppercased())
                .font(.pixel(size * 0.34))
                .foregroundStyle(BRTheme.greenFG)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The recruitment pitch — shared by the launch prompt and the signed-out tab.
struct GuildPitch: View {
    var body: some View {
        VStack(spacing: 0) {
            if let castle = UIImage(named: "guild_castle") {
                Image(uiImage: castle)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(height: 132)
                    .accessibilityHidden(true)
            }
            Text("THE GUILD IS OPEN")
                .font(.pixel(16))
                .foregroundStyle(BRTheme.greenFG)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 12) {
                pitchRow("🔥", "Share your quests and trophies")
                pitchRow("⚔️", "Recruit friends to your party")
                pitchRow("🏆", "Weekly XP leaderboards")
            }
            .padding(.top, 20)

            Text("Your health data never leaves your device.\nYou choose exactly what to share.")
                .font(.caption)
                .foregroundStyle(BRTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
        }
    }

    private func pitchRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text(emoji).font(.system(size: 18))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(BRTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One-time launch prompt (Xavier's ruling: prompt at launch, skippable).
struct GuildSignInPrompt: View {
    @Environment(\.dismiss) private var dismiss
    let onJoin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            GuildPitch()

            SignInWithAppleButton(.signIn) { _ in
                // Wiring round: nonce + scopes.
            } onCompletion: { _ in
                // Wiring round: SupabaseAPI.signInWithApple → onJoin().
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .accessibilityLabel("Sign in with Apple")

            Button {
                dismiss()
            } label: {
                Text("NOT NOW")
                    .font(.pixel(9))
                    .foregroundStyle(BRTheme.textMuted)
                    .frame(minHeight: 40)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .accessibilityLabel("Not now")
            .accessibilityHint("You can join anytime from the Guild tab.")

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .background(BRTheme.bg)
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.visible)
    }
}

/// Recruit-by-username search (wired to profile select at wiring time).
struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("RECRUIT A FRIEND")
                    .font(.pixel(12))
                    .foregroundStyle(BRTheme.greenFG)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Done") { dismiss() }
                    .foregroundStyle(BRTheme.blueFG)
            }
            .padding(.top, 18)

            TextField("Search by username", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BRTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(BRTheme.divider, lineWidth: 1)
                        )
                )
                .accessibilityLabel("Search by username")

            Text("Ask your friend for their guild name — exact matches only.")
                .font(.caption)
                .foregroundStyle(BRTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(BRTheme.bg)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Guild — home") {
    GuildView()
}
