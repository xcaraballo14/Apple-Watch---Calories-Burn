import Combine
import Foundation

/// The week boundary for the ⚔️ WEEKLY CHALLENGE. Fixed Monday-start so every
/// device buckets the week identically regardless of the locale's first
/// weekday — otherwise two friends could land in "different weeks" and never
/// see each other's scores.
enum LeaderboardWeek {
    /// Gregorian, Monday-start. Time zone stays the device's, so a friend right
    /// at the Sunday→Monday seam can disagree by a day; it self-heals on the
    /// next refresh and is acceptable for a friends board.
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2   // Monday
        return cal
    }

    static func start(_ now: Date = .now) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    }

    static func startString(_ now: Date = .now) -> String {
        formatter.string(from: start(now))
    }

    /// Same phrasing as `WeeklyChallenge.daysLeftText` so the two weekly clocks
    /// in the app never word the same day differently.
    static func resetText(_ now: Date = .now) -> String {
        let end = calendar.date(byAdding: .day, value: 7, to: start(now)) ?? now
        let days = max(0, calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: end).day ?? 0)
        switch days {
        case ...1: return "RESETS TODAY"
        case 2:    return "RESETS IN 1 DAY"
        default:   return "RESETS IN \(days - 1) DAYS"
        }
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

/// Owns the ⚔️ WEEKLY CHALLENGE board: posting your own weekly XP (opt-in) and
/// fetching your party's. Like the rest of social, nothing here runs without a
/// signed-in guild account, and the quest loop never reads it.
///
/// The only thing that ever leaves the device is an integer XP total and the
/// week it belongs to — never a workout. RLS in `p3_schema.sql` scopes reads
/// to accepted friends; this client just asks and ranks.
@MainActor
final class LeaderboardManager: ObservableObject {
    static let shared = LeaderboardManager()

    @Published private(set) var entries: [LeaderboardEntry] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// Opt-in, off by default (Xavier's ruling): the player must ENTER THE
    /// CHALLENGE before their XP is posted anywhere.
    @Published var isParticipating: Bool {
        didSet {
            // Demo launches flip this for the mockup; never let that overwrite
            // the real player's saved preference.
            guard !isDemo, oldValue != isParticipating else { return }
            UserDefaults.standard.set(isParticipating, forKey: Self.optInKey)
        }
    }
    private static let optInKey = "br.social.postWeeklyXP"

    private let isDemo: Bool

    private init() {
        isParticipating = UserDefaults.standard.bool(forKey: Self.optInKey)
        let arguments = ProcessInfo.processInfo.arguments
        isDemo = arguments.contains("-BRDemoLeaderboard")
            || arguments.contains("-BRDemoLeaderboardJoin")
        if arguments.contains("-BRDemoLeaderboardJoin") {
            isParticipating = false
            entries = DemoLeaderboard.watching
        } else if arguments.contains("-BRDemoLeaderboard") {
            isParticipating = true
            entries = DemoLeaderboard.entries
        }
    }

    var resetText: String { LeaderboardWeek.resetText() }

    /// Posts the player's weekly XP (if opted in) then fetches the party's and
    /// ranks. `myWeeklyXP` is derived locally from this week's quests; `me` and
    /// `friends` come from the guild so scores get names to show.
    func refresh(myWeeklyXP: Int, me: SocialProfile?, friends: [SocialProfile]) async {
        guard !isDemo, let meID = SupabaseAPI.shared.currentUserID else { return }
        isLoading = true
        defer { isLoading = false }
        let weekStart = LeaderboardWeek.startString()
        do {
            if isParticipating {
                try await SupabaseAPI.shared.upsert(
                    "weekly_scores",
                    values: WeeklyScoreRow(userID: meID, weekStart: weekStart, xp: myWeeklyXP)
                )
            }
            // RLS scopes this to me + accepted friends. Only this week's rows.
            let rows: [WeeklyScoreRow] = try await SupabaseAPI.shared.select(
                "weekly_scores",
                query: [URLQueryItem(name: "week_start", value: "eq.\(weekStart)"),
                        URLQueryItem(name: "select", value: "user_id,week_start,xp")]
            )
            entries = Self.build(rows: rows, meID: meID, me: me, friends: friends)
        } catch {
            guard !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Turn on posting and immediately publish this week's score.
    func join(myWeeklyXP: Int, me: SocialProfile?, friends: [SocialProfile]) async {
        isParticipating = true
        await refresh(myWeeklyXP: myWeeklyXP, me: me, friends: friends)
    }

    /// The Settings toggle, where the friends list isn't at hand. Posting only
    /// needs your own id + XP, so this publishes (or deletes) without rebuilding
    /// the display — the board fills in the next time ARENA opens.
    func setParticipating(_ on: Bool, myWeeklyXP: Int) async {
        guard on else { await leave(); return }
        isParticipating = true
        guard !isDemo, let meID = SupabaseAPI.shared.currentUserID else { return }
        do {
            try await SupabaseAPI.shared.upsert(
                "weekly_scores",
                values: WeeklyScoreRow(userID: meID,
                                       weekStart: LeaderboardWeek.startString(),
                                       xp: myWeeklyXP)
            )
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
    }

    /// Leave the challenge: stop posting and delete every score you've posted,
    /// so you drop off every friend's board right away.
    func leave() async {
        isParticipating = false
        guard !isDemo, let meID = SupabaseAPI.shared.currentUserID else {
            entries.removeAll { $0.isMe }
            return
        }
        do {
            try await SupabaseAPI.shared.delete(
                "weekly_scores",
                query: [URLQueryItem(name: "user_id", value: "eq.\(meID.uuidString)")]
            )
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        entries.removeAll { $0.isMe }
    }

    func signedOut() {
        entries = []
        errorMessage = nil
    }

    // MARK: - Building

    /// Turns raw score rows into named, ranked entries. Pure given its inputs.
    /// A row with no matching profile (shouldn't happen under RLS) is dropped
    /// rather than shown as a blank.
    static func build(
        rows: [WeeklyScoreRow], meID: UUID,
        me: SocialProfile?, friends: [SocialProfile]
    ) -> [LeaderboardEntry] {
        var byID: [UUID: SocialProfile] = [:]
        for friend in friends { byID[friend.id] = friend }
        if let me { byID[meID] = me }

        return rows.compactMap { row in
            guard let profile = byID[row.userID] else { return nil }
            return LeaderboardEntry(
                id: row.userID,
                username: profile.username,
                level: profile.level,
                title: profile.title,
                weeklyXP: row.xp,
                isMe: row.userID == meID
            )
        }
    }
}
