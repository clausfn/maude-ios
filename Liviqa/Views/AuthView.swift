// AuthView.swift — Sign-in gate · v04 2026-08-12 (A7.2 restyle)
// Designed anatomy (f-onboarding.jsx step 2): centered header ("A free
// account — for you first."), 3-row benefits card, black Sign in with Apple,
// collapsible "Use email instead", teal demo link (DEBUG), Keychain footnote.
// ALL real GoTrue states kept from v03: error text, confirm-email-pending,
// forgot-password (/recover), recovery deep link → SetNewPasswordView.
// Embedded as step 2 of OnboardingFlowView (flowKicker set); also serves the
// returning signed-out user standalone. The identity-wallet grid is not in
// the A7.2 frame — it stays reachable behind its Config flags, tucked under
// a quiet "More sign-in options" disclosure.
import SwiftUI
import AuthenticationServices

struct AuthView: View {
    /// "Step 2 of 9" when embedded in the onboarding flow; nil standalone.
    var flowKicker: String? = nil
    /// Flow hook for the DEBUG demo entry: the flow owns the demo session +
    /// routing (demo skips the Apple Health primer, per the design).
    var onDemoContinue: (() -> Void)? = nil

    /// Email surface mode — signup is the primary path for new citizens
    /// (open registration, CN 2026-07-07); sign-in one tap away.
    private enum EmailMode { case create, signIn }

    /// Forgot-password flow (GoTrue /recover): request state + calm confirmation.
    private enum ResetState: Equatable { case idle, needsEmail, sending, sent(String), failed(String) }

    @Environment(AppState.self) private var appState
    @State private var showEmailForm = false
    @State private var emailMode: EmailMode = .create
    @State private var email = ""
    @State private var password = ""
    @State private var resetState: ResetState = .idle
    /// Signup accepted, session withheld — the deployment wants the e-mail
    /// confirmed first (token-less 200 from GoTrue).
    @State private var confirmEmailPending = false
    @State private var appleCoordinator = AppleSignInCoordinator()
    @State private var showWalletLogin = false
    /// Wallet/eID grid disclosure (flag-gated flows; not in the A7.2 frame).
    @State private var showMoreOptions = false
    /// Set-new-password flow, opened by a GoTrue recovery deep link (the reset
    /// link the citizen received by e-mail). `nil` = no reset in progress.
    @State private var recovery: RecoveryContext? = nil
    /// After a successful in-app reset, prompt a calm "sign in with your new
    /// password" note (fallback when auto sign-in can't infer the email).
    @State private var passwordResetDone = false

    /// The recovery session token carried by the reset link (Identifiable so it
    /// can drive a `.fullScreenCover(item:)`).
    private struct RecoveryContext: Identifiable {
        let id = UUID()
        let accessToken: String
        let refreshToken: String?
    }
    #if DEBUG
    /// Screenshot hook: open the DfG wallet flow immediately (LIVIQA_OPEN_DFG=1).
    private var autoOpenDfG: Bool { ProcessInfo.processInfo.environment["LIVIQA_OPEN_DFG"] == "1" }
    /// Screenshot hook: open the email surface (LIVIQA_OPEN_EMAIL=create|signin).
    private var autoOpenEmail: String? { ProcessInfo.processInfo.environment["LIVIQA_OPEN_EMAIL"] }
    #endif
    @State private var activeIDP: IDProvider? = nil

