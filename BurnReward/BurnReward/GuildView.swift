import AuthenticationServices
import SwiftUI

/// The three faces of a signed-in guild.
enum GuildSegment: CaseIterable {
    case feed, party, arena

    var label: String {
        switch self {
        case .feed:  "FEED"
        case .party: "PARTY"
        case .arena: "ARENA"
        }
    }

    var spokenLabel: String {
        switch self {
        case .feed:  "Feed — what your party has been burning"
        case .party: "Party — your friends and requests"
        case .arena: "Arena — this week's XP challenge"
        }
    }
}

/// The social pillar: sign in, claim a name, run your party. Everything here
/// is opt-in and account-based — the core loop never needs it.
struct GuildView: View {
    @ObservedObject var guild: GuildManager
    @ObservedObject private var board = LeaderboardManager.shared
    /// Local game identity, pushed up so friends see it current.
    let level: Int
    let rankTitle: String
    let badgeIDs: [String]
    /// This week's XP, derived on-device — the number the ARENA posts.
    let weeklyXP: Int

    @State private var showAddFriend = false
    @State private var claimText = ""
    /// The guild home has two faces: what your party did (FEED) and who your
    /// party is (PARTY). Feed leads — it's the reason people open the tab.
    @State private var segment: GuildSegment = .feed
    @ObservedObject private var feed = FeedManager.shared
    @State private var showPostSheet = false
    // P4a mockup state — the ⋯ menu's three destinations. Actions are stubs
    // until the design is locked; then they wire to reports/blocks/delete.
    @State private var reportingEvent: FeedEvent?
    @State private var blockingEvent: FeedEvent?
    @State private var takedownEvent: FeedEvent?
    /// `-BRDemoMemberSheet`: the member profile is normally push-only (tap a
    /// party row), which screenshots can't reach — this presents it directly.
    @State private var demoMemberSheet = false
    /// A feed author whose character sheet is being opened (tap on a card's
    /// identity block).
    @State private var openProfile: SocialProfile?

