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

/// Password recovery (e-mail reset link) — carried by the sovereign service when
/// GoTrue auth is configured. AuthView reaches it via `supabase as? PasswordRecovery`,
/// so mock/sandbox services simply don't offer the affordance.
protocol PasswordRecovery: Sendable {
    /// Ask the auth server to e-mail a reset link. Succeeds even for unknown
    /// emails (no account enumeration) — keep the confirmation copy conditional.
    func requestPasswordReset(email: String) async throws
}

// MARK: - Service

final class LiviqaBackendService: SupabaseServiceProtocol, SovereignSharing, CareConnect, DataRights, PasswordRecovery, @unchecked Sendable {

    private let baseURL: URL
    private let session: URLSession

    /// Supabase Auth (self-hosted GoTrue, EU). When present, sign-in obtains a
    /// Supabase access-token (JWT) used as the bearer. When `nil` (local dev), the
    /// static `devToken` (seed account) is the identity.
    private let auth: SupabaseAuthClient?

    /// Keychain-backed persistence for the access token (NFR-SEC-01).
    private let tokenStore = SessionTokenStore()
    /// The GoTrue refresh token, same Keychain, its own slot — the real session
    /// (access tokens are short-lived; a 401 triggers one silent refresh).
    private let refreshStore = SessionTokenStore(account: "auth.refresh_token")

    /// Bearer presented to the backend: a dev seed token (local) or, after
    /// Supabase sign-in, the Supabase access token (persisted in the Keychain).
    private var bearerToken: String?

    /// One in-flight refresh at a time — concurrent 401s collapse onto the same
    /// Task instead of stampeding GoTrue (which rotates the refresh token).
    private var refreshTask: Task<String?, Never>?

    /// Derived-UUID → original backend id, populated on fetchGrants so that
    /// revoke / share-push can address grants by their backend path id.
    private var grantBackendIDs: [UUID: String] = [:]
    private let mapLock = NSLock()

    /// Wallet rails (issuance/receipts) live on the sandbox container when the
    /// main backend is prod (same DB + JWT secret — see Config.walletRailBaseURL).
    private var walletRailURL: URL { Config.walletRailBaseURL ?? baseURL }

