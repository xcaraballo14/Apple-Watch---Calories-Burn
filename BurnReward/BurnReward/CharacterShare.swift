import Combine
import Foundation

/// Owns the shared character sheet (P3.5): pushing your snapshot to friends and
/// fetching theirs. Part of the 2026-07-21 Strava-competitor pivot (memory
/// `strava-pivot`) — the friend profile mirrors your CHARACTER page with real
/// metrics, shared by consent.
///
/// Visibility is a single toggle: on = your snapshot lives in `shared_characters`
/// (party-visible via RLS); off = the row is deleted (private → friends see only
/// name/level/trophies). Nothing here runs without a signed-in account, and the
/// snapshot is still derived locally first — the server only holds what you share.
@MainActor
final class CharacterShare: ObservableObject {
    static let shared = CharacterShare()

    /// "Show my character to my party." Default ON (full-open pivot); the
    /// first-run consent screen is the wedge's disclosure layer, coming next.
    @Published var isSharing: Bool {
        didSet {
            guard !isDemo, oldValue != isSharing else { return }
            UserDefaults.standard.set(isSharing, forKey: Self.key)
            Task { await push() }
        }
    }
    @Published var errorMessage: String?

    private static let key = "br.social.shareCharacter"
    /// The most recent locally-derived snapshot, cached so a toggle flip can
    /// push without waiting for the next quest.
    private var latest: SharedCharacter?
    private let isDemo: Bool

    private init() {
        isSharing = (UserDefaults.standard.object(forKey: Self.key) as? Bool) ?? true
        isDemo = ProcessInfo.processInfo.arguments.contains("-BRDemoMemberSheet")
    }

    /// Called whenever the player's derived data changes (RootView). Caches the
    /// snapshot and re-publishes it if sharing is on and it actually changed.
    func update(_ snapshot: SharedCharacter) {
        guard latest != snapshot else { return }
        latest = snapshot
        guard isSharing else { return }
        Task { await push() }
    }

    /// Fetches a friend's shared character for their profile sheet. Returns nil
    /// when they're private (no row) or not a friend (RLS returns nothing).
    func fetch(userID: UUID) async -> SharedCharacter? {
        guard !isDemo, SupabaseAPI.shared.currentUserID != nil else { return nil }
        struct Row: Decodable { let character: SharedCharacter }
        do {
            let rows: [Row] = try await SupabaseAPI.shared.select(
                "shared_characters",
                query: [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"),
                        URLQueryItem(name: "select", value: "character")]
            )
            return rows.first?.character
        } catch {
            return nil   // best-effort: a failed fetch just shows the basics
        }
    }

    func signedOut() {
        latest = nil
        errorMessage = nil
    }

    // MARK: - Writing

    /// Sharing on → upsert the cached snapshot; off → delete the row. Skips
    /// nulling when we're on but haven't computed a snapshot yet.
    private func push() async {
        guard !isDemo, let uid = SupabaseAPI.shared.currentUserID else { return }
        do {
            if isSharing {
                guard let latest else { return }
                try await SupabaseAPI.shared.upsert(
                    "shared_characters",
                    values: SharedCharacterRow(userID: uid, character: latest)
                )
            } else {
                try await SupabaseAPI.shared.delete(
                    "shared_characters",
                    query: [URLQueryItem(name: "user_id", value: "eq.\(uid.uuidString)")]
                )
            }
        } catch {
            // Best-effort: a failed share must never interrupt the game.
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
    }
}

/// Upsert row for `shared_characters`. `updated_at` has a DB default.
private struct SharedCharacterRow: Encodable {
    let userID: UUID
    let character: SharedCharacter

    enum CodingKeys: String, CodingKey {
        case character
        case userID = "user_id"
    }
}
