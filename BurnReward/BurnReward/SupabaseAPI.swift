import CryptoKit
import Foundation
import Security

/// Thin, dependency-free client for BurnReward's Supabase backend (social
/// layer only — the core loop never touches this). Deliberately hand-rolled
/// over the plain REST APIs instead of pulling in supabase-swift: the surface
/// we need is three auth endpoints + PostgREST CRUD, and shipping zero
/// third-party code keeps the privacy story exactly as audited. Revisit at
/// P2 if the realtime feed justifies the real SDK.
///
/// Security model: this file knows only the publishable key (safe in the
/// binary by design). Row-Level Security in `supabase/p1_schema.sql` is the
/// actual boundary — every request runs as the signed-in user, nothing more.
///
/// `@MainActor` like every other manager in the app (the project builds with
/// default MainActor isolation); network calls await off-thread via
/// URLSession, so nothing here blocks the UI.
@MainActor
final class SupabaseAPI {
    static let shared = SupabaseAPI()

    private let baseURL = URL(string: "https://djofkmbxtzxdljongnqu.supabase.co")!
    private let publishableKey = "sb_publishable_2ZXntTG_lcclsg2t1z1Qdw_vGWxMC32"

    private var session: SupabaseSession?
    private let urlSession = URLSession.shared

    private init() {
        session = SessionKeychain.load()
    }

    // MARK: - Session state

    var isSignedIn: Bool { session != nil }
    var currentUserID: UUID? { session?.userID }

