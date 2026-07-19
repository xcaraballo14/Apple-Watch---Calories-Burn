import Combine
import Foundation
import SwiftUI

/// Guild events for the bell: who wants to join your party, who joined, and
/// who reacted to your wins.
///
/// **Deliberately separate from `AlertFeed`.** Everything AlertFeed produces is
/// derived from HealthKit on demand, so a reinstall rebuilds it exactly. These
/// items are *fetched* from Supabase and can't be — they only exist for a
/// signed-in player with a network. Keeping them in their own store means the
/// derivation-first guarantee still describes AlertFeed truthfully, and the
/// bell simply shows both.
///
/// No account → this stays empty and the bell looks exactly as it does today.
@MainActor
final class SocialAlertStore: ObservableObject {
    static let shared = SocialAlertStore()

    @Published private(set) var items: [AlertItem] = []

    /// How far back to look. Older guild history isn't interesting and would
    /// push real achievements out of the feed.
    private let window: TimeInterval = 14 * 24 * 60 * 60
    private let isDemo: Bool

    private init() {
        isDemo = ProcessInfo.processInfo.arguments.contains("-BRDemoSocialAlerts")
        if isDemo { items = DemoSocialAlerts.items }
    }

    func clear() { items = [] }

    // MARK: - Fetching

    /// Pulls the three guild-news sources and rebuilds the rows. Self-contained
    /// on purpose: the bell lives on Home, which doesn't own the guild manager,
    /// so this store asks for what it needs rather than depending on load order
    /// somewhere else.
    func refresh() async {
        guard !isDemo, let me = SupabaseAPI.shared.currentUserID else { return }
        let since = Date().addingTimeInterval(-window)
        do {
            async let friendshipsTask = loadFriendships(me: me, since: since)
            async let reactionsTask = loadReactions(me: me, since: since)
            let (requests, joined) = try await friendshipsTask
            let reactions = try await reactionsTask
            items = Self.build(requests: requests, joined: joined, reactions: reactions)
        } catch {
            // The bell degrades to achievements-only rather than shouting; a
            // failed guild fetch isn't something the player can act on.
            guard !error.isCancellation else { return }
            items = []
        }
    }

    /// Pending requests aimed at me, plus requests *I* sent that were accepted.
    /// Deliberately not the reverse: if I accepted someone's request, I already
    /// know — telling me again is noise.
    private func loadFriendships(
        me: UUID, since: Date
    ) async throws -> (requests: [SocialProfile], joined: [(profile: SocialProfile, date: Date)]) {
        let rows: [FriendshipRow] = try await SupabaseAPI.shared.select(
            "friendships",
            query: [URLQueryItem(name: "select", value: "*")]   // RLS scopes this to me
        )
        let pendingIn = rows.filter { $0.status == "pending" && $0.addressee == me }
        let acceptedMine = rows.filter {
            $0.status == "accepted" && $0.requester == me
                && ($0.updatedAt ?? .distantPast) >= since
        }

        let profiles = try await self.profiles(
            ids: pendingIn.map(\.requester) + acceptedMine.map(\.addressee)
        )
        return (
            requests: pendingIn.compactMap { profiles[$0.requester] },
            joined: acceptedMine.compactMap { row in
                guard let profile = profiles[row.addressee], let date = row.updatedAt
                else { return nil }
                return (profile, date)
            }
        )
    }

