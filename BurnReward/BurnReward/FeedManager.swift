import Combine
import Foundation
import SwiftUI

/// Owns the activity feed: fetching what your party posted, publishing your
/// own wins, and reactions. Opt-in like the rest of the social layer — nothing
/// here runs without a signed-in guild account, and the quest loop never reads
/// it.
///
/// Visibility is **not** enforced here. RLS in `supabase/p2_schema.sql` decides
/// what this client is allowed to see; the queries below simply ask for
/// everything and let the database scope it to the author and accepted
/// friends. That's deliberate — a client-side filter would be advisory, and a
/// modified client would ignore it.
@MainActor
final class FeedManager: ObservableObject {
    /// One feed for the whole app: the GUILD tab shows it, and the share
    /// sheets (which live under other tabs) post into it. A single instance
    /// avoids threading it through four unrelated call sites.
    static let shared = FeedManager()

    @Published private(set) var events: [FeedEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isPosting = false
    @Published var errorMessage: String?

    /// Screenshot fixtures; no network, no account.
    private let isDemo: Bool

    private init() {
        let arguments = ProcessInfo.processInfo.arguments
        isDemo = arguments.contains("-BRDemoFeed")
            || arguments.contains("-BRDemoFeedTail")
            || arguments.contains("-BRDemoPostSheet")
            || arguments.contains("-BRDemoPostPhotos")
        if arguments.contains("-BRDemoFeedTail") {
            events = Array(DemoFeed.events.suffix(3))
        } else if isDemo {
            events = DemoFeed.events
        }
    }

    // MARK: - Reading

    func refresh() async {
        guard !isDemo, let me = SupabaseAPI.shared.currentUserID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [ShareEventRow] = try await SupabaseAPI.shared.select(
                "share_events",
                query: [URLQueryItem(name: "select", value: "*"),
                        URLQueryItem(name: "order", value: "created_at.desc"),
                        URLQueryItem(name: "limit", value: "50")]
            )
            guard !rows.isEmpty else {
                events = []
                return
            }

            // Authors and reactions in one round trip each rather than per row.
            let authors = try await profiles(for: Set(rows.map(\.userID)))
            let reactions = try await reactions(for: rows.map(\.id))

            events = rows.compactMap { row in
                guard let author = authors[row.userID] else { return nil }
                return makeEvent(row: row, author: author,
                                 reactions: reactions[row.id] ?? [], me: me)
            }
            await loadPhotos(for: events)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func profiles(for ids: Set<UUID>) async throws -> [UUID: SocialProfile] {
        guard !ids.isEmpty else { return [:] }
        let list = ids.map(\.uuidString).joined(separator: ",")
        let rows: [SocialProfile] = try await SupabaseAPI.shared.select(
            "profiles",
            query: [URLQueryItem(name: "id", value: "in.(\(list))"),
                    URLQueryItem(name: "select", value: "*")]
        )
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
    }

    private func reactions(for eventIDs: [UUID]) async throws -> [UUID: [ReactionRow]] {
        guard !eventIDs.isEmpty else { return [:] }
        let list = eventIDs.map(\.uuidString).joined(separator: ",")
        let rows: [ReactionRow] = try await SupabaseAPI.shared.select(
            "reactions",
            query: [URLQueryItem(name: "event_id", value: "in.(\(list))"),
                    URLQueryItem(name: "select", value: "*")]
        )
        return Dictionary(grouping: rows, by: \.eventID)
    }

    /// Photos load after the rows so text appears immediately and images fill
    /// in — a feed that waits for every image before showing anything reads as
    /// broken on a slow connection.
    private func loadPhotos(for events: [FeedEvent]) async {
        for event in events where !event.photoPaths.isEmpty {
            var loaded: [UIImage] = []
            for path in event.photoPaths {
                if let image = await PostPhotoCache.shared.load(path) {
                    loaded.append(image)
                }
            }
            guard !loaded.isEmpty,
                  let index = self.events.firstIndex(where: { $0.id == event.id })
            else { continue }
            self.events[index].photos = loaded
        }
    }

    private func makeEvent(row: ShareEventRow, author: SocialProfile,
                           reactions: [ReactionRow], me: UUID) -> FeedEvent? {
        guard let kind = kind(from: row) else { return nil }
        var counts: [Reaction: Int] = [:]
        var mine: Reaction?
        for reaction in reactions {
            guard let value = Reaction(rawValue: reaction.reaction) else { continue }
            counts[value, default: 0] += 1
            if reaction.userID == me { mine = value }
        }
        return FeedEvent(
            id: row.id,
            username: author.username,
            level: author.level,
            title: author.title,
            kind: kind,
            caption: row.caption,
            date: row.createdAt,
            reactions: counts,
            myReaction: mine,
            photoPaths: row.photoPaths,
            isMine: row.userID == me
        )
    }

    private func kind(from row: ShareEventRow) -> FeedEventKind? {
        let payload = row.payload
        switch row.kind {
        case "quest":
            guard let reward = payload.reward else { return nil }
            return .quest(reward: reward,
                          emoji: payload.emoji ?? "🍩",
                          calories: payload.calories ?? 0,
                          seconds: payload.seconds ?? 0,
                          xp: payload.xp ?? 0)
        case "badge":
            guard let id = payload.badgeID else { return nil }
            return .badge(id: id, name: payload.name ?? id)
        case "levelup":
            guard let level = payload.level else { return nil }
            return .levelUp(level: level, title: payload.title ?? "")
        default:
            return nil   // a kind this build doesn't know about is skipped, not crashed
        }
    }

    // MARK: - Posting

    /// Publishes a win. Photos are prepared (downscaled, stripped of EXIF,
    /// screened) and uploaded first; the row is written last so a post never
    /// references a photo that failed to upload.
    func post(kind: String, payload: SharePayload,
              caption rawCaption: String, photos: [UIImage]) async -> Bool {
        guard let me = SupabaseAPI.shared.currentUserID else { return false }
        if let rejection = CaptionFilter.rejection(rawCaption) {
            errorMessage = rejection
            return false
        }
        isPosting = true
        defer { isPosting = false }

        let eventID = UUID()
        var paths: [String] = []
        do {
            for (index, photo) in photos.prefix(3).enumerated() {
                let data = try await PostPhotoPipeline.prepare(photo)
                let path = PostPhotoPipeline.path(user: me, event: eventID, index: index)
                try await SupabaseAPI.shared.upload(
                    bucket: PostPhotoPipeline.bucket, path: path, data: data
                )
                paths.append(path)
            }

            let new = NewShareEvent(id: eventID, userID: me, kind: kind,
                                    payload: payload,
                                    caption: CaptionFilter.clean(rawCaption),
                                    photoPaths: paths)
            let _: [ShareEventRow] = try await SupabaseAPI.shared.insert(
                "share_events", values: [new]
            )
            await refresh()
            return true
        } catch {
            // Don't strand uploaded photos when the row write fails — otherwise
            // they sit in storage forever, costing quota and outliving a post
            // that never existed.
            try? await SupabaseAPI.shared.removeObjects(
                bucket: PostPhotoPipeline.bucket, paths: paths
            )
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ event: FeedEvent) async {
        guard event.isMine else { return }
        do {
            try await SupabaseAPI.shared.delete(
                "share_events",
                query: [URLQueryItem(name: "id", value: "eq.\(event.id.uuidString)")]
            )
            try? await SupabaseAPI.shared.removeObjects(
                bucket: PostPhotoPipeline.bucket, paths: event.photoPaths
            )
            events.removeAll { $0.id == event.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reactions

    /// Optimistic: the tap lands immediately and reconciles on the next
    /// refresh. A reaction is cheap enough that waiting on the network to
    /// animate a button would be the wrong trade.
    func react(_ event: FeedEvent, _ reaction: Reaction) async {
        guard !event.isMine, let me = SupabaseAPI.shared.currentUserID,
              let index = events.firstIndex(where: { $0.id == event.id })
        else { return }

        let previous = events[index].myReaction
        applyLocally(at: index, previous: previous, next: previous == reaction ? nil : reaction)
        guard !isDemo else { return }

        do {
            let query = [
                URLQueryItem(name: "event_id", value: "eq.\(event.id.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(me.uuidString)"),
            ]
            if previous == reaction {
                try await SupabaseAPI.shared.delete("reactions", query: query)
            } else if previous == nil {
                let row = ReactionRow(eventID: event.id, userID: me, reaction: reaction.rawValue)
                let _: [ReactionRow] = try await SupabaseAPI.shared.insert(
                    "reactions", values: [row]
                )
            } else {
                let _: [ReactionRow] = try await SupabaseAPI.shared.update(
                    "reactions", values: ["reaction": reaction.rawValue], query: query
                )
            }
        } catch {
            // Put the UI back where the server still thinks it is.
            applyLocally(at: index, previous: events[index].myReaction, next: previous)
            errorMessage = error.localizedDescription
        }
    }

    private func applyLocally(at index: Int, previous: Reaction?, next: Reaction?) {
        guard events.indices.contains(index) else { return }
        if let previous {
            events[index].reactions[previous, default: 1] -= 1
            if events[index].reactions[previous] == 0 {
                events[index].reactions[previous] = nil
            }
        }
        if let next {
            events[index].reactions[next, default: 0] += 1
        }
        events[index].myReaction = next
    }

    func signedOut() {
        events = []
        PostPhotoCache.shared.clear()
    }
}
