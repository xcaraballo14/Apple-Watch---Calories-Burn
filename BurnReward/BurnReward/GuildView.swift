import AuthenticationServices
import SwiftUI

/// The two faces of a signed-in guild.
enum GuildSegment: CaseIterable {
    case feed, party

    var label: String {
        switch self {
        case .feed:  "FEED"
        case .party: "PARTY"
        }
    }

    var spokenLabel: String {
        switch self {
        case .feed:  "Feed — what your party has been burning"
        case .party: "Party — your friends and requests"
        }
    }
}

/// The social pillar: sign in, claim a name, run your party. Everything here
/// is opt-in and account-based — the core loop never needs it.
struct GuildView: View {
    @ObservedObject var guild: GuildManager
    /// Local game identity, pushed up so friends see it current.
    let level: Int
    let rankTitle: String
    let badgeIDs: [String]

    @State private var showAddFriend = false
    @State private var claimText = ""
    /// The guild home has two faces: what your party did (FEED) and who your
    /// party is (PARTY). Feed leads — it's the reason people open the tab.
    @State private var segment: GuildSegment = .feed
    @ObservedObject private var feed = FeedManager.shared
    @State private var showPostSheet = false

    init(guild: GuildManager, level: Int, rankTitle: String, badgeIDs: [String]) {
        self.guild = guild
        self.level = level
        self.rankTitle = rankTitle
        self.badgeIDs = badgeIDs
        if ProcessInfo.processInfo.arguments.contains("-BRDemoAddFriend") {
            _showAddFriend = State(initialValue: true)
        }
        if ProcessInfo.processInfo.arguments.contains("-BRDemoGuildClaim") {
            _claimText = State(initialValue: "xavier_pr")
        }
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-BRDemoParty") {
            _segment = State(initialValue: .party)
        }
        if arguments.contains("-BRDemoPostSheet") || arguments.contains("-BRDemoPostPhotos") {
            _showPostSheet = State(initialValue: true)
        }
    }

    /// The splash carries its own big wordmark — no header on top of it.
    private var showsHeader: Bool { guild.phase != .signedOut }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showsHeader {
                    BRTabHeader("GUILD") { }
                }
                ZStack {
                    BRTheme.bg.ignoresSafeArea()
                    switch guild.phase {
                    case .signedOut:     signedOutView
                    case .needsUsername: claimUsernameView
                    case .ready:         guildHome
                    }
                }
            }
            .background(BRTheme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SocialProfile.self) { profile in
                FriendProfileView(profile: profile, guild: guild)
            }
            .sheet(isPresented: $showAddFriend) { AddFriendSheet(guild: guild) }
            .sheet(isPresented: $showPostSheet) {
                // Mockup surface only — the real entry point is the quest
                // receipt / badge unlock share sheet (P0's ShareCardSheet).
                PostToGuildSheet(headline: "EARNED CHOCOLATE MILKSHAKE",
                                 emoji: "🥤",
                                 detail: "412 cal · 43:00 · +508 XP",
                                 onPost: { _, _ in true })   // mockup surface only
            }
            .alert("Guild", isPresented: Binding(
                get: { guild.errorMessage != nil },
                set: { if !$0 { guild.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { guild.errorMessage = nil }
            } message: {
                Text(guild.errorMessage ?? "")
            }
            .alert("Feed", isPresented: Binding(
                get: { feed.errorMessage != nil },
                set: { if !$0 { feed.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { feed.errorMessage = nil }
            } message: {
                Text(feed.errorMessage ?? "")
            }
            .task {
                await guild.restore()
                await guild.syncProfile(level: level, title: rankTitle, badgeIDs: badgeIDs)
                await feed.refresh()
            }
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

                appleSignInButton
                    .padding(.top, 4)

                Text("One tap. Apple hides your email. No password.")
                    .font(.caption)
                    .foregroundStyle(BRTheme.textMuted)
            }
            .padding(16)
        }
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            guild.prepareAppleRequest(request)
        } onCompletion: { result in
            Task { await guild.handleAppleCompletion(result) }
        }
        .signInWithAppleButtonStyle(.white)
        // Apple's button enforces width ≤ 375 internally; matching it here
        // keeps Auto Layout from logging broken-constraint noise.
        .frame(maxWidth: 375)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .disabled(guild.isWorking)
        .opacity(guild.isWorking ? 0.6 : 1)
        .accessibilityLabel("Sign in with Apple")
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

    private var claimProblem: String? {
        claimText.isEmpty ? nil : GuildManager.validate(username: claimText)
    }

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
                    .submitLabel(.done)
                    .onSubmit { submitClaim() }
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BRTheme.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(claimProblem == nil ? BRTheme.greenFG : BRTheme.alertRed,
                                                  lineWidth: 1.5)
                            )
                    )
                    .padding(.horizontal, 40)
                    .padding(.top, 22)
                    .accessibilityLabel("Choose your username")

                Text(claimProblem ?? "3–16 characters · a–z 0–9 _")
                    .font(.pixel(7))
                    .foregroundStyle(claimProblem == nil ? BRTheme.textMuted : BRTheme.alertRed)
                    .padding(.top, 10)

                Button(action: submitClaim) {
                    Text(guild.isWorking ? "CLAIMING…" : "CLAIM IT")
                        .font(.pixel(11))
                        .foregroundStyle(BRTheme.onNeonGreen)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(canClaim ? BRTheme.neonGreen : BRTheme.track)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canClaim)
                .padding(.horizontal, 40)
                .padding(.top, 22)
                .accessibilityLabel("Claim this username")
            }
            .padding(.bottom, 24)
        }
    }

    private var canClaim: Bool {
        !guild.isWorking && !claimText.isEmpty && claimProblem == nil
    }

    private func submitClaim() {
        guard canClaim else { return }
        Task {
            await guild.claim(username: claimText, level: level,
                              title: rankTitle, badgeIDs: badgeIDs)
        }
    }

    // MARK: - Guild home (signed in)

    /// Your card and the FEED/PARTY switch stay pinned; only the list below
    /// scrolls, so identity and navigation never scroll away.
    private var guildHome: some View {
        VStack(spacing: 12) {
            if let me = guild.me {
                guildCard(me: me, friendCount: guild.friends.count)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            segmentPicker
                .padding(.horizontal, 16)
            switch segment {
            case .feed:
                FeedView(events: feed.events,
                         hasFriends: !guild.friends.isEmpty,
                         onReact: { event, reaction in
                             Task { await feed.react(event, reaction) }
                         },
                         onRecruit: { showAddFriend = true })
                .refreshable { await feed.refresh() }
            case .party:
                partyList
            }
        }
    }

    private var segmentPicker: some View {
        HStack(spacing: 6) {
            ForEach(GuildSegment.allCases, id: \.self) { option in
                let selected = segment == option
                Button {
                    segment = option
                } label: {
                    HStack(spacing: 6) {
                        Text(option.label)
                            .font(.pixel(9))
                        // Pending requests are the one thing worth a nudge.
                        if option == .party, !guild.incoming.isEmpty {
                            Text("\(guild.incoming.count)")
                                .font(.pixel(7))
                                .foregroundStyle(BRTheme.onNeonGreen)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(BRTheme.gold))
                        }
                    }
                    .foregroundStyle(selected ? BRTheme.onNeonGreen : BRTheme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selected ? BRTheme.neonGreen : BRTheme.track)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.spokenLabel)
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private var partyList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !guild.incoming.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        PixelSectionLabel(text: "KNOCKING AT THE GATE")
                        ForEach(guild.incoming) { requester in
                            requestRow(requester)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        PixelSectionLabel(text: "PARTY MEMBERS")
                        Spacer()
                        Text("\(guild.friends.count)")
                            .font(.pixel(10))
                            .foregroundStyle(BRTheme.textMuted)
                    }
                    if guild.friends.isEmpty {
                        Text("No party members yet. Every guild starts with one brave recruit.")
                            .font(.footnote)
                            .foregroundStyle(BRTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BRTheme.card))
                    } else {
                        ForEach(guild.friends) { friend in
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
        .refreshable { await guild.loadGuild() }
    }

    private func guildCard(me: SocialProfile, friendCount: Int) -> some View {
        HStack(spacing: 12) {
            GuildAvatar(profile: me, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("@\(me.username)")
                    .font(.body.weight(.semibold))
                    // The card is always the dark island — light text in BOTH
                    // themes, or the name vanishes in light mode.
                    .foregroundStyle(.white)
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
                Task { await guild.accept(requester) }
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
                Task { await guild.decline(requester) }
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
}

/// A party member's sheet: their identity and the trophies they've earned.
/// Everything shown is what they chose to share — no health data exists here.
struct FriendProfileView: View {
    let profile: SocialProfile
    @ObservedObject var guild: GuildManager
    @State private var confirmingRemove = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BRTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    GuildAvatar(profile: profile, size: 96)
                        .padding(.top, 8)
                    Text("@\(profile.username)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BRTheme.textPrimary)
                    Text("LVL \(profile.level) · \(profile.title)")
                        .font(.pixel(10))
                        .foregroundStyle(BRTheme.yellowFG)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PixelSectionLabel(text: "TROPHIES")
                            Spacer()
                            Text("\(profile.badgeIDs.count) earned")
                                .font(.pixel(8))
                                .foregroundStyle(BRTheme.textMuted)
                        }
                        if profile.badgeIDs.isEmpty {
                            Text("No trophies yet — early days.")
                                .font(.footnote)
                                .foregroundStyle(BRTheme.textMuted)
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                                     count: 4), spacing: 14) {
                                ForEach(profile.badgeIDs, id: \.self) { id in
                                    if let art = UIImage(named: "badge_\(id)") {
                                        Image(uiImage: art)
                                            .resizable()
                                            .interpolation(.none)
                                            .scaledToFit()
                                            .frame(height: 46)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BRTheme.card))

                    Button {
                        confirmingRemove = true
                    } label: {
                        Text("REMOVE FROM PARTY")
                            .font(.pixel(8))
                            .foregroundStyle(BRTheme.alertRed)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BRTheme.card))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove @\(profile.username) from your party?",
                            isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                Task {
                    await guild.remove(profile)
                    dismiss()
                }
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("You can always recruit them again.")
        }
    }
}

/// Pixel avatar placeholder: initial-on-dark circle until Xavier's avatar art
/// set lands (photo avatars come with the SCA gate at P1.5).
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

/// The recruitment pitch — used by the one-time launch prompt.
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
    @ObservedObject var guild: GuildManager
    @Environment(\.dismiss) private var dismiss
    let onJoin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            GuildPitch()

            SignInWithAppleButton(.signIn) { request in
                guild.prepareAppleRequest(request)
            } onCompletion: { result in
                Task {
                    await guild.handleAppleCompletion(result)
                    if guild.phase != .signedOut {
                        dismiss()
                        onJoin()
                    }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(maxWidth: 375)
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

/// Recruit by exact username.
struct AddFriendSheet: View {
    @ObservedObject var guild: GuildManager
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var found: SocialProfile?
    @State private var searched = false

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
                .submitLabel(.search)
                .onSubmit(runSearch)
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

            if let found {
                resultRow(found)
            } else if searched && !guild.isWorking {
                Text("No adventurer goes by @\(query.lowercased()).")
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Ask your friend for their guild name — exact matches only.")
                    .font(.caption)
                    .foregroundStyle(BRTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(BRTheme.bg)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    private func resultRow(_ profile: SocialProfile) -> some View {
        let alreadyFriend = guild.friends.contains { $0.id == profile.id }
        let requested = guild.outgoingIDs.contains(profile.id)
        let isMe = profile.id == guild.me?.id
        return HStack(spacing: 12) {
            GuildAvatar(profile: profile, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(profile.username)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BRTheme.textPrimary)
                Text("LVL \(profile.level) · \(profile.title)")
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.textMuted)
            }
            Spacer()
            if isMe {
                Text("THAT'S YOU")
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.textMuted)
            } else if alreadyFriend {
                Text("IN PARTY")
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.greenFG)
            } else if requested {
                Text("ASKED")
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.textMuted)
            } else {
                Button {
                    Task { await guild.sendRequest(to: profile) }
                } label: {
                    Text("RECRUIT")
                        .font(.pixel(8))
                        .foregroundStyle(BRTheme.onNeonGreen)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 34)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(BRTheme.neonGreen))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send a request to \(profile.username)")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BRTheme.card))
    }

    private func runSearch() {
        Task {
            searched = true
            found = await guild.search(username: query)
        }
    }
}