    /// Reactions other people left on my posts, grouped one row per post.
    private func loadReactions(me: UUID, since: Date) async throws -> [ReactionSummary] {
        let myPosts: [ShareEventRow] = try await SupabaseAPI.shared.select(
            "share_events",
            query: [URLQueryItem(name: "user_id", value: "eq.\(me.uuidString)"),
                    URLQueryItem(name: "select", value: "*"),
                    URLQueryItem(name: "order", value: "created_at.desc"),
                    URLQueryItem(name: "limit", value: "30")]
        )
        guard !myPosts.isEmpty else { return [] }

        let list = myPosts.map(\.id.uuidString).joined(separator: ",")
        let rows: [ReactionRow] = try await SupabaseAPI.shared.select(
            "reactions",
            query: [URLQueryItem(name: "event_id", value: "in.(\(list))"),
                    URLQueryItem(name: "created_at", value: "gte.\(Self.iso.string(from: since))"),
                    URLQueryItem(name: "select", value: "*"),
                    URLQueryItem(name: "order", value: "created_at.desc")]
        )
        // Can't react to your own post, but filter anyway rather than trust it.
        let others = rows.filter { $0.userID != me }
        guard !others.isEmpty else { return [] }

        let reactors = try await profiles(ids: others.map(\.userID))
        let titles = Dictionary(uniqueKeysWithValues: myPosts.map { ($0.id, Self.title(for: $0)) })

        return Dictionary(grouping: others, by: \.eventID).compactMap { eventID, group in
            let sorted = group.sorted {
                ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
            var counts: [Reaction: Int] = [:]
            for row in sorted {
                guard let reaction = Reaction(rawValue: row.reaction) else { continue }
                counts[reaction, default: 0] += 1
            }
            guard !counts.isEmpty else { return nil }
            // Names in most-recent-first order, deduped — the headline names
            // whoever reacted last.
            var names: [String] = []
            for row in sorted {
                guard let name = reactors[row.userID]?.username, !names.contains(name)
                else { continue }
                names.append(name)
            }
            return ReactionSummary(
                eventID: eventID,
                postTitle: titles[eventID] ?? "your win",
                names: names,
                counts: counts,
                latest: sorted.first?.createdAt ?? .distantPast
            )
        }
    }

    private func profiles(ids: [UUID]) async throws -> [UUID: SocialProfile] {
        let unique = Set(ids)
        guard !unique.isEmpty else { return [:] }
        let list = unique.map(\.uuidString).joined(separator: ",")
        let rows: [SocialProfile] = try await SupabaseAPI.shared.select(
            "profiles",
            query: [URLQueryItem(name: "id", value: "in.(\(list))"),
                    URLQueryItem(name: "select", value: "*")]
        )
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
    }

    /// What to call a post in "…reacted on <this>".
    private static func title(for row: ShareEventRow) -> String {
        switch row.kind {
        case "quest":   row.payload.reward ?? "your quest"
        case "badge":   row.payload.name ?? "your badge"
        case "levelup": row.payload.level.map { "Level \($0)" } ?? "your level up"
        default:        "your win"
        }
    }

    private static let iso = ISO8601DateFormatter()

    // MARK: - Row building

    /// Builds the feed rows. Pure given its inputs, so the shape can be
    /// exercised without a network.
    static func build(
        requests: [SocialProfile],
        joined: [(profile: SocialProfile, date: Date)],
        reactions: [ReactionSummary],
        now: Date = .now
    ) -> [AlertItem] {
        var rows: [AlertItem] = []

        for request in requests {
            rows.append(AlertItem(
                id: "social_request_\(request.id)",
                kind: .friendRequest,
                emoji: "🤝",
                title: "@\(request.username) wants to join",
                detail: "LVL \(request.level) · \(request.title) — tap to answer",
                time: "Now",
                date: nil          // actionable, so it pins like a nudge
            ))
        }

        for entry in joined {
            rows.append(AlertItem(
                id: "social_joined_\(entry.profile.id)",
                kind: .friendJoined,
                emoji: "🎉",
                title: "@\(entry.profile.username) joined your party",
                detail: "LVL \(entry.profile.level) · \(entry.profile.title)",
                time: relative(entry.date, now: now),
                date: entry.date
            ))
        }

        for summary in reactions {
            rows.append(AlertItem(
                id: "social_reaction_\(summary.eventID)",
                kind: .reaction,
                emoji: summary.topReaction.emoji,
                title: summary.headline,
                detail: summary.detail,
                time: relative(summary.latest, now: now),
                date: summary.latest
            ))
        }

        // Requests first (they need an answer), then newest to oldest.
        return rows.sorted { lhs, rhs in
            if (lhs.date == nil) != (rhs.date == nil) { return lhs.date == nil }
            return (lhs.date ?? .distantFuture) > (rhs.date ?? .distantFuture)
        }
    }

    /// Same coarse buckets the rest of the app uses — exact times are neither
    /// needed nor anyone's business.
    private static func relative(_ date: Date, now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if minutes < 60 { return "\(max(1, minutes))m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return days == 1 ? "Yesterday" : "\(days)d ago"
    }
}

/// Reactions on one of your posts, collapsed into a single row. Five people
/// cheering the same win is one piece of news, not five.
struct ReactionSummary: Identifiable, Equatable {
    let eventID: UUID
    /// What the post was, for the detail line ("your Glazed Donut").
    let postTitle: String
    /// Who reacted, most recent first.
    let names: [String]
    let counts: [Reaction: Int]
    let latest: Date

    var id: UUID { eventID }

    var topReaction: Reaction {
        counts.max { $0.value < $1.value }?.key ?? .burn
    }

    var headline: String {
        switch names.count {
        case 0:  "Someone reacted"
        case 1:  "@\(names[0]) reacted"
        case 2:  "@\(names[0]) and @\(names[1]) reacted"
        default: "@\(names[0]) and \(names.count - 1) others reacted"
        }
    }

    var detail: String {
        let tally = Reaction.allCases
            .compactMap { reaction -> String? in
                guard let count = counts[reaction], count > 0 else { return nil }
                return "\(reaction.emoji) \(count)"
            }
            .joined(separator: "  ")
        return "\(tally) on \(postTitle)"
    }
}

// MARK: - Mockup fixtures (`-BRDemoSocialAlerts`)

enum DemoSocialAlerts {
    static let items: [AlertItem] = SocialAlertStore.build(
        requests: [
            SocialProfile(id: UUID(), username: "pedro_bikes", avatarKind: "pixel",
                          avatarRef: nil, level: 3, title: "SNACK ROOKIE", badgeIDs: []),
        ],
        joined: [
            (SocialProfile(id: UUID(), username: "mika_runs", avatarKind: "pixel",
                           avatarRef: nil, level: 8, title: "DUNGEON DINER", badgeIDs: []),
             Date().addingTimeInterval(-7_200)),
        ],
        reactions: [
            ReactionSummary(eventID: UUID(),
                            postTitle: "Chocolate Milkshake",
                            names: ["ana_walks", "carlos_lifts", "mika_runs"],
                            counts: [.burn: 2, .legend: 1],
                            latest: Date().addingTimeInterval(-3_000)),
            ReactionSummary(eventID: UUID(),
                            postTitle: "Glazed Donut",
                            names: ["carlos_lifts"],
                            counts: [.strong: 1],
                            latest: Date().addingTimeInterval(-95_000)),
        ]
    )
}