    var body: some View {
        ZStack {
            // Standalone carries its own paper ground; embedded rides the
            // flow's canvas + ambient glow.
            if flowKicker == nil {
                LiviqaTheme.paper.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        benefitsCard
                            .padding(.top, 18)
                            .padding(.bottom, 16)
                        signInStack
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, flowKicker == nil ? 28 : 0)
                    .padding(.bottom, 12)
                }
                .scrollBounceBehavior(.basedOnSize)

                // Lock footnote — pinned under the scroll
                HStack(spacing: 7) {
                    Image(systemName: "lock")
                        .font(.system(size: 11, weight: .medium))
                    Text("Sign-in keys are stored in the iOS Keychain.")
                        .font(.lato(11.5))
                }
                .foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 6)
                .padding(.bottom, 16)
            }
        }
        // Password-reset completion: the e-mailed recovery link opens the app
        // here (the citizen is signed out). GoTrue puts the recovery token in the
        // URL fragment; we parse it and present the set-new-password screen. This
        // is the in-app completion half of /recover — without it the reset link
        // has nowhere to land. (Delivery needs the URL scheme / associated domain
        // registered for the bundle — owner-side, see the deploy handoff.)
        .onOpenURL { url in
            switch SupabaseAuthClient.recoveryOutcome(from: url) {
            case .ready(let accessToken, let refreshToken):
                appState.lastError = nil
                recovery = RecoveryContext(accessToken: accessToken, refreshToken: refreshToken)
            case .expired(let message):
                // Link used or timed out — route back to sign-in with an honest note.
                withAnimation(.easeInOut(duration: 0.2)) {
                    recovery = nil
                    showEmailForm = true
                    emailMode = .signIn
                    resetState = .failed(message)
                }
            case nil:
                break   // not a recovery link — leave other deep-link handlers to it
            }
        }
        .fullScreenCover(item: $recovery) { ctx in
            SetNewPasswordView(
                accessToken: ctx.accessToken,
                onComplete: { email, newPassword in
                    recovery = nil
                    showEmailForm = true
                    emailMode = .signIn
                    resetState = .idle
                    if let email, !email.isEmpty {
                        // We know the account — sign straight in with the new password.
                        self.email = email
                        self.password = ""
                        Task { await appState.signInWithEmail(email: email, password: newPassword) }
                    } else {
                        // No email in the token — the citizen signs in manually.
                        self.password = ""
                        passwordResetDone = true
                    }
                },
                onCancel: { recovery = nil }
            )
        }
        #if DEBUG
        .onAppear {
            if let mode = autoOpenEmail {
                emailMode = (mode == "signin") ? .signIn : .create
                showEmailForm = true
            }
        }
        #endif
    }

    // MARK: — Designed header

    private var header: some View {
        VStack(spacing: 0) {
            if let flowKicker {
                Text(flowKicker.uppercased())
                    .font(.liviqaKicker(10.5))
                    .tracking(LiviqaTheme.Tracking.kicker)
                    .foregroundStyle(LiviqaTheme.moss)
            }
            Text("A free account — for you first.")
                .font(.liviqaSerif(26, .bold, relativeTo: .title2))
                .kerning(LiviqaTheme.Tracking.h1)
                .foregroundStyle(LiviqaTheme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(LiviqaTheme.moss)
                .frame(width: 44, height: 3)
                .padding(.vertical, 12)
                .accessibilityHidden(true)
            Text("Liviqa is yours to use alone, free. An account — held by the non-profit Data for Good Foundation — only stores your name and email, and unlocks a few things when you want them.")
                .font(.lato(13.5))
                .lineSpacing(4)
                .foregroundStyle(LiviqaTheme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
    }

    // What an account (DfG) enables — 3-row benefits card.
    private var benefitsCard: some View {
        OnbCard {
            OnbBenefitRow(icon: "doc.on.doc",
                          title: String(localized: "Keep your setup"),
                          sub: String(localized: "Restore your Passport and settings if you change phones."))
            OnbBenefitRow(icon: "sparkles",
                          title: String(localized: "Contribute to research"),
                          sub: String(localized: "When you choose to, your patterns join a group of people so studies can learn from them. Always anonymous, always grouped — never your individual readings."),
                          divider: true)
            OnbBenefitRow(icon: "gift",
                          title: String(localized: "Earn tokens — keep or give them away"),
                          sub: String(localized: "A token is a thank-you the Foundation gives you for taking part in a study. It holds no health data. Keep them, or pass them to a charitable cause for the public good."),
                          divider: true)
        }
    }

    // MARK: — Sign-in stack

    private var signInStack: some View {
        VStack(spacing: 10) {
            if Config.authEnabled {
                if Config.appleSignInAvailable {
                    appleButton
                }

                if showEmailForm {
                    emailForm
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showEmailForm = true }
                    } label: {
                        Text("Use email instead")
                            .font(.lato(14.5, .semibold))
                            .foregroundStyle(LiviqaTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(LiviqaTheme.ink.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                if let error = appState.lastError {
                    Text(error)
                        .font(.lato(12))
                        .foregroundStyle(LiviqaTheme.rust)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                        .padding(.horizontal, 4)
                }

                // Identity-wallet flows (simulated, flag-gated) — kept reachable
                // behind a quiet disclosure; not part of the A7.2 frame.
                if Config.dfgWalletLoginEnabled || Config.nationalIDLoginEnabled {
                    if showMoreOptions {
                        walletGrid
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showMoreOptions = true }
                        } label: {
                            Text("More sign-in options")
                                .font(.lato(12.5, .semibold))
                                .foregroundStyle(LiviqaTheme.ink3)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Quiet demo path (no account) — DEBUG-ONLY (T1 TestProd):
            // signInDemo() seeds fabricated grants/threads, so a Release/
            // TestFlight build must not offer it. Real sign-in only there.
            #if DEBUG
            Button {
                if let onDemoContinue {
                    onDemoContinue()
                } else {
                    appState.signInDemo()
                }
            } label: {
                Text(Config.authEnabled ? "Try it without an account →" : "Enter Liviqa")
                    .font(.lato(13.5, .semibold))
                    .foregroundStyle(LiviqaTheme.moss)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            #endif
        }
    }

    // MARK: — Buttons

    private var appleButton: some View {
        Button {
            Task { await appleSignIn() }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "apple.logo").font(.system(size: 17, weight: .medium))
                Text("Sign in with Apple").font(.lato(15, .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // Identity-wallet sign-in: AltID · e-Boks ID · iGrant.io · DfG — a 2×2 grid of
    // logo-forward wallet tiles (eIDAS 2.0 interoperability). Official AltID + e-Boks
    // marks; DfG mark; iGrant teal swatch.
    private var walletGrid: some View {
        VStack(spacing: 9) {
            Text("OR USE AN IDENTITY WALLET")
                .font(.liviqaKicker(9)).tracking(1.4).foregroundStyle(LiviqaTheme.ink4)
                .padding(.top, 2)
            HStack(spacing: 9) {
                walletCell(logo: "altid-logo", swatch: nil, name: "AltID") { activeIDP = .altID }
                walletCell(logo: "eboks-logo", swatch: nil, name: "e‑Boks ID") { activeIDP = .eBoks }
            }
            HStack(spacing: 9) {
                walletCell(logo: "igrant-logo", swatch: nil, name: "iGrant.io") { activeIDP = .iGrant }
                walletCell(logo: "dfg-logo-negative", tileColor: LiviqaTheme.dfgNavy, swatch: nil, name: "DfG Wallet") { showWalletLogin = true }
            }
        }
        .fullScreenCover(item: $activeIDP) { p in
            IDProviderLoginView(
                provider: p,
                onComplete: { activeIDP = nil; appState.signInWithProvider(p.name) },
                onCancel: { activeIDP = nil }
            )
        }
        #if DEBUG
        .task { if autoOpenDfG { try? await Task.sleep(nanoseconds: 400_000_000); showWalletLogin = true } }
        #endif
        .fullScreenCover(isPresented: $showWalletLogin) {
            DfGWalletLoginView(
                onComplete: { ref in showWalletLogin = false; appState.signInWithDfGWallet(verificationRef: ref) },
                onCancel: { showWalletLogin = false }
            )
        }
    }

    private func walletCell(logo: String?, tileColor: Color? = nil, swatch: Color?, name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let logo {
                    if let tileColor {
                        // Bare (transparent) logo → put it on its own coloured tile so it
                        // stays visible on any theme (e.g. the white DfG symbol on navy).
                        ZStack {
                            RoundedRectangle(cornerRadius: 7).fill(tileColor)
                            Image(logo).resizable().scaledToFit().frame(width: 26, height: 26)
                        }
                        .frame(width: 32, height: 32)
                    } else {
                        Image(logo).resizable().scaledToFit().frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                } else if let swatch {
                    RoundedRectangle(cornerRadius: 7).fill(swatch).frame(width: 32, height: 32)
                }
                Text(name).font(.lato(14, .bold)).foregroundStyle(LiviqaTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: — Email form (create-account first; sign-in one tap away)

    @ViewBuilder
    private var emailForm: some View {
        VStack(spacing: 9) {
            // Serif mini-verdict — the Morning Edition voice at the decision moment.
            Text(emailMode == .create
                 ? String(localized: "Create your account.")
                 : String(localized: "Welcome back."))
                .font(.liviqaSerif(19))
                .foregroundStyle(LiviqaTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

            // Confirmation-pending signup: a calm inbox nudge, not an error.
            if confirmEmailPending {
                calmNote(icon: "envelope.badge", EmailConfirmationPending.message)
            }

            // Password just reset in-app: invite a calm sign-in with the new one.
            if passwordResetDone {
                calmNote(icon: "checkmark.seal",
                         String(localized: "Password updated. Sign in with your new password."))
            }

            inputField {
                #if os(iOS)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                #else
                TextField("Email", text: $email).autocorrectionDisabled()
                #endif
            }
            inputField {
                SecureField("Password", text: $password)
                    .textContentType(emailMode == .create ? .newPassword : .password)
            }
            if emailMode == .signIn, appState.supabase is PasswordRecovery {
                forgotPasswordRow
            }
            if emailMode == .create {
                // The rule, stated up front — never a surprise rejection.
                Text(String(localized: "At least 6 characters."))
                    .font(.lato(11.5))
                    .foregroundStyle(password.isEmpty || password.count >= 6
                                     ? LiviqaTheme.ink4 : LiviqaTheme.clayText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            }
            Button {
                Task { await emailSubmit() }
            } label: {
                Group {
                    if appState.isSigningIn {
                        ProgressView().tint(.white)
                    } else {
                        Text(emailMode == .create
                             ? String(localized: "Create account")
                             : String(localized: "Sign in"))
                            .font(.lato(15, .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LiviqaTheme.moss)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(appState.isSigningIn || email.isEmpty || password.isEmpty)

            // Mode switch — the answer to "email taken" / "no account yet" is always visible.
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    emailMode = (emailMode == .create) ? .signIn : .create
                    appState.lastError = nil
                    resetState = .idle
                    confirmEmailPending = false
                    passwordResetDone = false
                }
            } label: {
                Text(emailMode == .create
                     ? String(localized: "Already have an account? Sign in")
                     : String(localized: "New to Liviqa? Create an account"))
                    .font(.lato(13, .bold))
                    .foregroundStyle(LiviqaTheme.moss)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
    }

    // "Forgot password?" — standard placement under the password field. GoTrue
    // answers 200 for unknown emails too (no account enumeration), so the
    // confirmation copy stays conditional.
    @ViewBuilder
    private var forgotPasswordRow: some View {
        if case .sent(let to) = resetState {
            calmNote(icon: "envelope.badge",
                     String(localized: "Check your email — if an account exists for \(to), we've sent a reset link."))
        } else {
            Button {
                Task { await sendPasswordReset() }
            } label: {
                Group {
                    if resetState == .sending {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(String(localized: "Forgot password?"))
                            .font(.lato(13, .bold))
                            .foregroundStyle(LiviqaTheme.moss)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)
            }
            .disabled(resetState == .sending)
            if case .needsEmail = resetState {
                Text(String(localized: "Enter your email above first, then tap again."))
                    .font(.lato(11.5))
                    .foregroundStyle(LiviqaTheme.clayText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            }
            if case .failed(let msg) = resetState {
                Text(msg)
                    .font(.lato(11.5))
                    .foregroundStyle(LiviqaTheme.rust)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            }
        }
    }

    /// Calm confirmation surface (moss tint, ink text — not the error voice).
    private func calmNote(icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LiviqaTheme.moss)
                .padding(.top, 1)
            Text(text)
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
    }

    private func inputField<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.lato(15))
            .foregroundStyle(LiviqaTheme.ink)
            .padding(14)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    // MARK: — Actions

    private func emailSubmit() async {
        confirmEmailPending = false
        switch emailMode {
        case .create:
            await appState.signUpWithEmail(email: email, password: password)
            // A confirmation-pending deployment answers 200 without a session;
            // that typed outcome lands in lastError — reroute it to the calm
            // inbox state and put sign-in front and centre for the return trip.
            if appState.lastError == EmailConfirmationPending.message {
                appState.lastError = nil
                withAnimation(.easeInOut(duration: 0.2)) {
                    confirmEmailPending = true
                    emailMode = .signIn
                }
            }
        case .signIn:
            await appState.signInWithEmail(email: email, password: password)
        }
    }

    /// GoTrue /recover — prefilled from the email field; calm conditional
    /// confirmation on success, friendly copy on failure.
    private func sendPasswordReset() async {
        guard let recovery = appState.supabase as? PasswordRecovery else { return }
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            withAnimation(.easeInOut(duration: 0.15)) { resetState = .needsEmail }
            return
        }
        resetState = .sending
        do {
            try await recovery.requestPasswordReset(email: address)
            withAnimation(.easeInOut(duration: 0.2)) { resetState = .sent(address) }
        } catch {
            let msg = (error as? SupabaseError)?.errorDescription
                ?? String(localized: "We couldn't send the reset email. Check your connection and try again.")
            withAnimation(.easeInOut(duration: 0.2)) { resetState = .failed(msg) }
        }
    }

    private func appleSignIn() async {
        do {
            let result = try await appleCoordinator.signIn()
            await appState.signInWithApple(idToken: result.idToken, nonce: result.rawNonce)
        } catch {
            // User backed out of the Apple sheet — not an error.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            // Surface the REAL reason (domain + code + message) so a failing Apple
            // sign-in is diagnosable instead of a dead end. A GoTrue token rejection
            // surfaces its own message via signInWithApple → lastError already.
            let ns = error as NSError
            appState.lastError = "Apple sign-in failed — \(ns.domain) \(ns.code): \(error.localizedDescription)"
        }
    }
}

// MARK: — Set-new-password (recovery-link completion)

/// The in-app landing for a GoTrue password-reset link. Sets the new password
/// via `PUT /auth/v1/user` (recovery token as bearer), then hands the email +
/// new password back so `AuthView` can sign the citizen straight in. Builds its
/// own auth client against `Config.supabaseAuthURL` — the same GoTrue the app
/// signs in with — so it needs no wiring into the private backend service.
/// A7.2: paper ground · ink text · moss accent · high-contrast CTA.
private struct SetNewPasswordView: View {
    let accessToken: String
    let onComplete: (_ email: String?, _ newPassword: String) -> Void
    let onCancel: () -> Void

    @State private var password = ""
    @State private var confirm = ""
    @State private var isSaving = false
    @State private var error: String? = nil

    /// Inline guidance — stated up front, never a surprise rejection.
    private var hint: (text: String, warn: Bool)? {
        if password.isEmpty { return nil }
        if password.count < 6 { return (String(localized: "At least 6 characters."), true) }
        if !confirm.isEmpty && confirm != password { return (String(localized: "Both passwords must match."), true) }
        return nil
    }
    private var canSave: Bool { password.count >= 6 && password == confirm && !isSaving }

    var body: some View {
        ZStack {
            LiviqaTheme.paper.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer(minLength: 24)

                VStack(spacing: 10) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text(String(localized: "Set a new password"))
                        .font(.liviqaSerif(22))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text(String(localized: "Choose a new password for your Liviqa account."))
                        .font(.lato(13)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 4)

                field {
                    SecureField(String(localized: "New password"), text: $password)
                        .textContentType(.newPassword)
                }
                field {
                    SecureField(String(localized: "Confirm new password"), text: $confirm)
                        .textContentType(.newPassword)
                }

                if let hint {
                    Text(hint.text)
                        .font(.lato(11.5))
                        .foregroundStyle(hint.warn ? LiviqaTheme.clayText : LiviqaTheme.ink4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
                if let error {
                    Text(error)
                        .font(.lato(12)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.rust)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }

                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(LiviqaTheme.invertFG)
                        } else {
                            Text(String(localized: "Set new password")).font(.lato(15, .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LiviqaTheme.invertBG)
                    .foregroundStyle(LiviqaTheme.invertFG)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.6)

                Button(action: onCancel) {
                    Text(String(localized: "Cancel"))
                        .font(.lato(13, .bold))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                Spacer()
            }
            .padding(.horizontal, 28)
        }
    }

    private func field<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.lato(15))
            .foregroundStyle(LiviqaTheme.ink)
            .padding(14)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    private func save() async {
        error = nil
        isSaving = true
        defer { isSaving = false }
        let client = SupabaseAuthClient(baseURL: Config.supabaseAuthURL, apiKey: nil)
        do {
            let result = try await client.updatePassword(accessToken: accessToken, newPassword: password)
            onComplete(result.email, password)
        } catch {
            self.error = (error as? SupabaseError)?.errorDescription
                ?? String(localized: "We couldn't set your new password. Try again.")
        }
    }
}
