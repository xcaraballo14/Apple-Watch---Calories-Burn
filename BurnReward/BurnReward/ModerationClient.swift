import Combine
import Foundation

/// P4a server operations: filing reports, blocking, unblocking. Kept apart
/// from `GuildManager` on purpose — moderation is rare-path and stateless,
/// so callers (feed, member sheet, settings) hit this and then refresh
/// whatever store they own. Every method returns the error text to show, or
/// nil on success — the "every async action gets a visible failure" rule.
@MainActor
final class ModerationClient {
    static let shared = ModerationClient()
    private init() {}

    /// Files a report. `eventID` is nil when reporting a player rather than
    /// a specific post. The reporter-side hide is the caller's job (the
    /// feed knows which rows it shows; we don't).
    func report(user targetID: UUID, event eventID: UUID?,
                reason: ReportReason, note: String) async -> String? {
        guard let me = SupabaseAPI.shared.currentUserID else {
            return "Sign in to the guild first."
        }
        guard targetID != me else { return nil }   // can't report yourself; no-op

        struct NewReport: Encodable {
            let reporter: UUID
            let targetUser: UUID
            let eventID: UUID?
            let reason: String
            let note: String?

            enum CodingKeys: String, CodingKey {
                case reporter, reason, note
                case targetUser = "target_user"
                case eventID = "event_id"
            }
        }
        do {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            // Write-only table: no select policy, so the insert must not ask
            // for the row back (RETURNING would 403 on the missing select).
            try await SupabaseAPI.shared.insertNoEcho(
                "reports",
                values: [NewReport(reporter: me, targetUser: targetID,
                                   eventID: eventID, reason: reason.rawValue,
                                   note: trimmed.isEmpty ? nil : trimmed)]
            )
            return nil
        } catch {
            if error.isCancellation { return nil }
            return "The report didn't send — check your connection and try again."
        }
    }

    /// Flips the pair's friendship row to 'blocked' (or creates one if no row
    /// exists — e.g. they were removed from the party first). Mutual
    /// invisibility is then RLS doing its normal job: `are_friends()` fails,
    /// so posts, photos, and reactions vanish in both directions.
    func block(userID: UUID) async -> String? {
        guard let me = SupabaseAPI.shared.currentUserID else {
            return "Sign in to the guild first."
        }
        guard userID != me else { return nil }

        struct BlockPatch: Encodable {
            let status: String
            let blockedBy: UUID
            enum CodingKeys: String, CodingKey {
                case status
                case blockedBy = "blocked_by"
            }
        }
        struct NewBlock: Encodable {
            let requester: UUID
            let addressee: UUID
            let status: String
            let blockedBy: UUID
            enum CodingKeys: String, CodingKey {
                case requester, addressee, status
                case blockedBy = "blocked_by"
            }
        }
        do {
            let patched: [FriendshipRow] = try await SupabaseAPI.shared.update(
                "friendships",
                values: BlockPatch(status: "blocked", blockedBy: me),
                query: [URLQueryItem(name: "or", value:
                    "(and(requester.eq.\(me),addressee.eq.\(userID)),"
                    + "and(requester.eq.\(userID),addressee.eq.\(me)))")]
            )
            if patched.isEmpty {
                let _: [FriendshipRow] = try await SupabaseAPI.shared.insert(
                    "friendships",
                    values: [NewBlock(requester: me, addressee: userID,
                                      status: "blocked", blockedBy: me)]
                )
            }
            return nil
        } catch {
            if error.isCancellation { return nil }
            return "The block didn't go through — check your connection and try again."
        }
    }

    /// Deletes the blocked row. RLS only lets the blocker do this, so there's
    /// no way to unblock yourself out of someone else's block.
    func unblock(userID: UUID) async -> String? {
        guard let me = SupabaseAPI.shared.currentUserID else {
            return "Sign in to the guild first."
        }
        do {
            try await SupabaseAPI.shared.delete(
                "friendships",
                query: [URLQueryItem(name: "status", value: "eq.blocked"),
                        URLQueryItem(name: "blocked_by", value: "eq.\(me)"),
                        URLQueryItem(name: "or", value:
                            "(and(requester.eq.\(me),addressee.eq.\(userID)),"
                            + "and(requester.eq.\(userID),addressee.eq.\(me)))")]
            )
            return nil
        } catch {
            if error.isCancellation { return nil }
            return "Couldn't unblock — check your connection and try again."
        }
    }

    /// The players this account has blocked, for the Settings list.
    func blockedPlayers() async throws -> [SocialProfile] {
        guard let me = SupabaseAPI.shared.currentUserID else { return [] }
        let rows: [FriendshipRow] = try await SupabaseAPI.shared.select(
            "friendships",
            query: [URLQueryItem(name: "status", value: "eq.blocked"),
                    URLQueryItem(name: "blocked_by", value: "eq.\(me)"),
                    URLQueryItem(name: "select", value: "*")]
        )
        let ids = rows.map { $0.requester == me ? $0.addressee : $0.requester }
        guard !ids.isEmpty else { return [] }
        let list = ids.map(\.uuidString).joined(separator: ",")
        let profiles: [SocialProfile] = try await SupabaseAPI.shared.select(
            "profiles",
            query: [URLQueryItem(name: "id", value: "in.(\(list))"),
                    URLQueryItem(name: "select", value: "*")]
        )
        return profiles.sorted { $0.username < $1.username }
    }
}