    /// Default session with sane timeouts (URLSession.shared waits 60 s per
    /// request) — a dead network fails fast into friendly copy, not a spinner.
    static let defaultSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 30
        return URLSession(configuration: c)
    }()

    init(baseURL: URL, devToken: String? = nil, auth: SupabaseAuthClient? = nil,
         session: URLSession = LiviqaBackendService.defaultSession) {
        self.baseURL = baseURL
        self.auth = auth
        self.session = session
        // With Supabase, restore a previously persisted access token so the citizen
        // stays signed in across launches; locally, the static seed token is it.
        self.bearerToken = auth != nil ? (tokenStore.load() ?? devToken) : devToken
    }

    /// Adopt a GoTrue session: bearer in memory + both tokens in the Keychain
    /// (GoTrue rotates the refresh token on every refresh, so always overwrite).
    private func adoptSession(_ result: SupabaseSessionResult) {
        bearerToken = result.accessToken
        tokenStore.save(result.accessToken)
        refreshStore.save(result.refreshToken)
    }

    // MARK: - Auth (Supabase access token in prod; dev seed token locally)

    func signInWithEmail(email: String, password: String) async throws -> UserSession {
        if let auth {
            // Supabase (GoTrue) login → access token becomes the backend bearer.
            let result = try await auth.login(email: email, password: password)
            adoptSession(result)
            let account = try await getMe()
            return UserSession(userId: BackendMapping.stableUUID(account.id), email: account.email ?? email)
        }
        // Local dev: the static seed token IS the identity.
        guard bearerToken != nil else { throw SupabaseError.notAvailable }
        let account = try await getMe()
        return UserSession(userId: BackendMapping.stableUUID(account.id), email: email)
    }

    func signUpWithEmail(email: String, password: String) async throws -> UserSession {
        if let auth {
            // GoTrue signup (autoconfirm → session) → the first authenticated /me
            // auto-provisions the citizen account server-side (OPEN_CITIZEN_SIGNUP).
            let result = try await auth.signup(email: email, password: password)
            adoptSession(result)
            let account = try await getMe()
            return UserSession(userId: BackendMapping.stableUUID(account.id), email: account.email ?? email)
        }
        // Local dev has no registration surface; the seed token is the identity.
        throw SupabaseError.notAvailable
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> UserSession {
        if let auth {
            // Supabase native id_token grant (Sign in with Apple) → access token = bearer.
            let result = try await auth.loginWithApple(idToken: idToken, nonce: nonce)
            adoptSession(result)
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
            refreshStore.clear()
        }
        // Local dev seed tokens are static; nothing to revoke server-side.
    }

    func currentSession() async -> UserSession? {
        // With Supabase, validate the live token; locally, the seed token is enough.
        if let auth, let token = bearerToken {
            // Access tokens are short-lived: an expired one gets ONE silent
            // refresh before the citizen is treated as signed out.
            if (try? await auth.user(token: token)) == nil,
               await refreshSession() == nil { return nil }
            guard let account = try? await getMe() else { return nil }
            return UserSession(userId: BackendMapping.stableUUID(account.id), email: account.email)
        }
        guard bearerToken != nil, let account = try? await getMe() else { return nil }
        return UserSession(userId: BackendMapping.stableUUID(account.id), email: account.email)
    }

    /// PasswordRecovery — GoTrue e-mails the reset link (standard template).
    func requestPasswordReset(email: String) async throws {
        guard let auth else { throw SupabaseError.notAvailable }
        try await auth.recover(email: email)
    }

    /// Silent refresh, single-flight: trade the Keychained refresh token for a
    /// fresh session. Returns the new access token, or nil when there is no
    /// refresh token / GoTrue rejects it (⇒ the citizen is really signed out).
    private func refreshSession() async -> String? {
        let task = joinOrStartRefresh()
        let token = await task.value
        clearRefreshTask(task)
        return token
    }

    /// Lock-guarded section, kept synchronous (NSLock is not await-safe):
    /// join the in-flight refresh Task or start the one and only.
    private func joinOrStartRefresh() -> Task<String?, Never> {
        mapLock.lock(); defer { mapLock.unlock() }
        if let running = refreshTask { return running }
        let auth = self.auth
        let refreshStore = self.refreshStore
        let task = Task<String?, Never> { [weak self] in
            guard let auth,
                  let refresh = refreshStore.load(), !refresh.isEmpty,
                  let result = try? await auth.refresh(refreshToken: refresh)
            else { return nil }
            self?.adoptSession(result)           // rotated refresh token included
            return result.accessToken
        }
        refreshTask = task
        return task
    }

    private func clearRefreshTask(_ task: Task<String?, Never>) {
        mapLock.lock(); defer { mapLock.unlock() }
        if refreshTask == task { refreshTask = nil }
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
                createdAt: BackendMapping.parseDate(dto.createdAt),
                ceGrantRef: dto.ceGrantRef
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
        return dtos.map(Self.walletEvent(from:))
    }

    /// Pure DTO→domain mapping (internal so `ReceiptDecodeTests` can exercise
    /// the ce evidence decode without URLSession).
    static func walletEvent(from dto: LedgerEventDTO) -> WalletEvent {
        WalletEvent(
            id: BackendMapping.stableUUID(dto.id),
            userId: nil,
            eventType: BackendMapping.eventType(dto.type),
            actorName: dto.detail?.actorName ?? dto.detail?.actor ?? "—",
            scopeKeys: dto.detail?.scopeKeys ?? dto.detail?.scope ?? [],
            decision: BackendMapping.decision(dto.type),
            occurredAt: BackendMapping.parseDate(dto.occurredAt) ?? Date(),
            ce: dto.detail?.ce
        )
    }

    // MARK: - Journal (GET/PUT /journal · DELETE /journal/{id} — opt-in sync)
    // T1 TestProd wave: the former stub trio (fetch→[], upsert echo, delete
    // no-op) silently discarded synced entries. These are now the real citizen
    // journal routes. The server stores TEXT + timestamp only; mood/tags/metric
    // snapshots stay device-local by design (never uploaded).

    /// Local-UUID → backend journal id, so update/delete address the server row.
    private var journalBackendIDs: [UUID: String] = [:]

    func fetchJournalEntries(limit: Int) async throws -> [JournalEntry] {
        let dtos = try await get("/journal", as: [JournalEntryDTO].self)
        var map: [UUID: String] = [:]
        let entries = dtos.prefix(max(limit, 0)).map { dto -> JournalEntry in
            let entry = BackendMapping.journalEntry(from: dto)
            map[entry.id] = dto.id
            return entry
        }
        mapLock.lock()
        journalBackendIDs.merge(map) { _, new in new }
        mapLock.unlock()
        return Array(entries)
    }

    func upsertJournalEntry(_ entry: JournalEntry) async throws -> JournalEntry {
        let backendID = journalBackendID(for: entry.id)
        let body = JournalUpsertBody(id: backendID,
                                     text: entry.body,
                                     at: BackendMapping.iso(entry.createdAt))
        let dto = try await put("/journal", body: body, as: JournalEntryDTO.self)
        mapLock.lock()
        journalBackendIDs[entry.id] = dto.id
        journalBackendIDs[BackendMapping.stableUUID(dto.id)] = dto.id
        mapLock.unlock()
        // Keep the caller's identity + device-local fields (mood/tags/metrics);
        // the server round-trip confirms text + timestamp.
        var confirmed = entry
        confirmed.syncEnabled = true
        confirmed.updatedAt = Date()
        return confirmed
    }

    func deleteJournalEntry(id: UUID) async throws {
        // Entry never synced ⇒ nothing server-side to delete (honest no-op).
        guard let backendID = journalBackendID(for: id) else { return }
        struct DeletedDTO: Decodable { let deleted: Bool }
        let resp = try await delete("/journal/\(backendID)", as: DeletedDTO.self)
        guard resp.deleted else { throw SupabaseError.serverError("Delete failed.") }
        mapLock.lock()
        journalBackendIDs[id] = nil
        mapLock.unlock()
    }

    private func journalBackendID(for uuid: UUID) -> String? {
        mapLock.lock(); defer { mapLock.unlock() }
        return journalBackendIDs[uuid]
    }

    // MARK: - GDPR rights (GET /me/export · POST /me/erase) — T1 TestProd wave

    /// GDPR Art. 20 — the server's export blob, verbatim (shared as JSON).
    func exportMyData() async throws -> Data {
        try await sendRaw("/me/export", method: "GET", bodyData: nil)
    }

    /// GDPR Art. 17 — server-side erasure (revoke-on-erase: the account row and
    /// its auth mapping die together; re-entry needs a fresh invite).
    func eraseMyData() async throws {
        struct ErasedDTO: Decodable { let erased: Bool }
        let resp = try await post("/me/erase", body: EmptyBody(), as: ErasedDTO.self)
        guard resp.erased else {
            throw SupabaseError.serverError("The server did not confirm the erase.")
        }
    }

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
    private func delete<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        try await send(path, method: "DELETE", bodyData: nil, as: T.self)
    }

    private func send<T: Decodable>(_ path: String, method: String, bodyData: Data?, as: T.Type, base: URL? = nil) async throws -> T {
        let data = try await sendRaw(path, method: method, bodyData: bodyData, base: base)
        if data.isEmpty, let empty = EmptyDecodable() as? T { return empty }
        do { return try Self.decoder.decode(T.self, from: data) }
        catch { throw SupabaseError.serverError("Decode \(T.self): \(error.localizedDescription)") }
    }

    /// Request returning the raw response body (used for `/me/export`, whose
    /// JSON blob is shared verbatim, and as the plumbing under `send`).
    /// `allowRefresh` guards the 401 → silent-refresh → retry path to exactly
    /// one retry (the retried call passes false).
    @discardableResult
    private func sendRaw(_ path: String, method: String, bodyData: Data?, base: URL? = nil,
                         allowRefresh: Bool = true) async throws -> Data {
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
        catch let e as URLError where e.code == .notConnectedToInternet
                                   || e.code == .networkConnectionLost
                                   || e.code == .dataNotAllowed {
            throw SupabaseError.serverError(String(localized: "You appear to be offline. Check your connection and try again."))
        }
        catch let e as URLError where e.code == .timedOut {
            throw SupabaseError.serverError(String(localized: "The server is taking too long to respond. Try again in a moment."))
        }
        catch { throw SupabaseError.serverError(error.localizedDescription) }

        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.serverError("No HTTP response")
        }
        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            // Expired access token → ONE silent refresh, then retry this
            // request once. A failed refresh falls through to signed-out.
            if allowRefresh, auth != nil, await refreshSession() != nil {
                return try await sendRaw(path, method: method, bodyData: bodyData,
                                         base: base, allowRefresh: false)
            }
            throw SupabaseError.notSignedIn
        case 500...599:
            // Server-side trouble — never show the raw body to a citizen.
            throw SupabaseError.serverError(String(localized: "Liviqa's servers are having trouble right now. Please try again in a few minutes."))
        default:
            // 4xx: prefer the server's own message field; never dump raw JSON.
            let o = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let serverMsg = (o["message"] as? String) ?? (o["error"] as? String) ?? (o["msg"] as? String)
            throw SupabaseError.serverError(serverMsg
                ?? String(localized: "That didn't go through (error \(http.statusCode)). Try again."))
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
    /// CE chain reference — carried by the grant DETAIL today; tolerated on the
    /// list route for forward-compatibility (optional decode, T1 wave).
    let ceGrantRef: String?
}

/// Internal (not private) so `ReceiptDecodeTests` can decode fixtures and
/// exercise `LiviqaBackendService.walletEvent(from:)` without URLSession.
struct LedgerEventDTO: Decodable {
    struct Detail: Decodable {
        let actorName: String?
        let actor: String?
        let scope: [String]?
        let scopeKeys: [String]?
        /// CE evidence block (`detail.ce`, CE_MODE=sim) — snake_case keys
        /// decoded straight into the domain `CEEvidence` (same wire names).
        let ce: CEEvidence?
    }
    let id: String
    let type: String
    let grantId: String?
    let detail: Detail?
    let occurredAt: String
}

/// Citizen journal row (`GET/PUT /journal`). Internal for mapping tests.
struct JournalEntryDTO: Decodable {
    let id: String
    let text: String
    let at: String
    let createdAt: String?
}

private struct JournalUpsertBody: Encodable {
    let id: String?
    let text: String
    let at: String
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
