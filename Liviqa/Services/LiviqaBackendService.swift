// LiviqaBackendService.swift — EU-sovereign backend client (NestJS/Scaleway+Ory).
// Implements the existing SupabaseServiceProtocol seam against the sovereign API
// (replaces Supabase for real PII per NFR-SEC-07; Supabase stays sandbox-only),
// and adds the derived-share PUSH the prototype lacked.
//
// FR-SHARE-02 · Liviqa_iOS_Backend_Contract_v01 §5 · openapi.yaml.
// CARDINAL: raw HealthKit samples never leave the device. The only health payload
// that goes out is the DERIVED, scoped package built by DerivedShareBuilder
// (FR-SHARE-01) — no raw samples, no provenance.
import Foundation

// MARK: - Sovereign-only surface (not on the shared protocol)

/// The recipient directory entry the citizen picks when creating a grant
/// (`GET /recipients`).
struct Recipient: Identifiable, Equatable, Sendable {
    let id: String            // backend account id (opaque)
    let displayName: String
    let org: String?
    let role: RecipientRole
}

/// Backend recipient roles (Mode-A). The app consents at group level; the role
/// template tightens scope server-side.
enum RecipientRole: String, Codable, Sendable {
    case clinicalNurse = "clinical_nurse"
    case healthCoach   = "health_coach"
}

/// Capabilities that only exist on the sovereign backend (recipient directory +
/// derived-share push). AppState reaches these via `supabase as? SovereignSharing`,
/// so the rest of the app stays decoupled from the concrete service.
protocol SovereignSharing: Sendable {
    func fetchRecipients() async throws -> [Recipient]

    /// Create a consent grant. `scopeGroups` are GROUP keys (glucose, activity,
    /// sleep, recovery…); the backend expands them to metrics and tightens to the
    /// recipient role template. Returns the new backend grant id.
    @discardableResult
    func createGrant(recipientId: String,
                     role: RecipientRole,
                     scopeGroups: [String],
                     purpose: String?,
                     granularity: [String: String]?,
                     expiry: Date?,
                     delivery: String) async throws -> String

    /// Push (or supersede) the derived, scoped share for a grant
    /// (`PUT /shares/{grantId}`). Body produced by DerivedShareBuilder.
    func pushDerivedShare(grantId: String, _ request: DerivedShareRequest) async throws

    /// Issue a Liviqa Share Receipt (UC-21) for an active grant into the citizen's
    /// My DfG wallet. Provenance-only; returns the wallet offer URL (haip-vci deep
    /// link) to render as a QR / open on-device. `verified` is the on-device
    /// threshold proof (optional — a safe default is used server-side).
    func issueShareReceipt(for grant: WalletGrant, verified: String?) async throws -> URL

    /// Issue the citizen's own "Liviqa Citizen" sign-in credential (UC-A) into
    /// their My DfG wallet. Pseudonymous: role + member id + issue date only.
    /// `validUntil` reflects the SHORT-VALIDITY policy (revocation stand-in).
    func issueCitizenCredential() async throws -> (url: URL, validUntil: Date?)
}

// MARK: - Service

final class LiviqaBackendService: SupabaseServiceProtocol, SovereignSharing, CareConnect, @unchecked Sendable {

    private let baseURL: URL
    private let session: URLSession

    /// Supabase Auth (self-hosted GoTrue, EU). When present, sign-in obtains a
    /// Supabase access-token (JWT) used as the bearer. When `nil` (local dev), the
    /// static `devToken` (seed account) is the identity.
    private let auth: SupabaseAuthClient?

    /// Keychain-backed persistence for the access token (NFR-SEC-01).
    private let tokenStore = SessionTokenStore()

    /// Bearer presented to the backend: a dev seed token (local) or, after
    /// Supabase sign-in, the Supabase access token (persisted in the Keychain).
    private var bearerToken: String?

    /// Derived-UUID → original backend id, populated on fetchGrants so that
    /// revoke / share-push can address grants by their backend path id.
    private var grantBackendIDs: [UUID: String] = [:]
    private let mapLock = NSLock()

