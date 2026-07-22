import AuthenticationServices
import Combine
import Foundation
import SwiftUI

/// Owns the social layer's state and every call into Supabase. Opt-in by
/// construction: nothing here runs until the player signs in, and the core
/// quest loop never reads it.
///
/// What can leave the device, all of it user-chosen: username, level, title,
/// badge ids. Never raw HealthKit samples, heart rate, or routes — the
/// summary-only wire from SOCIAL.md.
@MainActor
final class GuildManager: ObservableObject {
    enum Phase: Equatable {
        case signedOut
        case needsUsername
        case ready
    }

    @Published private(set) var phase: Phase = .signedOut
    @Published private(set) var me: SocialProfile?
    @Published private(set) var friends: [SocialProfile] = []
    @Published private(set) var incoming: [SocialProfile] = []
    @Published private(set) var outgoingIDs: Set<UUID> = []
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    /// Demo seeding for simulator screenshots — no network, no session.
    private let isDemo: Bool
    private var currentNonce: String?

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        isDemo = arguments.contains("-BRDemoGuild")
            || arguments.contains("-BRDemoGuildClaim")
            || arguments.contains("-BRDemoAddFriend")
            || arguments.contains("-BRDemoFeed")
            || arguments.contains("-BRDemoParty")
            || arguments.contains("-BRDemoFeedEmpty")
            || arguments.contains("-BRDemoPostSheet")
            || arguments.contains("-BRDemoFeedTail")
            || arguments.contains("-BRDemoPostPhotos")
            || arguments.contains("-BRDemoReportSheet")
            || arguments.contains("-BRDemoBlockConfirm")
            || arguments.contains("-BRDemoMemberSheet")
            || arguments.contains("-BRDemoLeaderboard")
            || arguments.contains("-BRDemoLeaderboardJoin")
        if arguments.contains("-BRDemoGuildClaim") {
            phase = .needsUsername
        } else if arguments.contains("-BRDemoFeedEmpty") {
            // Signed in, nobody recruited yet — the day-one feed.
            phase = .ready
            me = DemoGuild.me
        } else if isDemo {
            phase = .ready
            me = DemoGuild.me
            friends = DemoGuild.friends
            incoming = DemoGuild.incoming
        }
    }

    // MARK: - Session

    /// Restores an existing Keychain session at launch. Signed-out is the
    /// normal, silent outcome — never an error state.
    func restore() async {
        guard !isDemo, SupabaseAPI.shared.isSignedIn else { return }
        await loadGuild()
    }

    /// Configures the Apple request: a fresh nonce (SHA-256 on the wire, raw
    /// kept for the Supabase exchange). Email scope only — Apple's private
    /// relay hides the real address, and the in-app identity is the username.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleNonce.random()
        currentNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = AppleNonce.sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            // Diagnostic: surface the exact underlying failure in the console
            // ("SIWA failure" filter) — Apple's sheet hides the reason.
            let nsError = error as NSError
            print("SIWA failure — domain: \(nsError.domain), code: \(nsError.code), userInfo: \(nsError.userInfo)")
            // The user cancelling the sheet isn't an error worth shouting about.
            guard (error as? ASAuthorizationError)?.code != .canceled,
                  !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Apple didn't return a usable sign-in token."
                return
            }
            isWorking = true
            defer { isWorking = false }
            do {
                try await SupabaseAPI.shared.signInWithApple(idToken: idToken, rawNonce: nonce)
                currentNonce = nil
                await loadGuild()
            } catch {
                guard !error.isCancellation else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() async {
        await SupabaseAPI.shared.signOut()
        phase = .signedOut
        me = nil
        friends = []
        incoming = []
        outgoingIDs = []
        // Nothing social survives sign-out: the feed, the cached photos, the
        // bell's guild rows, and the challenge board all belong to the account
        // that just left.
        FeedManager.shared.signedOut()
        SocialAlertStore.shared.clear()
        LeaderboardManager.shared.signedOut()
        CharacterShare.shared.signedOut()
    }

    /// Permanently deletes the account (Apple 5.1.1(v)). The Edge Function
    /// (service role, server-side) removes the auth user + all shared data +
    /// storage photos; on success we tear down the local session and state,
    /// leaving the app in its account-free solo mode. Returns whether it ran.
    func deleteAccount() async -> Bool {
        guard SupabaseAPI.shared.currentUserID != nil else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await SupabaseAPI.shared.callFunction("delete-account")
            // The account and its server data are gone; clear everything local.
            await signOut()
            return true
        } catch {
            guard !error.isCancellation else { return false }
            errorMessage = "Couldn't delete your account. Please try again — \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Loading

    /// Signed in with no profile row yet → the username claim screen. This is
    /// the only thing that decides `.needsUsername`, so a dropped network call
    /// can't strand a claimed player on the claim screen (it surfaces an error
    /// instead).
    func loadGuild() async {
        guard !isDemo, let uid = SupabaseAPI.shared.currentUserID else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let rows: [SocialProfile] = try await SupabaseAPI.shared.select(
                "profiles",
                query: [URLQueryItem(name: "id", value: "eq.\(uid)"),
                        URLQueryItem(name: "select", value: "*")]
            )
            guard let profile = rows.first else {
                phase = .needsUsername
                return
            }
            me = profile
            phase = .ready
            await loadFriendships(uid: uid)
            await SocialAlertStore.shared.refresh()
        } catch SupabaseAPI.APIError.notSignedIn {
            phase = .signedOut
        } catch {
            guard !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadFriendships(uid: UUID) async {
        do {
            let rows: [FriendshipRow] = try await SupabaseAPI.shared.select(
                "friendships",
                query: [URLQueryItem(name: "select", value: "*")]  // RLS scopes this to me
            )
            let accepted = rows.filter { $0.status == "accepted" }
            let pendingIn = rows.filter { $0.status == "pending" && $0.addressee == uid }
            let pendingOut = rows.filter { $0.status == "pending" && $0.requester == uid }
            outgoingIDs = Set(pendingOut.map(\.addressee))

            let friendIDs = accepted.map { $0.requester == uid ? $0.addressee : $0.requester }
            let requesterIDs = pendingIn.map(\.requester)
            let profiles = try await fetchProfiles(ids: friendIDs + requesterIDs)
            let byID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            friends = friendIDs.compactMap { byID[$0] }.sorted { $0.level > $1.level }
            incoming = requesterIDs.compactMap { byID[$0] }
        } catch {
            guard !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func fetchProfiles(ids: [UUID]) async throws -> [SocialProfile] {
        guard !ids.isEmpty else { return [] }
        let list = ids.map(\.uuidString).joined(separator: ",")
        return try await SupabaseAPI.shared.select(
            "profiles",
            query: [URLQueryItem(name: "id", value: "in.(\(list))"),
                    URLQueryItem(name: "select", value: "*")]
        )
    }

    // MARK: - Username

    static func validate(username: String) -> String? {
        let name = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard name.count >= 3 else { return "At least 3 characters." }
        guard name.count <= 16 else { return "16 characters max." }
        guard name.range(of: "^[a-z0-9_]+$", options: .regularExpression) != nil else {
            return "Lowercase letters, numbers, and underscores only."
        }
        return nil
    }

    /// Claims a name by inserting the profile row. Uniqueness is the database's
    /// unique index, not a check-then-write — two players racing for the same
    /// name can't both win.
    func claim(username: String, level: Int, title: String, badgeIDs: [String]) async {
        guard let uid = SupabaseAPI.shared.currentUserID else { return }
        let name = username.trimmingCharacters(in: .whitespaces).lowercased()
        if let problem = Self.validate(username: name) {
            errorMessage = problem
            return
        }
        isWorking = true
        defer { isWorking = false }

        struct NewProfile: Encodable {
            let id: UUID
            let username: String
            let level: Int
            let title: String
            let badge_ids: [String]
        }
        do {
            let created: [SocialProfile] = try await SupabaseAPI.shared.insert(
                "profiles",
                values: NewProfile(id: uid, username: name, level: level,
                                   title: title, badge_ids: badgeIDs)
            )
            me = created.first
            phase = .ready
        } catch SupabaseAPI.APIError.http(let code, let body) {
            // 23505 = unique violation: the name is taken.
            errorMessage = (code == 409 || body.contains("23505"))
                ? "@\(name) is taken. Try another."
                : "Couldn't claim that name — \(body.prefix(120))"
        } catch {
            guard !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Pushes the locally-derived game identity up so friends see it current.
    /// Only ever level/title/badges — the summary-only wire.
    func syncProfile(level: Int, title: String, badgeIDs: [String]) async {
        guard !isDemo, phase == .ready, let uid = SupabaseAPI.shared.currentUserID,
              let current = me else { return }
        guard current.level != level || current.title != title
                || current.badgeIDs != badgeIDs else { return }

        struct ProfilePatch: Encodable {
            let level: Int
            let title: String
            let badge_ids: [String]
        }
        do {
            let updated: [SocialProfile] = try await SupabaseAPI.shared.update(
                "profiles",
                values: ProfilePatch(level: level, title: title, badge_ids: badgeIDs),
                query: [URLQueryItem(name: "id", value: "eq.\(uid)")]
            )
            if let profile = updated.first { me = profile }
        } catch {
            // Best-effort: a failed sync must never interrupt the game.
        }
    }

    // MARK: - Friends

    func search(username: String) async -> SocialProfile? {
        let name = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return nil }
        isWorking = true
        defer { isWorking = false }
        do {
            let rows: [SocialProfile] = try await SupabaseAPI.shared.select(
                "profiles",
                query: [URLQueryItem(name: "username", value: "eq.\(name)"),
                        URLQueryItem(name: "select", value: "*")]
            )
            return rows.first
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
            return nil
        }
    }

    func sendRequest(to profile: SocialProfile) async {
        guard let uid = SupabaseAPI.shared.currentUserID, profile.id != uid else { return }
        struct NewFriendship: Encodable {
            let requester: UUID
            let addressee: UUID
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let _: [FriendshipRow] = try await SupabaseAPI.shared.insert(
                "friendships", values: NewFriendship(requester: uid, addressee: profile.id)
            )
            outgoingIDs.insert(profile.id)
        } catch SupabaseAPI.APIError.http(let code, _) where code == 409 || code == 403 {
            // The RLS insert policy also refuses duplicates and blocked pairs;
            // either way there's nothing useful to say beyond this.
            errorMessage = "You've already got a request with @\(profile.username)."
        } catch {
            guard !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func accept(_ profile: SocialProfile) async {
        guard let uid = SupabaseAPI.shared.currentUserID else { return }
        struct StatusPatch: Encodable { let status: String }
        do {
            let _: [FriendshipRow] = try await SupabaseAPI.shared.update(
                "friendships",
                values: StatusPatch(status: "accepted"),
                query: [URLQueryItem(name: "requester", value: "eq.\(profile.id)"),
                        URLQueryItem(name: "addressee", value: "eq.\(uid)")]
            )
            await loadFriendships(uid: uid)
        } catch {
            guard !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func decline(_ profile: SocialProfile) async {
        guard let uid = SupabaseAPI.shared.currentUserID else { return }
        do {
            try await SupabaseAPI.shared.delete(
                "friendships",
                query: [URLQueryItem(name: "requester", value: "eq.\(profile.id)"),
                        URLQueryItem(name: "addressee", value: "eq.\(uid)")]
            )
            incoming.removeAll { $0.id == profile.id }
        } catch {
            guard !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Unfriend — either side may sever, so one delete covers both directions.
    func remove(_ profile: SocialProfile) async {
        guard let uid = SupabaseAPI.shared.currentUserID else { return }
        do {
            try await SupabaseAPI.shared.delete(
                "friendships",
                query: [URLQueryItem(name: "or", value:
                    "(and(requester.eq.\(uid),addressee.eq.\(profile.id)),"
                    + "and(requester.eq.\(profile.id),addressee.eq.\(uid)))")]
            )
            friends.removeAll { $0.id == profile.id }
        } catch {
            guard !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }
}

/// Screenshot fixtures — ProcessInfo-gated, never reachable in a real install.
enum DemoGuild {
    static let me = SocialProfile(
        id: UUID(), username: "xavier_pr", avatarKind: "pixel", avatarRef: "flame",
        level: 6, title: "SNACK SLAYER",
        badgeIDs: ["first_burn", "decade", "spark", "inferno"]
    )
    static let friends = [
        SocialProfile(id: UUID(), username: "mika_runs", avatarKind: "pixel", avatarRef: "bolt",
                      level: 8, title: "DUNGEON DINER", badgeIDs: ["first_burn", "trailblazer"]),
        SocialProfile(id: UUID(), username: "carlos_lifts", avatarKind: "pixel", avatarRef: "sword",
                      level: 4, title: "TREAT APPRENTICE", badgeIDs: ["first_burn"]),
        SocialProfile(id: UUID(), username: "ana_walks", avatarKind: "pixel", avatarRef: "boot",
                      level: 11, title: "FEAST PHANTOM", badgeIDs: ["first_burn", "legend"]),
    ]
    static let incoming = [
        SocialProfile(id: UUID(), username: "pedro_bikes", avatarKind: "pixel", avatarRef: "wheel",
                      level: 3, title: "SNACK ROOKIE", badgeIDs: []),
    ]
}