    enum APIError: LocalizedError {
        case notSignedIn
        case http(Int, String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .notSignedIn:            "You're not signed in."
            case .http(let code, let m):  "Server error \(code) — \(m)"
            case .badResponse:            "Unexpected server response."
            }
        }
    }

    // MARK: - Auth (GoTrue)

    /// Native Sign in with Apple: exchange Apple's identity token for a
    /// Supabase session. `rawNonce` is the value whose SHA-256 was set on the
    /// ASAuthorization request.
    func signInWithApple(idToken: String, rawNonce: String) async throws {
        var request = URLRequest(url: authURL(grantType: "id_token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode([
            "provider": "apple",
            "id_token": idToken,
            "nonce": rawNonce,
        ])
        let data = try await perform(request)
        try adoptSession(from: data)
    }

    func signOut() async {
        if let token = session?.accessToken {
            var request = URLRequest(url: baseURL.appending(path: "/auth/v1/logout"))
            request.httpMethod = "POST"
            request.setValue(publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await perform(request)
        }
        session = nil
        SessionKeychain.clear()
    }

    /// Valid bearer token, refreshing first when close to expiry.
    private func freshAccessToken() async throws -> String {
        guard let current = session else { throw APIError.notSignedIn }
        if current.expiresAt.timeIntervalSinceNow > 60 { return current.accessToken }

        var request = URLRequest(url: authURL(grantType: "refresh_token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(["refresh_token": current.refreshToken])
        do {
            let data = try await perform(request)
            try adoptSession(from: data)
        } catch {
            // A dead refresh token means the account state is gone server-side;
            // fall back to signed-out rather than looping.
            session = nil
            SessionKeychain.clear()
            throw APIError.notSignedIn
        }
        guard let refreshed = session else { throw APIError.notSignedIn }
        return refreshed.accessToken
    }

    private func authURL(grantType: String) -> URL {
        var components = URLComponents(
            url: baseURL.appending(path: "/auth/v1/token"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "grant_type", value: grantType)]
        return components.url!
    }

    private func adoptSession(from data: Data) throws {
        struct TokenResponse: Decodable {
            struct User: Decodable { let id: UUID }
            let access_token: String
            let refresh_token: String
            let expires_in: Double
            let user: User
        }
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        let adopted = SupabaseSession(
            accessToken: token.access_token,
            refreshToken: token.refresh_token,
            expiresAt: Date().addingTimeInterval(token.expires_in),
            userID: token.user.id
        )
        session = adopted
        SessionKeychain.save(adopted)
    }

    // MARK: - PostgREST

    func select<Row: Decodable>(_ table: String, query: [URLQueryItem]) async throws -> [Row] {
        let data = try await rest("GET", table: table, query: query, body: nil as Never?)
        return try decoder.decode([Row].self, from: data)
    }

    @discardableResult
    func insert<Value: Encodable, Row: Decodable>(_ table: String, values: Value) async throws -> [Row] {
        let data = try await rest("POST", table: table, query: [], body: values)
        return try decoder.decode([Row].self, from: data)
    }

    /// Insert into a write-only table (no select policy — e.g. `reports`).
    /// The default insert asks for the row back, and RETURNING needs select
    /// rights the caller deliberately doesn't have — this one doesn't ask.
    func insertNoEcho<Value: Encodable>(_ table: String, values: Value) async throws {
        _ = try await rest("POST", table: table, query: [], body: values,
                           prefer: "return=minimal")
    }

    @discardableResult
    func update<Value: Encodable, Row: Decodable>(
        _ table: String, values: Value, query: [URLQueryItem]
    ) async throws -> [Row] {
        let data = try await rest("PATCH", table: table, query: query, body: values)
        return try decoder.decode([Row].self, from: data)
    }

    func delete(_ table: String, query: [URLQueryItem]) async throws {
        _ = try await rest("DELETE", table: table, query: query, body: nil as Never?)
    }

    // MARK: - Storage

    /// Uploads bytes to a private bucket. `path` must start with the signed-in
    /// user's id — the storage policies in `p2_schema.sql` reject anything
    /// else, so a modified client can't write into someone else's folder.
    func upload(bucket: String, path: String, data: Data,
                contentType: String = "image/jpeg") async throws {
        let token = try await freshAccessToken()
        var request = URLRequest(
            url: baseURL.appending(path: "/storage/v1/object/\(bucket)/\(path)")
        )
        request.httpMethod = "POST"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try await perform(request)
    }

    /// Downloads a private object. Reads are authorized per-request, so a path
    /// alone is never enough to see someone's photo — RLS still has to agree
    /// that you're a friend of the owner.
    func download(bucket: String, path: String) async throws -> Data {
        let token = try await freshAccessToken()
        var request = URLRequest(
            url: baseURL.appending(path: "/storage/v1/object/\(bucket)/\(path)")
        )
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func removeObjects(bucket: String, paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        let token = try await freshAccessToken()
        var request = URLRequest(url: baseURL.appending(path: "/storage/v1/object/\(bucket)"))
        request.httpMethod = "DELETE"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["prefixes": paths])
        _ = try await perform(request)
    }

    // MARK: - REST plumbing

    private func rest<Body: Encodable>(
        _ method: String, table: String, query: [URLQueryItem], body: Body?,
        prefer: String = "return=representation"
    ) async throws -> Data {
        let token = try await freshAccessToken()
        var components = URLComponents(
            url: baseURL.appending(path: "/rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(prefer, forHTTPHeaderField: "Prefer")
        if let body {
            request.httpBody = try encoder.encode(body)
        }
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(http.statusCode, String(message.prefix(300)))
        }
        return data
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Postgres emits timestamptz with microseconds ("…T08:19:40.123456+00")
        // sometimes and without them other times, and plain `.iso8601` rejects
        // the fractional form. A mismatch would throw mid-decode and take the
        // whole response with it, so try both rather than trust one shape.
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = PostgresTimestamp.parse(text) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unrecognized timestamp: \(text)"
            ))
        }
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

// MARK: - Timestamps

/// Parses the two shapes Postgres hands back for `timestamptz`.
///
/// The formatters are shared rather than rebuilt per value — constructing an
/// `ISO8601DateFormatter` for every row in a feed is measurably wasteful.
/// `nonisolated(unsafe)` is sound here: Foundation's date formatters are
/// documented thread-safe for parsing, and these two are configured once at
/// init and never mutated afterwards.
private enum PostgresTimestamp {
    nonisolated(unsafe) private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let plain = ISO8601DateFormatter()

    static func parse(_ text: String) -> Date? {
        withFraction.date(from: text) ?? plain.date(from: text)
    }
}

// MARK: - Cancellation

extension Error {
    /// Whether this is "the work was cancelled" rather than "the work failed".
    ///
    /// SwiftUI cancels `.task` and `.refreshable` work as a matter of course —
    /// switching tabs, backgrounding, letting go of a pull-to-refresh early.
    /// Every one of those surfaced as a "cancelled" alert until this existed.
    /// A cancellation is the app doing what it was told; the player has no
    /// action to take and shouldn't be interrupted.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}

// MARK: - Nonce helpers (Sign in with Apple)

enum AppleNonce {
    /// Cryptographically random raw nonce; its SHA-256 goes on the Apple
    /// request, the raw value goes to Supabase.
    static func random() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Session persistence

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: UUID
}

/// One generic-password item; tokens never live in UserDefaults.
private enum SessionKeychain {
    private static let service = "com.burnrewardapp.app.supabase"
    private static let account = "session"

    static func save(_ session: SupabaseSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load() -> SupabaseSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Row models (match supabase/p1_schema.sql)

struct SocialProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String
    var avatarKind: String
    var avatarRef: String?
    var level: Int
    var title: String
    var badgeIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id, username, level, title
        case avatarKind = "avatar_kind"
        case avatarRef = "avatar_ref"
        case badgeIDs = "badge_ids"
    }
}

struct FriendshipRow: Codable, Hashable {
    let requester: UUID
    let addressee: UUID
    var status: String
    /// Who flipped the pair to 'blocked' — only they can undo it (p4a).
    /// Optional so decoding survives a database that predates the migration.
    var blockedBy: UUID?
    /// When the relationship last changed — i.e. when it was accepted, which
    /// is what dates the "joined your party" alert.
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case requester, addressee, status
        case blockedBy = "blocked_by"
        case updatedAt = "updated_at"
    }
}

// MARK: - Row models (match supabase/p2_schema.sql)

/// A post. `payload` holds only the summary fields for its kind — never raw
/// HealthKit samples, heart rate, routes, or exact workout timestamps.
struct ShareEventRow: Codable, Identifiable, Hashable {
    let id: UUID
    let userID: UUID
    let kind: String
    let payload: SharePayload
    let caption: String?
    let photoPaths: [String]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, payload, caption
        case userID = "user_id"
        case photoPaths = "photo_paths"
        case createdAt = "created_at"
    }
}

/// The union of every kind's fields — each post fills in only its own. Kept
/// flat and optional rather than an enum so PostgREST's jsonb round-trips
/// without a custom decoder.
struct SharePayload: Codable, Hashable {
    // quest
    var reward: String?
    var emoji: String?
    var calories: Int?
    var seconds: Int?
    var xp: Int?
    // badge
    var badgeID: String?
    var name: String?
    // levelup
    var level: Int?
    var title: String?

    enum CodingKeys: String, CodingKey {
        case reward, emoji, calories, seconds, xp, name, level, title
        case badgeID = "badge_id"
    }
}

/// What a post is being created with. Separate from `ShareEventRow` because
/// the server fills in id and created_at.
struct NewShareEvent: Encodable {
    let id: UUID
    let userID: UUID
    let kind: String
    let payload: SharePayload
    let caption: String?
    let photoPaths: [String]

    enum CodingKeys: String, CodingKey {
        case id, kind, payload, caption
        case userID = "user_id"
        case photoPaths = "photo_paths"
    }
}

struct ReactionRow: Codable, Hashable {
    let eventID: UUID
    let userID: UUID
    var reaction: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case reaction
        case eventID = "event_id"
        case userID = "user_id"
        case createdAt = "created_at"
    }

    /// Inserts must not send `created_at` — the column has a default and the
    /// row is rejected if the client tries to set it.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventID, forKey: .eventID)
        try container.encode(userID, forKey: .userID)
        try container.encode(reaction, forKey: .reaction)
    }
}
