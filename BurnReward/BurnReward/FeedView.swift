import PhotosUI
import SwiftUI

// MARK: - Model (mockup shape — becomes the `share_events` row in P2 wiring)

/// What a friend did. The wire payload is summary-only: no HealthKit samples,
/// no heart rate, no route — just what the poster chose to publish.
enum FeedEventKind: Equatable {
    /// Reward name + emoji, calories burned, duration, XP earned.
    case quest(reward: String, emoji: String, calories: Int, seconds: Int, xp: Int)
    /// Badge id (drives `Art/badge_<id>.png`) + its display name.
    case badge(id: String, name: String)
    /// The new level and the title that came with it.
    case levelUp(level: Int, title: String)
}

/// The fixed reaction palette (Xavier's ruling 2026-07-18: expressive
/// reactions, no comments). A closed set is the whole point — nobody can type
/// anything, so there is no abuse surface and no moderation burden, which is
/// exactly what free-text comments would have cost.
enum Reaction: String, CaseIterable, Identifiable, Codable {
    case burn, strong, legend, respect

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .burn:    "🔥"
        case .strong:  "💪"
        case .legend:  "👑"
        case .respect: "⚔️"
        }
    }

    /// Carries the meaning for VoiceOver, where the emoji can't — and doubles
    /// as the button label, so every reaction says what it means.
    var name: String {
        switch self {
        case .burn:    "Burn"
        case .strong:  "Strong"
        case .legend:  "Legend"
        case .respect: "Respect"
        }
    }

    /// Each reaction owns a colour so the row scans like the stats console.
    var color: Color {
        switch self {
        case .burn:    BRTheme.orangeFG
        case .strong:  BRTheme.greenFG
        case .legend:  BRTheme.gold
        case .respect: BRTheme.blueFG
        }
    }
}

struct FeedEvent: Identifiable, Equatable {
    let id: UUID
    let username: String
    let level: Int
    let title: String
    let kind: FeedEventKind
    /// Optional player-written line, ≤100 chars, filtered before it ships.
    let caption: String?
    let date: Date
    /// Counts per reaction. One reaction per player per post, so these read as
    /// "how many people felt this way" rather than raw tap volume.
    var reactions: [Reaction: Int]
    /// Which one you picked, if any. Tapping another moves your reaction.
    var myReaction: Reaction?
    /// The moment itself — a selfie, the trail, the actual donut. Up to
    /// `maxPhotos`, always explicitly attached. `photoPaths` is what the row
    /// stores; `photos` fills in as the private-bucket downloads land.
    var photoPaths: [String] = []
    var photos: [UIImage] = []
    /// Your own posts read differently (and can't be reacted to by you).
    var isMine: Bool = false

    var totalReactions: Int { reactions.values.reduce(0, +) }
}

extension FeedEvent {
    /// The auto-generated structured line — always present, always truthful,
    /// derived from the payload rather than typed by the player.
    var headline: String {
        switch kind {
        case .quest(let reward, _, _, _, _): "EARNED \(reward.uppercased())"
        case .badge(_, let name):            "UNLOCKED \(name.uppercased())"
        case .levelUp(let level, let title): "REACHED LVL \(level) · \(title)"
        }
    }

    var accent: Color {
        switch kind {
        case .quest:   BRTheme.orangeFG
        case .badge:   BRTheme.gold
        case .levelUp: BRTheme.greenFG
        }
    }

    var kindLabel: String {
        switch kind {
        case .quest:   "QUEST"
        case .badge:   "TROPHY"
        case .levelUp: "LEVEL UP"
        }
    }

