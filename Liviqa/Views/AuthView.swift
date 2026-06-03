// AuthView.swift — Sign in gate. Three paths: Apple, email/password, Demo mode.
// Demo mode is the single most important button for the Novo pitch — it must never fail.
// v02 2026-05-22
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
                Spacer()

                // ── Wordmark ──
                VStack(spacing: 10) {
                    LiviqaApertureMark(size: 52)
                    Text("Liviqa")
                        .font(.lato(36, .black))
                        .kerning(-0.7)
                        .foregroundStyle(LiviqaTheme.ink)
                    Text("Your data. Your insights. Your terms.")
                        .font(.lato(13))
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                .padding(.bottom, 48)

                // ── Sign in card ──
                VStack(spacing: 12) {

                    // Apple Sign In (currently falls back to demo on error)
                    Button {
                        Task { await appleSignIn() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.lato(15, .medium))
                            Text("Continue with Apple")
                                .font(.lato(15, .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LiviqaTheme.invertBG)
                        .foregroundStyle(LiviqaTheme.invertFG)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Email/password toggle
                    if showEmailForm {
                        emailForm
                    } else {
                        Button("Sign in with email") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showEmailForm = true
                            }
                        }
                        .font(.lato(14, .medium))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LiviqaTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line))
                    }

                    // Error
                    if let error = appState.lastError {
                        Text(error)
                            .font(.lato(12))
                            .foregroundStyle(LiviqaTheme.rust)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                    // Demo mode — primary path for pitch and preview
                    Divider()
                        .background(LiviqaTheme.line2)
                        .padding(.vertical, 4)

                    Button {
                        appState.signInDemo()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle")
                                .font(.lato(14))
                            Text("Continue without account")
                                .font(.lato(14, .bold))
                        }
                        .foregroundStyle(LiviqaTheme.moss)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LiviqaTheme.moss2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.moss3, lineWidth: 1))
                    }
                }
                .padding(20)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line, lineWidth: 0.5))
                .shadow(color: LiviqaTheme.cardShadow, radius: 12, y: 4)
                .padding(.horizontal, 24)

                Spacer()

                // Privacy note
                Text("Data stays on your device. Nothing shared without your consent.")
                    .font(.caption2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Email form

    @ViewBuilder
    private var emailField: some View {
        #if os(iOS)
        TextField("Email", text: $email)
            .font(.lato(14))
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
        #else
        TextField("Email", text: $email)
            .font(.lato(14))
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
        #endif
    }

    @ViewBuilder
    private var emailForm: some View {
        VStack(spacing: 8) {
            emailField
                .padding(12)
                .background(LiviqaTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(LiviqaTheme.line))

            SecureField("Password", text: $password)
                .font(.lato(14))
                .textContentType(.password)
                .padding(12)
                .background(LiviqaTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(LiviqaTheme.line))

            Button {
                Task { await emailSignIn() }
            } label: {
                Group {
                    if appState.isSigningIn {
                        ProgressView().tint(.white)
                    } else {
                        Text("Sign in")
                            .font(.lato(14, .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(LiviqaTheme.invertBG)
                .foregroundStyle(LiviqaTheme.invertFG)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(appState.isSigningIn || email.isEmpty || password.isEmpty)
        }
    }

    // MARK: - Actions

    private func emailSignIn() async {
        await appState.signInWithEmail(email: email, password: password)
    }

    private func appleSignIn() async {
        // Native Sign in with Apple → Ory OIDC-native. The Apple identity token +
        // raw nonce go to the backend service (FR-AUTH-01). The Demo button below
        // remains the never-fail pitch path; we do NOT silently fall back here.
        do {
            let result = try await appleCoordinator.signIn()
            await appState.signInWithApple(idToken: result.idToken, nonce: result.rawNonce)
        } catch {
            // Swallow an explicit user cancel; surface anything else.
            if (error as? ASAuthorizationError)?.code != .canceled {
                appState.lastError = "Apple sign-in didn’t complete. Use email, or continue without an account."
            }
        }
    }
}
