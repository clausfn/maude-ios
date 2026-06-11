// AuthView.swift — Sign-in gate (Design System v2). Premium, paper-ground,
// evidence-led. Apple primary · email secondary · demo a quiet tertiary.
// v03 2026-06-09
import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AppState.self) private var appState
    @State private var showEmailForm = false
    @State private var email = ""
    @State private var password = ""
    @State private var appleCoordinator = AppleSignInCoordinator()
    @State private var showWalletLogin = false
    #if DEBUG
    /// Screenshot hook: open the DfG wallet flow immediately (LIVIQA_OPEN_DFG=1).
    private var autoOpenDfG: Bool { ProcessInfo.processInfo.environment["LIVIQA_OPEN_DFG"] == "1" }
    #endif
    @State private var activeIDP: IDProvider? = nil

    var body: some View {
        ZStack {
            LiviqaTheme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // ── Brand hero ──
                VStack(spacing: 14) {
                    LiviqaApertureMark(size: 60)
                    Text("Liviqa")
                        .font(.lato(40, .black))
                        .kerning(LiviqaTheme.Tracking.wordmark)
                        .foregroundStyle(LiviqaTheme.ink)
                    Text("Your own data, understood.\nNot averages — yours.")
                        .font(.lato(14))
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                .padding(.bottom, 44)

                // ── Sign-in ──
                VStack(spacing: 11) {
                    if Config.authEnabled {
                        appleButton

                        if Config.dfgWalletLoginEnabled || Config.nationalIDLoginEnabled {
                            walletGrid
                        }

                        if showEmailForm {
                            emailForm
                        } else {
                            secondaryButton("Continue with email", icon: "envelope") {
                                withAnimation(.easeInOut(duration: 0.2)) { showEmailForm = true }
                            }
                        }

                        if let error = appState.lastError {
                            Text(error)
                                .font(.lato(12))
                                .foregroundStyle(LiviqaTheme.rust)
                                .multilineTextAlignment(.center)
                                .padding(.top, 2)
                                .padding(.horizontal, 4)
                        }
                    }

                    // Quiet demo path (no account) — kept for a quick look-around.
                    Button {
                        appState.signInDemo()
                    } label: {
                        Text(Config.authEnabled ? "Continue without an account" : "Enter Liviqa")
                            .font(.lato(13, .bold))
                            .foregroundStyle(LiviqaTheme.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .padding(.top, Config.authEnabled ? 2 : 0)
                }
                .padding(.horizontal, 28)

                Spacer()

                // ── Sovereignty footer ──
                VStack(spacing: 7) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("Your data stays on your device.\nNothing leaves without your consent.")
                        .font(.lato(11.5)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: — Buttons

    private var appleButton: some View {
        Button {
            Task { await appleSignIn() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo").font(.system(size: 17, weight: .medium))
                Text("Continue with Apple").font(.lato(16, .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(LiviqaTheme.invertBG)
            .foregroundStyle(LiviqaTheme.invertFG)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
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

    private func secondaryButton(_ title: String, icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .medium))
                Text(title).font(.lato(15, .bold))
            }
            .foregroundStyle(LiviqaTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
        }
    }

    // MARK: — Email form

    @ViewBuilder
    private var emailForm: some View {
        VStack(spacing: 9) {
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
                    .textContentType(.password)
            }
            Button {
                Task { await emailSignIn() }
            } label: {
                Group {
                    if appState.isSigningIn {
                        ProgressView().tint(LiviqaTheme.invertFG)
                    } else {
                        Text("Sign in").font(.lato(15, .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LiviqaTheme.invertBG)
                .foregroundStyle(LiviqaTheme.invertFG)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(appState.isSigningIn || email.isEmpty || password.isEmpty)
        }
    }

    private func inputField<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.lato(15))
            .foregroundStyle(LiviqaTheme.ink)
            .padding(14)
            .background(LiviqaTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    // MARK: — Actions

    private func emailSignIn() async {
        await appState.signInWithEmail(email: email, password: password)
    }

    private func appleSignIn() async {
        do {
            let result = try await appleCoordinator.signIn()
            await appState.signInWithApple(idToken: result.idToken, nonce: result.rawNonce)
        } catch {
            if (error as? ASAuthorizationError)?.code != .canceled {
                appState.lastError = "Apple sign-in didn’t complete. Use email, or continue without an account."
            }
        }
    }
}