    /// Compact relative stamp — "2h", "3d". Deliberately coarse: the exact
    /// workout timestamp is health data and never leaves the device.
    var stamp: String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes < 60 { return "\(max(1, minutes))m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

// MARK: - Feed screen

/// The activity feed: what your party has been burning. Reactions are the
/// only response, by design — no comments, no DMs (Xavier's ruling, and the
/// reason this ships without a moderation queue behind it).
struct FeedView: View {
    let events: [FeedEvent]
    let hasFriends: Bool
    let onReact: (FeedEvent, Reaction) -> Void
    let onRecruit: () -> Void

    var body: some View {
        Group {
            if events.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(events) { event in
                            FeedRow(event: event) { onReact(event, $0) }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: hasFriends ? "flame" : "person.2")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(BRTheme.textMuted)
                    .padding(.top, 40)
                Text(hasFriends ? "THE HALL IS QUIET" : "NO PARTY YET")
                    .font(.pixel(12))
                    .foregroundStyle(BRTheme.textPrimary)
                Text(hasFriends
                     ? "Nobody's posted a win yet. Be the first — finish a quest and share it to the guild."
                     : "Recruit a friend and their victories show up right here.")
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                if !hasFriends {
                    Button(action: onRecruit) {
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
                    .padding(.horizontal, 32)
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - One post

struct FeedRow: View {
    let event: FeedEvent
    let onReact: (Reaction) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            body_
            // Photo first, then the numbers — the moment sets the scene and
            // the stats land as the payoff right before the actions.
            if !event.photos.isEmpty {
                PhotoCarousel(photos: event.photos)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
            statsPanel
            reactionBar
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BRTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(event.isMine ? BRTheme.gold.opacity(0.55) : BRTheme.cardBorder,
                                      lineWidth: event.isMine ? 1.5 : 1)
                )
        )
        .accessibilityElement(children: .contain)
    }

    // Who posted, and when.
    private var header: some View {
        HStack(spacing: 10) {
            FeedAvatar(username: event.username, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.isMine ? "YOU" : "@\(event.username)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BRTheme.textPrimary)
                        .lineLimit(1)
                    if event.isMine {
                        Text("YOU")
                            .font(.pixel(6))
                            .foregroundStyle(BRTheme.gold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(BRTheme.gold.opacity(0.15)))
                            .hidden()   // the name already says YOU; keeps layout stable
                    }
                }
                Text("LVL \(event.level) · \(event.title)")
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 3) {
                Text(event.stamp)
                    .font(.caption2)
                    .foregroundStyle(BRTheme.textMuted)
                Text(event.kindLabel)
                    .font(.pixel(6))
                    .foregroundStyle(event.accent)
            }
        }
        .padding(14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.isMine ? "You" : event.username), level \(event.level) \(event.title), \(event.stamp) ago.")
    }

    // The win itself.
    @ViewBuilder private var body_: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.headline)
                        .font(.pixel(10))
                        .foregroundStyle(event.accent)
                        .fixedSize(horizontal: false, vertical: true)
                    if let caption = event.caption, !caption.isEmpty {
                        Text("“\(caption)”")
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(BRTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenBody)
    }

    /// One console readout rather than three loose chips (Xavier's design,
    /// 2026-07-18): a single framed panel, hairline dividers between the
    /// columns, and the numbers sized to be the first thing the eye lands on.
    @ViewBuilder private var statsPanel: some View {
        if case .quest(_, _, let calories, let seconds, let xp) = event.kind {
            HStack(spacing: 0) {
                statColumn("🔥", "CALORIES", "\(calories)", "CAL", BRTheme.orangeFG)
                statDividerLine
                statColumn("⏱", "TIME", durationText(seconds), "MIN", BRTheme.blueFG)
                statDividerLine
                statColumn("⭐", "XP EARNED", "+\(xp)", "XP", BRTheme.gold)
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BRTheme.track.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(BRTheme.cardBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    private var statDividerLine: some View {
        Rectangle()
            .fill(BRTheme.cardBorder)
            .frame(width: 1, height: 44)
    }

    private func statColumn(_ icon: String, _ label: String,
                            _ value: String, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(icon).font(.system(size: 11))
                Text(label)
                    .font(.pixel(6))
                    .foregroundStyle(BRTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(value)
                .font(.pixel(16))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(unit)
                .font(.pixel(6))
                .foregroundStyle(BRTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var icon: some View {
        switch event.kind {
        case .quest(_, let emoji, _, _, _):
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BRTheme.tintOrange)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(BRTheme.orangeFG.opacity(0.35), lineWidth: 1)
                    )
                Text(emoji).font(.system(size: 26))
            }
            .frame(width: 52, height: 52)
        case .badge(let id, _):
            Group {
                if let art = UIImage(named: "badge_\(id)") {
                    Image(uiImage: art)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    ZStack {
                        Circle().fill(BRTheme.gold.opacity(0.16))
                            .overlay(Circle().strokeBorder(BRTheme.gold, lineWidth: 1))
                        Image(systemName: "rosette")
                            .font(.system(size: 22))
                            .foregroundStyle(BRTheme.gold)
                    }
                }
            }
            .frame(width: 52, height: 52)
        case .levelUp(let level, _):
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BRTheme.tintGreen)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(BRTheme.greenFG.opacity(0.35), lineWidth: 1)
                    )
                VStack(spacing: 0) {
                    Text("LVL").font(.pixel(6)).foregroundStyle(BRTheme.textMuted)
                    Text("\(level)").font(.pixel(14)).foregroundStyle(BRTheme.greenFG)
                }
            }
            .frame(width: 52, height: 52)
        }
    }

    // Same console framing as the stats panel (Xavier's design, 2026-07-18) so
    // the card reads as one machine: a closed palette of named buttons that
    // invite a tap, with nothing free-text to moderate.
    private var reactionBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(Reaction.allCases.enumerated()), id: \.element) { offset, reaction in
                reactionButton(reaction)
                if offset < Reaction.allCases.count - 1 {
                    Rectangle()
                        .fill(BRTheme.cardBorder)
                        .frame(width: 1, height: 26)
                }
            }
        }
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BRTheme.track.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(BRTheme.cardBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func reactionButton(_ reaction: Reaction) -> some View {
        let count = event.reactions[reaction] ?? 0
        let mine = event.myReaction == reaction
        return Button { onReact(reaction) } label: {
            HStack(spacing: 4) {
                Text(reaction.emoji).font(.system(size: 13))
                if count > 0 {
                    Text("\(count)")
                        .font(.pixel(10))
                        .foregroundStyle(reaction.color)
                }
                Text(reaction.name.uppercased())
                    .font(.pixel(6))
                    .foregroundStyle(mine ? reaction.color : BRTheme.textMuted)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            // Fills the column so the whole width is tappable, and stays a
            // legal 44pt target even though the row reads compact.
            .frame(maxWidth: .infinity, minHeight: 26)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(mine ? reaction.color.opacity(0.18) : .clear)
                    .padding(.horizontal, 4)
            )
            .scaleEffect(mine && !reduceMotion ? 1.05 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.25), value: mine)
        }
        .buttonStyle(.plain)
        .disabled(event.isMine)
        .opacity(event.isMine ? 0.45 : 1)
        .accessibilityLabel(mine
            ? "Remove your \(reaction.name) reaction"
            : "React \(reaction.name)\(count > 0 ? ", \(count) so far" : "")")
    }

    private var spokenBody: String {
        var parts = [event.headline.capitalized]
        if case .quest(_, _, let calories, let seconds, let xp) = event.kind {
            parts.append("\(calories) calories, \(durationText(seconds)), \(xp) XP.")
        }
        if let caption = event.caption, !caption.isEmpty { parts.append("Caption: \(caption)") }
        return parts.joined(separator: " ")
    }

    private func durationText(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        if m >= 60 { return String(format: "%d:%02d:%02d", m / 60, m % 60, s) }
        return String(format: "%d:%02d", m, s)
    }
}

/// Up to three photos, swipeable. Single photos skip the paging entirely so
/// the common case carries no carousel chrome.
struct PhotoCarousel: View {
    let photos: [UIImage]
    @State private var index = 0

    private let height: CGFloat = 220

    var body: some View {
        if photos.count == 1 {
            photoFrame(photos[0])
                .accessibilityLabel("Photo attached to this post")
        } else {
            ZStack(alignment: .bottom) {
                TabView(selection: $index) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { offset, photo in
                        photoFrame(photo)
                            .tag(offset)
                            .accessibilityLabel("Photo \(offset + 1) of \(photos.count)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: height)

                // Own dots rather than the system index view: the system one
                // can't be tinted per-page reliably and disappears on light
                // photos. A pill behind them keeps them legible on anything.
                HStack(spacing: 6) {
                    ForEach(photos.indices, id: \.self) { position in
                        Circle()
                            .fill(position == index ? Color.white : Color.white.opacity(0.45))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(.black.opacity(0.45)))
                .padding(.bottom, 10)
                .accessibilityHidden(true)   // the pages already announce position
            }
            .frame(height: height)
        }
    }

    private func photoFrame(_ photo: UIImage) -> some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
    }
}

/// Placeholder identity art — the pixel avatar set (P1.5) drops in here.
struct FeedAvatar: View {
    let username: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(BRTheme.track)
            Circle().strokeBorder(BRTheme.gold.opacity(0.5), lineWidth: 1)
            Text(String(username.prefix(1)).uppercased())
                .font(.pixel(size / 3.2))
                .foregroundStyle(BRTheme.gold)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Compose (share a win to the guild)

/// The post sheet: the same card the player already shares to Instagram, plus
/// an optional caption. Nothing posts without this explicit step.
struct PostToGuildSheet: View {
    let headline: String
    let emoji: String
    let detail: String
    /// Returns whether the post actually landed. The sheet stays open on
    /// failure so the player can see why and retry — dismissing regardless
    /// turned a 403 into "nothing happened", which is how the storage
    /// permission bug stayed invisible through a whole device test.
    let onPost: (String, [UIImage]) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var photos: [UIImage] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isPosting = false
    @FocusState private var captionFocused: Bool

    private let limit = 100
    /// Three is the ceiling Xavier set: enough for the selfie, the place, and
    /// the reward, without turning a post into an album.
    private let maxPhotos = 3

    init(headline: String, emoji: String, detail: String,
         onPost: @escaping (String, [UIImage]) async -> Bool) {
        self.headline = headline
        self.emoji = emoji
        self.detail = detail
        self.onPost = onPost
        // Screenshot helper: pre-fills the picker so the thumbnail row is
        // visible without driving the system photo picker.
        if ProcessInfo.processInfo.arguments.contains("-BRDemoPostPhotos") {
            _photos = State(initialValue: [
                DemoFeed.placeholderPhoto(UIColor(red: 0.99, green: 0.66, blue: 0.30, alpha: 1),
                                          UIColor(red: 0.72, green: 0.33, blue: 0.42, alpha: 1),
                                          sun: true),
                DemoFeed.placeholderPhoto(UIColor(red: 0.55, green: 0.78, blue: 0.55, alpha: 1),
                                          UIColor(red: 0.18, green: 0.40, blue: 0.28, alpha: 1),
                                          sun: false),
            ])
            _caption = State(initialValue: "Precision run — landed within 2%.")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PixelSectionLabel(text: "WHAT YOUR PARTY WILL SEE")
                    preview
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            PixelSectionLabel(text: "ADD A LINE (OPTIONAL)")
                            Spacer()
                            Text("\(caption.count)/\(limit)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(caption.count > limit ? BRTheme.alertRed : BRTheme.textMuted)
                        }
                        TextField("Say something about this win…", text: $caption, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($captionFocused)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(BRTheme.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(BRTheme.cardBorder, lineWidth: 1)
                                    )
                            )
                            .onChange(of: caption) { _, new in
                                if new.count > limit { caption = String(new.prefix(limit)) }
                            }
                    }
                    photoSection
                    privacyNote
                    Button {
                        guard !isPosting else { return }
                        isPosting = true
                        Task {
                            let posted = await onPost(
                                caption.trimmingCharacters(in: .whitespacesAndNewlines), photos
                            )
                            isPosting = false
                            if posted { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isPosting {
                                ProgressView().tint(BRTheme.onNeonGreen)
                            }
                            Text(isPosting ? postingLabel : "POST TO GUILD")
                                .font(.pixel(11))
                                .foregroundStyle(BRTheme.onNeonGreen)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(BRTheme.neonGreen.opacity(isPosting ? 0.6 : 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPosting)
                    .accessibilityLabel("Post this win to your guild")
                }
                .padding(16)
            }
            .background(BRTheme.bg)
            .navigationTitle("Share to Guild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// Photos are opt-in per post and never auto-attached. The picker is
    /// PhotosUI's own — the app never sees the library, only the one image the
    /// player hands it.
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PixelSectionLabel(text: "ADD PHOTOS (OPTIONAL)")
                Spacer()
                Text("\(photos.count)/\(maxPhotos)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(BRTheme.textMuted)
            }
            HStack(spacing: 8) {
                ForEach(Array(photos.enumerated()), id: \.offset) { offset, photo in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Button {
                            photos.remove(at: offset)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(.black.opacity(0.6)))
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .accessibilityLabel("Remove photo \(offset + 1)")
                    }
                }
                if photos.count < maxPhotos {
                    PhotosPicker(selection: $photoItems,
                                 maxSelectionCount: maxPhotos - photos.count,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                            Text(photos.isEmpty ? "ATTACH" : "ADD").font(.pixel(7))
                        }
                        .foregroundStyle(BRTheme.textMuted)
                        .frame(width: photos.isEmpty ? nil : 96, height: 96)
                        .frame(maxWidth: photos.isEmpty ? .infinity : nil)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(BRTheme.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                        .foregroundStyle(BRTheme.cardBorder)
                                )
                        )
                    }
                    .accessibilityLabel("Attach a photo, \(photos.count) of \(maxPhotos) added")
                }
                Spacer(minLength: 0)
            }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items where photos.count < maxPhotos {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photos.append(image)
                    }
                }
                photoItems = []
            }
        }
    }

    /// Uploading a few photos takes real seconds; naming the step is the
    /// difference between "working" and "frozen".
    private var postingLabel: String {
        photos.isEmpty ? "POSTING…" : "UPLOADING…"
    }

    private var preview: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BRTheme.tintOrange)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(BRTheme.orangeFG.opacity(0.35), lineWidth: 1)
                    )
                Text(emoji).font(.system(size: 26))
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(headline)
                    .font(.pixel(10))
                    .foregroundStyle(BRTheme.orangeFG)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                if !caption.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("“\(caption)”")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(BRTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BRTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(BRTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.footnote)
                .foregroundStyle(BRTheme.greenFG)
            Text("Only your party sees this. Your heart rate, workout times, and everything else in Health stay on this iPhone.")
                .font(.caption)
                .foregroundStyle(BRTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BRTheme.tintGreen)
        )
    }
}