    /// Wallet rails (issuance/receipts) live on the sandbox container when the
    /// main backend is prod (same DB + JWT secret — see Config.walletRailBaseURL).
    private var walletRailURL: URL { Config.walletRailBaseURL ?? baseURL }

    init(baseURL: URL, devToken: String? = nil, auth: SupabaseAuthClient? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.auth = auth
        self.session = session
        // With Supabase, restore a previously persisted access token so the citizen
        // stays signed in across launches; locally, the static seed token is it.
        self.bearerToken = auth != nil ? (tokenStore.load() ?? devToken) : devToken
    }

    // MARK: - Auth (Supabase access token in prod; dev seed token locally)

    func signInWithEmail(email: String, password: String) async throws -> UserSession {
        if let auth {
            // Supabase (GoTrue) login → access token becomes the backend bearer.
            let result = try await auth.login(email: email, password: password)
            bearerToken = result.accessToken
            tokenStore.save(result.accessToken)
            let account = try await getMe()
            return UserSession(userId: BackendMapping.stableUUID(account.id), email: account.email ?? email)
        }
        // Local dev: the static seed token IS the identity.
        guard bearerToken != nil else { throw SupabaseError.notAvailable }
        let account = try await getMe()
        return UserSession(userId: BackendMapping.stableUUID(account.id), email: email)
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> UserSession {
        if let auth {
            // Supabase native id_token grant (Sign in with Apple) → access token = bearer.
            let result = try await auth.loginWithApple(idToken: idToken, nonce: nonce)
            bearerToken = result.accessToken
            tokenStore.save(result.accessToken)
            let account = try await getMe()
            return UserSession(userId: BackendMapping.stableUUID(account.id),
                               email: account.email ?? result.email)
        }
        // Local dev (no Supabase): Apple sign-in needs the GoTrue bridge; the static
        // seed token is the only identity, so fall back to it when present.
        guard bearerToken != nil else { throw SupabaseError.notAvailable }
        let account = try await getMe()
        return UserSession(userId: BackendMapping.stableUUID(account.id), email: account.email)
    }

    func signOut() async throws {
        if let auth, let token = bearerToken {
            try? await auth.logout(token: token)
            bearerToken = nil
            tokenStore.clear()
        }
        // Local dev seed tokens are static; nothing to revoke server-side.
    }

    func currentSession() async -> UserSession? {
        // With Supabase, validate the live token; locally, the seed token is enough.
        if let auth, let token = bearerToken {
            guard (try? await auth.user(token: token)) != nil,
                  let account = try? await getMe() else { return nil }
            return UserSession(userId: BackendMapping.stableUUID(account.id), email: account.email)
        }
        guard bearerToken != nil, let account = try? await getMe() else { return nil }
        return UserSession(userId: BackendMapping.stableUUID(account.id), email: account.email)
    }

    // MARK: - Profile  (GET /me)

    func fetchProfile() async throws -> UserProfile {
        let a = try await getMe()
        return UserProfile(id: BackendMapping.stableUUID(a.id),
                           displayName: a.displayName,
                           avatarURL: nil,
                           createdAt: nil,
                           alias: a.alias)
    }

    private func getMe() async throws -> AccountDTO {
        // Rides the care rail: the sandbox backend's /me carries the citizen
        // alias (same DB + JWT as prod) — the alias keeps real names out of calls.
        try await getCare("/me", as: AccountDTO.self)
    }

    // MARK: - Wallet grants  (GET/POST /grants, POST /grants/{id}/revoke)

    func fetchGrants() async throws -> [WalletGrant] {
        let dtos = try await get("/grants", as: [MyGrantDTO].self)
        var map: [UUID: String] = [:]
        let grants = dtos.map { dto -> WalletGrant in
            let uuid = BackendMapping.stableUUID(dto.id)
            map[uuid] = dto.id
            return WalletGrant(
                id: uuid,
                userId: nil,
                recipientName: dto.recipientName,
                recipientType: BackendMapping.recipientType(forRole: dto.recipientRole),
                scopeKeys: dto.scopeKeys,
                isActive: dto.active,
                expiresAt: BackendMapping.parseDate(dto.expiresAt),
                createdAt: BackendMapping.parseDate(dto.createdAt)
            )
        }
        storeBackendIDs(map)
        return grants
    }

    /// Protocol path. The only mutation expressible from a bare `WalletGrant` is
    /// DEACTIVATION → revoke (immediate, one-way, evidenced). Creating or
    /// reactivating needs a recipient id / role / granularity, which a plain
    /// WalletGrant doesn't carry — use `createGrant(...)` for that.
    func upsertGrant(_ grant: WalletGrant) async throws -> WalletGrant {
        guard let backendID = backendID(for: grant.id) else {
            throw SupabaseError.serverError(
                "Creating a grant needs a recipient — use the share flow (createGrant).")
        }
        if grant.isActive {
            // Revocation is one-way; reactivation isn't supported by the backend.
            throw SupabaseError.serverError("A revoked grant cannot be reactivated.")
        }
        let resp = try await post("/grants/\(backendID)/revoke", body: EmptyBody(), as: RevokedDTO.self)
        guard resp.revoked else { throw SupabaseError.serverError("Revoke failed.") }
        var updated = grant
        updated.isActive = false
        return updated
    }

    func fetchEvents(limit: Int) async throws -> [WalletEvent] {
        let dtos = try await get("/ledger?limit=\(limit)", as: [LedgerEventDTO].self)
        return dtos.map { dto in
            WalletEvent(
                id: BackendMapping.stableUUID(dto.id),
                userId: nil,
                eventType: BackendMapping.eventType(dto.type),
                actorName: dto.detail?.actorName ?? dto.detail?.actor ?? "—",
                scopeKeys: dto.detail?.scopeKeys ?? dto.detail?.scope ?? [],
                decision: BackendMapping.decision(dto.type),
                occurredAt: BackendMapping.parseDate(dto.occurredAt) ?? Date()
            )
        }
    }

    // MARK: - Journal (PUT /journal — opt-in, deferred parity)

    func fetchJournalEntries(limit: Int) async throws -> [JournalEntry] { [] }
    func upsertJournalEntry(_ entry: JournalEntry) async throws -> JournalEntry { entry }
    func deleteJournalEntry(id: UUID) async throws {}

    // MARK: - SovereignSharing

    func fetchRecipients() async throws -> [Recipient] {
        let dtos = try await get("/recipients", as: [RecipientDTO].self)
        // Citizens grant to clinical_nurse / health_coach (Mode A). Other directory
        // roles (e.g. analyst) aren't grant targets, so they're filtered from the picker.
        return dtos.compactMap { dto in
            guard let role = RecipientRole(rawValue: dto.role) else { return nil }
            return Recipient(id: dto.id, displayName: dto.displayName, org: dto.org, role: role)
        }
    }

    @discardableResult
    func createGrant(recipientId: String,
                     role: RecipientRole,
                     scopeGroups: [String],
                     purpose: String? = nil,
                     granularity: [String: String]? = nil,
                     expiry: Date? = nil,
                     delivery: String = "live_view") async throws -> String {
        let gran = granularity ?? Dictionary(uniqueKeysWithValues: scopeGroups.map { ($0, "summary") })
        let exp = expiry ?? Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
        let body = CreateGrantDTO(
            recipientId: recipientId,
            recipientRole: role.rawValue,
            purpose: purpose,
            scopeKeys: scopeGroups,
            granularity: gran,
            expiry: BackendMapping.iso(exp),
            delivery: delivery
        )
        let resp = try await post("/grants", body: body, as: IdDTO.self)
        storeBackendIDs([BackendMapping.stableUUID(resp.id): resp.id])
        return resp.id
    }

    func pushDerivedShare(grantId: String, _ request: DerivedShareRequest) async throws {
        _ = try await put("/shares/\(grantId)", body: request, as: IdDTO.self)
    }

    func issueShareReceipt(for grant: WalletGrant, verified: String? = nil) async throws -> URL {
        guard let backendID = backendID(for: grant.id) else {
            throw SupabaseError.serverError("Reload your wallet, then try again.")
        }
        let resp = try await postWalletRail("/issuance/sessions",
                                            body: IssueReceiptBody(grantId: backendID, verified: verified),
                                            as: OfferDTO.self)
        guard let url = URL(string: resp.offerUri) else {
            throw SupabaseError.serverError("The issuer returned an invalid offer.")
        }
        return url
    }

    func issueCitizenCredential() async throws -> (url: URL, validUntil: Date?) {
        let resp = try await postWalletRail("/issuance/citizen-credential",
                                            body: EmptyBody(),
                                            as: OfferDTO.self)
        guard let url = URL(string: resp.offerUri) else {
            throw SupabaseError.serverError("The issuer returned an invalid offer.")
        }
        return (url, BackendMapping.parseDate(resp.validUntil))
    }

    // MARK: - CareConnect (citizen care-team surface)

    func fetchNotifications() async throws -> [CitizenNotification] {
        let resp = try await getCare("/notifications", as: NotificationsDTO.self)
        return resp.items.map {
            CitizenNotification(id: $0.id, kind: Self.notifKind($0.type),
                                text: $0.text, at: BackendMapping.parseDate($0.at))
        }
    }

    func fetchScheduledConsults() async throws -> [ScheduledConsult] {
        struct ApptDTO: Decodable { let id: String; let at: String; let kind: String; let status: String?; let recipientName: String; let recipientOrg: String? }
        let dtos = try await getCare("/appointments", as: [ApptDTO].self)
        return dtos.compactMap { d in
            guard let at = BackendMapping.parseDate(d.at) else { return nil }
            return ScheduledConsult(id: d.id, at: at, kind: d.kind, status: d.status ?? "scheduled",
                                    recipientName: d.recipientName, recipientOrg: d.recipientOrg)
        }
    }

    @discardableResult
    func respondToProposal(id: String, accept: Bool) async throws -> Bool {
        struct R: Decodable { let status: String }
        let r = try await postCare("/appointments/\(id)/\(accept ? "accept" : "decline")", body: EmptyBody(), as: R.self)
        return r.status == "scheduled"
    }

    @discardableResult
    func requestConsult(recipientId: String, at: Date, kind: String) async throws -> ScheduledConsult {
        struct Body: Encodable { let recipientId: String; let at: String; let kind: String }
        struct ApptDTO: Decodable { let id: String; let at: String; let kind: String; let status: String?; let recipientName: String?; let recipientOrg: String? }
        let iso = ISO8601DateFormatter().string(from: at)
        let d = try await postCare("/appointments/request",
                                   body: Body(recipientId: recipientId, at: iso, kind: kind),
                                   as: ApptDTO.self)
        return ScheduledConsult(id: d.id, at: BackendMapping.parseDate(d.at) ?? at, kind: d.kind,
                                status: d.status ?? "proposed:citizen",
                                recipientName: d.recipientName ?? "Care team", recipientOrg: d.recipientOrg)
    }

    func fetchActiveConsults() async throws -> [ConsultSummary] {
        let dtos = try await getCare("/consults/active", as: [ActiveConsultDTO].self)
        return dtos.map { d in
            ConsultSummary(
                id: d.id,
                roomName: d.roomName ?? "liviqa-consult-\(d.id)",
                recipientName: d.recipientName ?? "Care team",
                recipientOrg: d.recipientOrg,
                startedAt: BackendMapping.parseDate(d.startedAt),
                recordingRequested: d.recordingRequested ?? false,
                recordingConsent: d.recordingConsent ?? false)
        }
    }

    @discardableResult
    func joinConsult(id: String) async throws -> String {
        _ = try await postCare("/consults/\(id)/join", body: EmptyBody(), as: ConsultSessionDTO.self)
        return "liviqa-consult-\(id)"     // deterministic room (contract §video)
    }

    @discardableResult
    func setRecordingConsent(consultId: String, consent: Bool) async throws -> Bool {
        let dto = try await postCare("/consults/\(consultId)/recording-consent",
                                 body: ConsentBody(consent: consent), as: ConsultSessionDTO.self)
        return dto.recordingConsent ?? consent
    }

    func fetchThreads() async throws -> [CareThread] {
        let dtos = try await getCare("/threads", as: [ThreadDTO].self)
        return dtos.map {
            CareThread(recipientId: $0.recipientId, recipientName: $0.recipientName,
                       recipientOrg: $0.recipientOrg, unread: $0.unread ?? 0,
                       lastMessageAt: BackendMapping.parseDate($0.lastMessageAt))
        }
    }

    func fetchMessages(recipientId: String) async throws -> [CareMessage] {
        let dtos = try await get("/threads/\(recipientId)/messages", as: [MessageDTO].self)
        return dtos.map { Self.message(from: $0, fallbackSender: .recipient) }
    }

    @discardableResult
    func sendMessage(recipientId: String, body: String) async throws -> CareMessage {
        let dto = try await post("/threads/\(recipientId)/messages",
                                 body: SendMessageBody(body: body), as: MessageDTO.self)
        return Self.message(from: dto, fallbackSender: .citizen)
    }

    func registerPushToken(_ token: String) async throws {
        struct Body: Encodable { let token: String }
        struct Ok: Decodable { let ok: Bool? }
        _ = try await post("/me/push-token", body: Body(token: token), as: Ok.self)
    }

    private static func notifKind(_ t: String) -> CitizenNotification.Kind {
        switch t {
        case "consult":        return .consult
        case "message":        return .message
        case "access_request": return .accessRequest
        default:               return .unknown
        }
    }

    private static func message(from dto: MessageDTO, fallbackSender: CareMessage.Sender) -> CareMessage {
        CareMessage(id: dto.id,
                    sender: CareMessage.Sender(rawValue: dto.sender) ?? fallbackSender,
                    body: dto.body,
                    readAt: BackendMapping.parseDate(dto.readAt),
                    createdAt: BackendMapping.parseDate(dto.createdAt) ?? Date())
    }

    // MARK: - Backend id lookup

    private func backendID(for uuid: UUID) -> String? {
        mapLock.lock(); defer { mapLock.unlock() }
        return grantBackendIDs[uuid]
    }

    private func storeBackendIDs(_ map: [UUID: String]) {
        mapLock.lock(); defer { mapLock.unlock() }
        grantBackendIDs.merge(map) { _, new in new }
    }

    // MARK: - HTTP

    private func get<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        try await send(path, method: "GET", bodyData: nil, as: T.self)
    }
    private func post<B: Encodable, T: Decodable>(_ path: String, body: B, as: T.Type) async throws -> T {
        try await send(path, method: "POST", bodyData: try Self.encoder.encode(body), as: T.self)
    }
    /// POST on the wallet-rail base (sandbox container on prod builds — same DB
    /// + JWT secret as prod, so the same bearer works; see Config.walletRailBaseURL).
    private func postWalletRail<B: Encodable, T: Decodable>(_ path: String, body: B, as: T.Type) async throws -> T {
        try await send(path, method: "POST", bodyData: try Self.encoder.encode(body), as: T.self, base: walletRailURL)
    }
    /// Care-surface calls ride the same rail: the sandbox backend carries the
    /// newer consult behaviour (freshness window, scheduled list, access
    /// notifications) against the SAME database and login as prod.
    private func getCare<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        try await send(path, method: "GET", bodyData: nil, as: T.self, base: walletRailURL)
    }
    private func postCare<B: Encodable, T: Decodable>(_ path: String, body: B, as: T.Type) async throws -> T {
        try await send(path, method: "POST", bodyData: try Self.encoder.encode(body), as: T.self, base: walletRailURL)
    }
    private func put<B: Encodable, T: Decodable>(_ path: String, body: B, as: T.Type) async throws -> T {
        try await send(path, method: "PUT", bodyData: try Self.encoder.encode(body), as: T.self)
    }

    private func send<T: Decodable>(_ path: String, method: String, bodyData: Data?, as: T.Type, base: URL? = nil) async throws -> T {
        guard let url = URL(string: path, relativeTo: base ?? baseURL) else {
            throw SupabaseError.serverError("Bad URL: \(path)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let token = bearerToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let bodyData {
            req.httpBody = bodyData
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: req) }
        catch { throw SupabaseError.serverError(error.localizedDescription) }

        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.serverError("No HTTP response")
        }
        switch http.statusCode {
        case 200...299:
            if data.isEmpty, let empty = EmptyDecodable() as? T { return empty }
            do { return try Self.decoder.decode(T.self, from: data) }
            catch { throw SupabaseError.serverError("Decode \(T.self): \(error.localizedDescription)") }
        case 401:
            throw SupabaseError.notSignedIn
        default:
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw SupabaseError.serverError("HTTP \(http.statusCode): \(msg)")
        }
    }

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()
}

