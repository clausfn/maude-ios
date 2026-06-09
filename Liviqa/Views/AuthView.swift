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
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("Your data stays on your device. Nothing leaves without your consent.")
                        .font(.liviqaKicker(9.5)).tracking(0.3)
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.bottom, 30)
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