    init(guild: GuildManager, level: Int, rankTitle: String, badgeIDs: [String],
         weeklyXP: Int) {
        self.guild = guild
        self.level = level
        self.rankTitle = rankTitle
        self.badgeIDs = badgeIDs
        self.weeklyXP = weeklyXP
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
        // Screenshot flags for the P4a mockup round.
        if arguments.contains("-BRDemoReportSheet") {
            _reportingEvent = State(initialValue: DemoFeed.events.first)
        }
        if arguments.contains("-BRDemoBlockConfirm") {
            _blockingEvent = State(initialValue: DemoFeed.events.first)
        }
        if arguments.contains("-BRDemoMemberSheet") {
            _demoMemberSheet = State(initialValue: true)
        }
        if arguments.contains("-BRDemoLeaderboard") || arguments.contains("-BRDemoLeaderboardJoin") {
            _segment = State(initialValue: .arena)
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
            // Programmatic push for feed-header taps (the party list uses
            // NavigationLink values; the feed resolves the author first).
            .navigationDestination(item: $openProfile) { profile in
                FriendProfileView(profile: profile, guild: guild)
            }
            .sheet(isPresented: $showAddFriend) { AddFriendSheet(guild: guild) }
            .sheet(isPresented: $demoMemberSheet) {
                NavigationStack {
                    FriendProfileView(
                        profile: SocialProfile(
                            id: UUID(), username: "mika_runs",
                            avatarKind: "photo", avatarRef: nil,
                            level: 8, title: "DUNGEON DINER",
                            badgeIDs: ["first_burn", "long_walk", "marathoner"],
                            character: SharedCharacter(
                                totalXP: 8_450,   // consistent with LVL 8 (real sync derives level from XP)
                                classSpread: [
                                    .init(emoji: "🏃", name: "STRIDER", count: 14, isMain: true),
                                    .init(emoji: "🚴", name: "WAYFARER", count: 8, isMain: false),
                                    .init(emoji: "🏋️", name: "WARDEN", count: 5, isMain: false),
                                ],
                                questsWon: 27, rewardsWon: 19, allTimeCalories: 41_800,
                                dailyStreak: 6, bestStreak: 12, longestSeconds: 4_920,
                                biggestBurn: 612, topHeartRate: 168, mostSteps: 9_240)),
                        guild: guild,
                        avatarPhoto: DemoAvatar.placeholder()
                    )
                }
            }
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

                // Control panel — the honest post-pivot line. Full disclosure
                // comes at the sign-in consent screen; this is the teaser.
                guildPanel {
                    HStack(spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(BRTheme.textMuted)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("YOU'RE IN CONTROL")
                                .font(.pixel(9))
                                .foregroundStyle(BRTheme.greenFG)
                            Text("You choose what your party sees, and can go private anytime. Never sold, never used for ads.")
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
                         onAction: { event, action in
                             switch action {
                             case .takeDown: takedownEvent = event
                             case .report:   reportingEvent = event
                             case .block:    blockingEvent = event
                             }
                         },
                         onOpenProfile: { event in
                             // The party list has the live profile (real badge
                             // ids); the event itself is the fallback so the
                             // tap always lands somewhere sensible.
                             openProfile = guild.friends.first { $0.id == event.authorID }
                                 ?? SocialProfile(id: event.authorID,
                                                  username: event.username,
                                                  avatarKind: "pixel", avatarRef: nil,
                                                  level: event.level, title: event.title,
                                                  badgeIDs: [])
                         },
                         onRecruit: { showAddFriend = true })
                .refreshable { await feed.refresh() }
                .sheet(item: $reportingEvent) { event in
                    ReportSheet(subject: "@\(event.username)'s post — \(event.headline)") { reason, note in
                        let failure = await ModerationClient.shared.report(
                            user: event.authorID, event: event.id,
                            reason: reason, note: note
                        )
                        // The sheet's promise: gone from your feed on send.
                        if failure == nil { feed.hideReported(event.id) }
                        return failure
                    }
                }
                .confirmationDialog(
                    "Block @\(blockingEvent?.username ?? "")?",
                    isPresented: Binding(get: { blockingEvent != nil },
                                         set: { if !$0 { blockingEvent = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("Block player", role: .destructive) {
                        guard let event = blockingEvent else { return }
                        blockingEvent = nil
                        Task {
                            if let failure = await ModerationClient.shared.block(userID: event.authorID) {
                                guild.errorMessage = failure
                            } else {
                                feed.dropAuthor(event.authorID)
                                await guild.loadGuild()
                                await SocialAlertStore.shared.refresh()
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) { blockingEvent = nil }
                } message: {
                    Text("They leave your party. Their posts vanish for you and yours vanish for them. They aren't told.")
                }
                .confirmationDialog(
                    "Take down this post?",
                    isPresented: Binding(get: { takedownEvent != nil },
                                         set: { if !$0 { takedownEvent = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("Take down", role: .destructive) {
                        guard let event = takedownEvent else { return }
                        takedownEvent = nil
                        Task { await feed.delete(event) }
                    }
                    Button("Keep it", role: .cancel) { takedownEvent = nil }
                } message: {
                    Text("Its photos and reactions go with it. Your party isn't told.")
                }
            case .party:
                partyList
            case .arena:
                LeaderboardView(entries: board.entries,
                                isParticipating: board.isParticipating,
                                resetText: board.resetText,
                                onJoin: {
                                    Task { await board.join(myWeeklyXP: weeklyXP,
                                                            me: guild.me, friends: guild.friends) }
                                },
                                onRecruit: { showAddFriend = true })
                .task { await board.refresh(myWeeklyXP: weeklyXP,
                                            me: guild.me, friends: guild.friends) }
                .refreshable { await board.refresh(myWeeklyXP: weeklyXP,
                                                   me: guild.me, friends: guild.friends) }
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
    /// A loaded photo avatar. Nil today (real loading arrives with the upload
    /// build); the mockup flag injects one so the design is visible.
    var avatarPhoto: UIImage? = nil
    /// The friend's shared character, fetched on appear. The demo injects it via
    /// `profile.character`; real friends load it from `shared_characters`.
    @State private var loadedCharacter: SharedCharacter?
    @State private var confirmingRemove = false
    // P4a mockup state — report/block from the member sheet (App Review wants
    // a path from a profile too, not just from posts). Stubs until locked.
    @State private var reporting = false
    @State private var confirmingBlock = false
    @Environment(\.dismiss) private var dismiss

    /// Demo injects via `profile.character`; real friends load `loadedCharacter`.
    private var character: SharedCharacter? { profile.character ?? loadedCharacter }

    var body: some View {
        ZStack {
            BRTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    identityPlate
                    if let character = character {
                        streakStrip(character)
                        classSpread(character)
                        lifetimeTiles(character)
                        records(character)
                    }
                    trophyCase

                    // Ordered by severity: part ways / flag them / wall them
                    // off. Remove stays friendly; block is the loud one.
                    VStack(spacing: 8) {
                        memberActionRow("REMOVE FROM PARTY", color: BRTheme.alertRed) {
                            confirmingRemove = true
                        }
                        memberActionRow("REPORT PLAYER", color: BRTheme.textMuted) {
                            reporting = true
                        }
                        Button {
                            confirmingBlock = true
                        } label: {
                            Text("BLOCK PLAYER")
                                .font(.pixel(8))
                                .foregroundStyle(BRTheme.alertRed)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(BRTheme.alertRed.opacity(0.10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(BRTheme.alertRed.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Real friends: pull their shared character (nil if private or the
            // schema isn't run yet → the sheet just shows name/level/trophies).
            if profile.character == nil {
                loadedCharacter = await CharacterShare.shared.fetch(userID: profile.id)
            }
        }
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
        .sheet(isPresented: $reporting) {
            ReportSheet(subject: "@\(profile.username)") { reason, note in
                await ModerationClient.shared.report(
                    user: profile.id, event: nil, reason: reason, note: note
                )
            }
        }
        .confirmationDialog("Block @\(profile.username)?",
                            isPresented: $confirmingBlock, titleVisibility: .visible) {
            Button("Block player", role: .destructive) {
                Task {
                    if let failure = await ModerationClient.shared.block(userID: profile.id) {
                        guild.errorMessage = failure
                    } else {
                        FeedManager.shared.dropAuthor(profile.id)
                        await guild.loadGuild()
                        await SocialAlertStore.shared.refresh()
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They leave your party. Their posts vanish for you and yours vanish for them. They aren't told.")
        }
        .alert("Guild", isPresented: Binding(
            get: { guild.errorMessage != nil },
            set: { if !$0 { guild.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { guild.errorMessage = nil }
        } message: {
            Text(guild.errorMessage ?? "")
        }
    }

    // MARK: - Identity plate

    /// Mirrors the player's own CHARACTER identity plate so a friend's sheet
    /// reads as the same kind of screen: avatar, name, title, LVL, and — when
    /// they've synced it — a full XP bar built from their total XP.
    private var identityPlate: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                GuildAvatar(profile: profile, size: 64, photo: avatarPhoto)
                    .overlay(Circle().strokeBorder(BRTheme.gold, lineWidth: 2))
                VStack(alignment: .leading, spacing: 6) {
                    Text("@\(profile.username)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BRTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(profile.title)
                        .font(.pixel(9))
                        .foregroundStyle(BRTheme.greenFG)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 4)
                VStack(spacing: 2) {
                    Text("LVL").font(.pixel(7)).foregroundStyle(BRTheme.mutedOnDark)
                    Text("\(profile.level)").font(.pixel(14)).foregroundStyle(BRTheme.expFill)
                }
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(BRTheme.darkIsland))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(BRTheme.gold, lineWidth: 1))
            }

            if let character = character {
                let progress = LevelEngine.progress(forXP: character.totalXP)
                VStack(spacing: 6) {
                    BRProgressBar(fraction: progress.fraction, fill: BRTheme.xpFill, height: 10)
                    HStack {
                        Text("\(character.totalXP.formatted()) XP")
                            .font(.pixel(8)).foregroundStyle(BRTheme.yellowFG)
                        Spacer()
                        Text("\(progress.xpIntoLevel.formatted()) / \(progress.xpLevelSpan.formatted()) to LVL \(progress.level + 1)")
                            .font(.caption2).foregroundStyle(BRTheme.textMuted)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(character.totalXP) total experience, \(progress.xpIntoLevel) of \(progress.xpLevelSpan) to level \(progress.level + 1)")
            }
        }
        .brCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Character mirror sections
    //
    // A full mirror of the owner's CHARACTER page after the 2026-07-21 privacy
    // pivot — real metrics (calories, HR, steps) included, shared by consent
    // with per-visibility control. The owner's "Show my character" visibility
    // setting decides whether `profile.character` is present at all.

    /// The live daily streak, kept distinct from the all-time best-streak
    /// record below. A day count, not a health metric.
    private func streakStrip(_ character: SharedCharacter) -> some View {
        HStack(spacing: 10) {
            Text("🔥").font(.system(size: 18)).accessibilityHidden(true)
            Text("CURRENT STREAK")
                .font(.pixel(8)).foregroundStyle(BRTheme.textMuted)
            Spacer()
            Text("\(character.dailyStreak) DAY\(character.dailyStreak == 1 ? "" : "S")")
                .font(.pixel(11)).foregroundStyle(BRTheme.orangeFG)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BRTheme.tintOrange)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(BRTheme.orangeFG.opacity(0.3), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current streak: \(character.dailyStreak) days")
    }

    private func classSpread(_ character: SharedCharacter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionLabel(text: "CLASS AFFINITY")
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6),
                               count: max(1, min(character.classSpread.count, 4))),
                spacing: 6
            ) {
                ForEach(character.classSpread, id: \.name) { stat in
                    classTile(stat)
                }
            }
        }
    }

    private func classTile(_ stat: SharedCharacter.ClassStat) -> some View {
        VStack(spacing: 5) {
            Text(stat.emoji).font(.system(size: 18)).accessibilityHidden(true)
            Text("\(stat.count)")
                .font(.pixel(11))
                .foregroundStyle(stat.isMain ? BRTheme.greenFG : BRTheme.textPrimary)
            Text(stat.name)
                .font(.caption2).foregroundStyle(BRTheme.textMuted)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11).padding(.horizontal, 3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BRTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(stat.isMain ? BRTheme.greenFG : BRTheme.cardBorder,
                                  lineWidth: stat.isMain ? 1.5 : 1))
        )
        .overlay(alignment: .top) {
            if stat.isMain {
                Text("MAIN")
                    .font(.pixel(6)).foregroundStyle(BRTheme.onNeonGreen)
                    .padding(.vertical, 2).padding(.horizontal, 5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(BRTheme.neonGreen))
                    .offset(y: -7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.name), \(stat.count) quest\(stat.count == 1 ? "" : "s")\(stat.isMain ? ", their main class" : "")")
    }

    private func lifetimeTiles(_ character: SharedCharacter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionLabel(text: "LIFETIME")
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    lifetimeTile("\(character.questsWon)", "quests won", BRTheme.greenFG, BRTheme.tintGreen)
                    lifetimeTile("\(character.rewardsWon)", "rewards won", BRTheme.blueFG, BRTheme.tintBlue)
                }
                HStack(spacing: 10) {
                    lifetimeTile(BRFormat.compact(character.allTimeCalories), "cal all-time", BRTheme.orangeFG, BRTheme.tintOrange)
                    lifetimeTile(BRFormat.compact(character.totalXP), "total XP", BRTheme.yellowFG, BRTheme.tintYellow)
                }
            }
        }
    }

    private func lifetimeTile(_ value: String, _ label: String,
                              _ color: Color, _ fill: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.pixel(12)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(BRTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(color.opacity(0.35), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    /// The full record set — a mirror of the CHARACTER page, real metrics
    /// included. A record with no data (0) is dropped rather than shown as "—".
    private func records(_ character: SharedCharacter) -> some View {
        let rows: [(String, Color, String, String)?] = [
            character.biggestBurn > 0
                ? ("flame.fill", BRTheme.orangeFG, "Biggest burn", "\(character.biggestBurn) CAL") : nil,
            character.longestSeconds > 0
                ? ("clock", BRTheme.blueFG, "Longest quest", BRFormat.duration(TimeInterval(character.longestSeconds))) : nil,
            character.mostSteps > 0
                ? ("figure.walk", BRTheme.greenFG, "Most steps", character.mostSteps.formatted()) : nil,
            character.topHeartRate > 0
                ? ("heart.fill", BRTheme.alertRed, "Top heart rate", "\(character.topHeartRate) BPM") : nil,
            character.bestStreak > 0
                ? ("calendar", BRTheme.yellowFG, "Best streak", "\(character.bestStreak) DAY\(character.bestStreak == 1 ? "" : "S")") : nil,
        ]
        let records = rows.compactMap { $0 }
        return VStack(alignment: .leading, spacing: 10) {
            PixelSectionLabel(text: "RECORDS")
            VStack(spacing: 0) {
                ForEach(Array(records.enumerated()), id: \.offset) { index, r in
                    recordRow(r.0, r.1, r.2, r.3)
                    if index < records.count - 1 { Divider().background(BRTheme.cardBorder) }
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BRTheme.card))
        }
    }

    private func recordRow(_ icon: String, _ color: Color,
                           _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16)).foregroundStyle(color)
                .frame(width: 26)
            Text(title).font(.subheadline).foregroundStyle(BRTheme.textPrimary)
            Spacer()
            Text(value).font(.pixel(10)).foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: - Trophy case

    private var trophyCase: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PixelSectionLabel(text: "TROPHIES")
                Spacer()
                Text("\(profile.badgeIDs.count) earned")
                    .font(.pixel(8)).foregroundStyle(BRTheme.textMuted)
            }
            if profile.badgeIDs.isEmpty {
                Text("No trophies yet — early days.")
                    .font(.footnote).foregroundStyle(BRTheme.textMuted)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                         count: 4), spacing: 14) {
                    ForEach(profile.badgeIDs, id: \.self) { id in
                        if let art = UIImage(named: "badge_\(id)") {
                            Image(uiImage: art)
                                .resizable().interpolation(.none).scaledToFit()
                                .frame(height: 46)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BRTheme.card))
    }

    private func memberActionRow(_ title: String, color: Color,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.pixel(8))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BRTheme.card))
        }
        .buttonStyle(.plain)
    }
}

/// A stand-in "uploaded selfie" drawn at runtime so the friend-profile mockup
/// shows the photo-avatar vision without shipping a sample face in the binary.
enum DemoAvatar {
    static func placeholder() -> UIImage {
        let size = CGSize(width: 240, height: 240)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor(red: 0.36, green: 0.62, blue: 0.86, alpha: 1).cgColor,
                         UIColor(red: 0.20, green: 0.30, blue: 0.52, alpha: 1).cgColor] as CFArray,
                locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: .zero,
                                  end: CGPoint(x: 0, y: size.height), options: [])
            // A simple head-and-shoulders silhouette so it reads as a portrait.
            UIColor(white: 1, alpha: 0.9).setFill()
            cg.fillEllipse(in: CGRect(x: 88, y: 58, width: 64, height: 64))
            cg.fillEllipse(in: CGRect(x: 56, y: 138, width: 128, height: 130))
        }
    }
}

/// Pixel avatar placeholder: initial-on-dark circle until photo avatars land.
struct GuildAvatar: View {
    let profile: SocialProfile
    let size: CGFloat
    /// A loaded photo avatar, once uploads land. Nil → the initial circle.
    var photo: UIImage? = nil

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .contentShape(Circle())   // clip is drawing-only; bound taps too
            } else {
                Circle()
                    .fill(BRTheme.tintGreen)
                    .overlay(Circle().strokeBorder(BRTheme.greenFG, lineWidth: 1.5))
                Text(String(profile.username.prefix(1)).uppercased())
                    .font(.pixel(size * 0.34))
                    .foregroundStyle(BRTheme.greenFG)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The consent + disclosure gate for going social (pillar 4 of the Strava
/// pivot). Shown when a player enables the guild — signing in with Apple is
/// the consent act, so this screen must plainly disclose, *before* that tap,
/// what the party sees (real metrics included), the controls, and the two hard
/// promises. Replaces the old prompt whose "health data never leaves your
/// device" line the pivot made false.
struct GuildSignInPrompt: View {
    @ObservedObject var guild: GuildManager
    @Environment(\.dismiss) private var dismiss
    let onJoin: () -> Void

    private let policyURL = URL(string: "https://xcaraballo14.github.io/Apple-Watch---Calories-Burn/privacy-policy.html")!

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                disclosureSections
                promise
                actions
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
        }
        .background(BRTheme.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: 10) {
            if let castle = UIImage(named: "guild_castle") {
                Image(uiImage: castle)
                    .resizable().interpolation(.none).scaledToFit()
                    .frame(height: 104)
                    .accessibilityHidden(true)
            }
            Text("JOIN THE GUILD")
                .font(.pixel(16)).foregroundStyle(BRTheme.greenFG)
            Text("Team up, compete, and level up with your party.")
                .font(.subheadline).foregroundStyle(BRTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var disclosureSections: some View {
        VStack(spacing: 14) {
            consentCard(
                title: "WHAT YOUR PARTY SEES",
                tint: BRTheme.blueFG, fill: BRTheme.tintBlue,
                rows: [
                    ("🧙", "Your character sheet — class, XP, streaks, and records, **including calories and heart rate**"),
                    ("📸", "Wins you post to the feed, with photos and captions"),
                    ("🏆", "Your weekly XP, if you join the challenge"),
                ])
            consentCard(
                title: "YOU'RE IN CONTROL",
                tint: BRTheme.greenFG, fill: BRTheme.tintGreen,
                rows: [
                    ("👥", "Only players you accept into your party can see any of it"),
                    ("🔒", "Go private anytime in Settings — nothing has to be shared"),
                    ("🚫", "Block anyone to hide everything, both ways"),
                ])
        }
        .padding(.top, 22)
    }

    private func consentCard(title: String, tint: Color, fill: Color,
                             rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.pixel(9)).foregroundStyle(tint)
            ForEach(rows, id: \.1) { emoji, text in
                HStack(alignment: .top, spacing: 10) {
                    Text(emoji).font(.system(size: 16)).accessibilityHidden(true)
                    Text(markdown(text))
                        .font(.subheadline).foregroundStyle(BRTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1))
        )
    }

    /// The two hard lines from the pivot, stated as a promise. Dark card in
    /// both themes, so the body text is light (not `textPrimary`, which goes
    /// dark in light mode and would vanish on the dark fill).
    private var promise: some View {
        VStack(spacing: 6) {
            Text("OUR PROMISE")
                .font(.pixel(8)).foregroundStyle(BRTheme.gold)
            Text("We never sell or hand your health data to sponsors or advertisers, and never use it for ad targeting.")
                .font(.footnote).foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BRTheme.darkIsland)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(BRTheme.gold.opacity(0.5), lineWidth: 1))
        )
        .padding(.top, 14)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(.signIn) { request in
                guild.prepareAppleRequest(request)
            } onCompletion: { result in
                Task {
                    await guild.handleAppleCompletion(result)
                    if guild.phase != .signedOut { dismiss(); onJoin() }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .accessibilityLabel("Sign in with Apple to join the guild")

            Text("Signing in means you agree to share as described. You can change or stop it anytime in Settings.")
                .font(.caption2).foregroundStyle(BRTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Link("Privacy Policy", destination: policyURL)
                .font(.caption).foregroundStyle(BRTheme.blueFG)
                .padding(.top, 2)

            Button { dismiss() } label: {
                Text("NOT NOW")
                    .font(.pixel(9)).foregroundStyle(BRTheme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Stay solo. You can join anytime from the Guild tab.")
        }
        .padding(.top, 22)
    }

    /// Small helper so the disclosure rows can bold key phrases inline.
    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
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