// MARK: - Mockup fixtures (`-BRDemoFeed`)

enum DemoFeed {
    /// Stand-in "photos" drawn at runtime so the mockup shows a real image
    /// without shipping sample bitmaps in the binary. Replaced by the player's
    /// actual photo once this is wired.
    static func placeholderPhoto(_ top: UIColor, _ bottom: UIColor, sun: Bool) -> UIImage {
        let size = CGSize(width: 800, height: 500)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            )!
            cg.drawLinearGradient(gradient, start: .zero,
                                  end: CGPoint(x: 0, y: size.height), options: [])
            if sun {
                UIColor(white: 1, alpha: 0.5).setFill()
                cg.fillEllipse(in: CGRect(x: 560, y: 70, width: 110, height: 110))
            }
            // A soft horizon so it reads as a place, not a swatch.
            UIColor(white: 0, alpha: 0.22).setFill()
            cg.fill(CGRect(x: 0, y: size.height * 0.68, width: size.width, height: size.height * 0.32))
        }
    }

    static let events: [FeedEvent] = [
        FeedEvent(id: UUID(), username: "mika_runs", level: 8, title: "DUNGEON DINER",
                  kind: .quest(reward: "Glazed Donut", emoji: "🍩",
                               calories: 268, seconds: 1_694, xp: 341),
                  caption: "Chased it down at the park. Worth every bite.",
                  date: Date().addingTimeInterval(-2_400),
                  reactions: [.burn: 3, .strong: 1], myReaction: .burn,
                  photos: [placeholderPhoto(UIColor(red: 0.99, green: 0.66, blue: 0.30, alpha: 1),
                                            UIColor(red: 0.72, green: 0.33, blue: 0.42, alpha: 1),
                                            sun: true),
                           placeholderPhoto(UIColor(red: 0.55, green: 0.78, blue: 0.55, alpha: 1),
                                            UIColor(red: 0.18, green: 0.40, blue: 0.28, alpha: 1),
                                            sun: false),
                           placeholderPhoto(UIColor(red: 0.86, green: 0.55, blue: 0.75, alpha: 1),
                                            UIColor(red: 0.40, green: 0.22, blue: 0.48, alpha: 1),
                                            sun: true)]),
        FeedEvent(id: UUID(), username: "ana_walks", level: 11, title: "FEAST PHANTOM",
                  kind: .badge(id: "inferno", name: "Inferno"),
                  caption: nil,
                  date: Date().addingTimeInterval(-9_800),
                  reactions: [.burn: 4, .legend: 3, .respect: 2], myReaction: .legend),
        FeedEvent(id: UUID(), username: "xavier_pr", level: 6, title: "SNACK SLAYER",
                  kind: .quest(reward: "Chocolate Milkshake", emoji: "🥤",
                               calories: 412, seconds: 2_580, xp: 508),
                  caption: "Precision run — landed within 2%.",
                  date: Date().addingTimeInterval(-21_600),
                  reactions: [.burn: 2, .strong: 2, .respect: 1], myReaction: nil,
                  photos: [placeholderPhoto(UIColor(red: 0.42, green: 0.68, blue: 0.85, alpha: 1),
                                            UIColor(red: 0.16, green: 0.38, blue: 0.42, alpha: 1),
                                            sun: false)],
                  isMine: true),
        FeedEvent(id: UUID(), username: "carlos_lifts", level: 4, title: "TREAT APPRENTICE",
                  kind: .levelUp(level: 4, title: "TREAT APPRENTICE"),
                  caption: nil,
                  date: Date().addingTimeInterval(-104_000),
                  reactions: [.legend: 2], myReaction: nil),
        FeedEvent(id: UUID(), username: "pedro_bikes", level: 3, title: "SNACK ROOKIE",
                  kind: .quest(reward: "Slice of Pepperoni", emoji: "🍕",
                               calories: 298, seconds: 2_105, xp: 372),
                  caption: "First quest ever. My legs are gone.",
                  date: Date().addingTimeInterval(-190_000),
                  reactions: [.burn: 5, .strong: 3, .legend: 1], myReaction: .burn),
    ]
}

#Preview("Feed") {
    FeedView(events: DemoFeed.events, hasFriends: true, onReact: { _, _ in }, onRecruit: {})
        .background(BRTheme.bg)
}

#Preview("Feed — empty") {
    FeedView(events: [], hasFriends: false, onReact: { _, _ in }, onRecruit: {})
        .background(BRTheme.bg)
}

#Preview("Post sheet") {
    PostToGuildSheet(headline: "EARNED CHOCOLATE MILKSHAKE",
                     emoji: "🥤",
                     detail: "412 cal · 43:00 · +508 XP",
                     onPost: { _, _ in true })
}