// MARK: - Wire DTOs (match openapi.yaml exactly: string ids, camelCase)

private struct AccountDTO: Decodable {
    let id: String
    let kind: String?
    let role: String?
    let email: String?
    let displayName: String?
    let org: String?
    let alias: String?
}

private struct RecipientDTO: Decodable {
    let id: String
    let displayName: String
    let org: String?
    let role: String
}

private struct MyGrantDTO: Decodable {
    let id: String
    let recipientName: String
    let recipientOrg: String?
    let recipientRole: String
    let purpose: String?
    let scopeKeys: [String]
    let active: Bool
    let delivery: String?
    let expiresAt: String?
    let createdAt: String?
}

private struct LedgerEventDTO: Decodable {
    struct Detail: Decodable {
        let actorName: String?
        let actor: String?
        let scope: [String]?
        let scopeKeys: [String]?
    }
    let id: String
    let type: String
    let grantId: String?
    let detail: Detail?
    let occurredAt: String
}

private struct CreateGrantDTO: Encodable {
    let recipientId: String
    let recipientRole: String
    let purpose: String?
    let scopeKeys: [String]
    let granularity: [String: String]
    let expiry: String
    let delivery: String
}

private struct IdDTO: Decodable { let id: String }
private struct IssueReceiptBody: Encodable { let grantId: String; let verified: String? }
private struct OfferDTO: Decodable { let offerUri: String; let validUntil: String? }
private struct RevokedDTO: Decodable { let revoked: Bool }
private struct EmptyBody: Encodable {}
private struct EmptyDecodable: Decodable {}

// CareConnect wire DTOs (match the citizen routes in Video_and_OAuth_Contract_v01)
private struct NotificationsDTO: Decodable {
    struct Item: Decodable { let id: String; let type: String; let text: String; let at: String? }
    let unread: Int?
    let items: [Item]
}
private struct ActiveConsultDTO: Decodable {
    let id: String
    let roomName: String?
    let recipientName: String?
    let recipientOrg: String?
    let startedAt: String?
    let recordingRequested: Bool?
    let recordingConsent: Bool?
}
private struct ConsultSessionDTO: Decodable {
    let id: String
    let recordingRequested: Bool?
    let recordingConsent: Bool?
    let citizenJoinedAt: String?
    let status: String?
}
private struct ThreadDTO: Decodable {
    let recipientId: String
    let recipientName: String
    let recipientOrg: String?
    let unread: Int?
    let lastMessageAt: String?
}
private struct MessageDTO: Decodable {
    let id: String
    let sender: String
    let body: String
    let readAt: String?
    let createdAt: String
}
private struct ConsentBody: Encodable { let consent: Bool }
private struct SendMessageBody: Encodable { let body: String }
