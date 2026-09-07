// ShareReceiptSheet.swift — the share receipt SLIP (UC-13/UC-21, FR-WAL-09) ·
// v02 2026-08-12 · A7.2 rebuild from b-onboarding.jsx ScrConsentReceipt.
// Slip-first: a centered check ring, serif verdict, then a receipt card (dark
// marine header with the iris watermark, plain rows, governed footer). The
// wallet offer (QR + haip-vci deep link, the old v01 anatomy) is DEMOTED behind
// "Add to my DfG wallet". Citizen credentials (UC-A) keep the QR-first layout —
// they are a sign-in credential, not a share receipt.
//
// CE-STUB RAIL (FR-WAL-09, safety-path copy): while the backend runs
// CE_MODE=stub, receipts are NON-EVIDENTIARY. The "signed so nobody can change
// it" claim and the proof number render ONLY when a real, evidentiary
// CEEvidence is attached (receipt id + event hash — CEEvidence.isEvidentiary);
// otherwise the copy softens to "kept in your consent record". T-WAL-09.
import SwiftUI
#if canImport(UIKit)
import UIKit
import CoreImage.CIFilterBuiltins
#endif

/// The wallet offer, made Identifiable so it can drive `.sheet(item:)`.
/// `grant`/`evidence` feed the receipt slip; both default nil so existing
/// call sites (JournalView, DfGWalletLoginView) keep compiling unchanged.
struct WalletReceiptOffer: Identifiable {
    enum Kind { case shareReceipt, citizenCredential }
    let id = UUID()
    let url: URL
    let recipientName: String
    var kind: Kind = .shareReceipt
    /// Short-validity window (revocation stand-in) — shown so renewal is expected.
    var validUntil: Date? = nil
    /// The grant this receipt witnesses — drives the slip rows when present.
    var grant: WalletGrant? = nil
    /// Real consent-engine evidence for the grant, if any (FR-WAL-09 gate).
    var evidence: CEEvidence? = nil
}

// MARK: - Slip model (testable — T-WAL-09)

/// Pure builder for the receipt slip: headline, rows, and the claim sentence.
/// All evidence gating lives here so it can be unit-asserted without SwiftUI.
struct ReceiptSlipModel: Equatable {
    let headline: String
    let rows: [Row]
    /// The body sentence under the verdict — signed-claim ONLY with evidence.
    let claim: String

    struct Row: Equatable {
        let label: String
        let value: String
    }

    static func build(recipientName: String,
                      grant: WalletGrant?,
                      evidence: CEEvidence?,
                      now: Date = Date()) -> ReceiptSlipModel {
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy"
        let tf = DateFormatter()
        tf.dateFormat = "d MMM yyyy · HH:mm"

        var rows: [Row] = []

        // Areas — the consent GROUPS, never raw metric keys.
        if let grant {
            let groups = WalletView.scopeGroups(grant.scopeKeys)
            let areas = groups.isEmpty ? String(localized: "Summaries")
                                       : groups.joined(separator: " · ")
            rows.append(Row(label: String(localized: "Areas shared"),
                            value: "\(areas) — summaries only"))

            let from = grant.createdAt ?? now
            let period: String
            if let until = grant.expiresAt {
                period = "\(df.string(from: from)) – \(df.string(from: until))"
            } else {
                period = String(localized: "\(df.string(from: from)) — until you stop it")
            }
            rows.append(Row(label: String(localized: "Time period"), value: period))
        }

        // The standing promise — true by construction (DerivedShareBuilder).
        rows.append(Row(label: String(localized: "Your individual readings"),
                        value: String(localized: "0 shared — ever")))

        // Proof number + signed-at: ONLY from real, evidentiary CE evidence.
        let evidentiary = evidence?.isEvidentiary == true
        if evidentiary, let proof = evidence?.proofNumber {
            rows.append(Row(label: String(localized: "Proof number"), value: proof))
            rows.append(Row(label: String(localized: "Signed at"), value: tf.string(from: now)))
        } else {
            rows.append(Row(label: String(localized: "Recorded at"), value: tf.string(from: now)))
        }

        let claim = evidentiary
            ? String(localized: "This slip is your proof: it names exactly what you agreed to, and it is signed so nobody can change it afterwards. Kept in your consent record — you can stop the share any time.")
            : String(localized: "This slip names exactly what you agreed to. It is kept in your consent record — you can stop the share any time.")

        return ReceiptSlipModel(
            headline: String(localized: "Share receipt → \(recipientName)"),
            rows: rows,
            claim: claim
        )
    }
}

// MARK: - Sheet

struct ShareReceiptSheet: View {
    let offer: WalletReceiptOffer
    @Environment(\.dismiss) private var dismiss

    /// The wallet offer (QR + deep link) is demoted behind the primary button.
    @State private var showWalletOffer = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.lato(14, .bold))
                        .foregroundStyle(MaudeTheme.ink3)
                        .padding(10)
                }
            }

            ScrollView {
                if offer.kind == .citizenCredential {
                    credentialBody
                } else {
                    slipBody
                }
            }
        }
        // Liquid-Glass receipt sheet (keeps the call sites' [.large] detent). The QR
        // card keeps its own opaque white fill for scannability; only the surface is glass.
        .maudeSheetGlass()
        .task {
            #if DEBUG
            // Headless screenshot hook: MAUDE_RECEIPT_OFFER=1 opens the demoted
            // wallet-offer section so the QR state can be captured deterministically.
            if ProcessInfo.processInfo.environment["MAUDE_RECEIPT_OFFER"] == "1" {
                showWalletOffer = true
            }
            #endif
        }
    }

    // MARK: - Share receipt: the slip (A7.2 anatomy)

    private var slipBody: some View {
        let slip = ReceiptSlipModel.build(recipientName: offer.recipientName,
                                          grant: offer.grant,
                                          evidence: offer.evidence)
        return VStack(spacing: 16) {
            // Check ring
            ZStack {
                Circle().fill(MaudeTheme.moss2).frame(width: 60, height: 60)
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(MaudeTheme.moss)
            }
            .padding(.top, 2)

            VStack(spacing: 7) {
                Text("Your share is on the record.")
                    .font(.maudeSerif(21))
                    .kerning(-0.2)
                    .foregroundStyle(MaudeTheme.ink)
                Text(slip.claim)
                    .font(.lato(13))
                    .lineSpacing(2.5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MaudeTheme.ink2)
                    .frame(maxWidth: 310)
            }

            slipCard(slip)

            // Primary: add to wallet (reveals the demoted QR/deep-link offer)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showWalletOffer.toggle() }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "wallet.pass").font(.lato(15, .medium))
                    Text("Add to my DfG wallet").font(.lato(15, .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                // Primary treatment (see MaudeTheme.primaryFill): teal + white
                // by day, off-white + marine at night — the same slab as `Done`
                // on the sibling share sheet.
                .background(MaudeTheme.primaryFill)
                .foregroundStyle(MaudeTheme.primaryLabel)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if showWalletOffer {
                walletOfferSection
            }

            Button { dismiss() } label: {
                Text("Done")
                    .font(.lato(14, .semibold))
                    .foregroundStyle(MaudeTheme.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Text("Provenance only · no raw samples leave your phone")
                .font(.maudeKicker(10))
                .tracking(0.6)
                .foregroundStyle(MaudeTheme.moss)
                .padding(.top, 2)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 30)
    }

    /// The receipt slip card: dark marine header (iris watermark) + plain rows
    /// + governed footer. Brass hairline — a consent/witness moment (A7.2 rule).
    private func slipCard(_ slip: ReceiptSlipModel) -> some View {
        VStack(spacing: 0) {
            // Header — deep marine gradient with the iris watermark
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [Color(hex: 0x16324F), Color(hex: 0x1D3557)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                MaudeApertureMark(size: 90, reversed: true)
                    .opacity(0.16)
                    .offset(x: 14, y: -20)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Proof of your choice".uppercased())
                        .font(.maudeKicker(9.5)).tracking(1.2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(slip.headline)
                        .font(.maudeSerif(17))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .clipped()

            // Rows
            VStack(spacing: 0) {
                ForEach(Array(slip.rows.enumerated()), id: \.offset) { idx, row in
                    if idx > 0 { Divider().background(MaudeTheme.line2) }
                    HStack(alignment: .top, spacing: 12) {
                        Text(row.label)
                            .font(.lato(12.5))
                            .foregroundStyle(MaudeTheme.ink3)
                        Spacer(minLength: 8)
                        Text(row.value)
                            .font(.maudeMono(12.5))
                            .foregroundStyle(MaudeTheme.ink)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 9)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(MaudeTheme.paper2)

            // Governed footer
            HStack(spacing: 8) {
                Image(systemName: "lock")
                    .font(.lato(12, .semibold))
                    .foregroundStyle(MaudeTheme.moss)
                Text("Governed by the Data for Good Foundation.")
                    .font(.lato(11.5))
                    .foregroundStyle(MaudeTheme.ink2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(MaudeTheme.moss2.opacity(0.6))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MaudeTheme.brass.opacity(0.55), lineWidth: 1))
        .shadow(color: MaudeTheme.cardShadow, radius: 10, y: 4)
    }

    /// The demoted wallet offer: QR (scan from another device) + deep link.
    private var walletOfferSection: some View {
        VStack(spacing: 12) {
            qr
                .frame(width: 190, height: 190)
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(MaudeTheme.line))
                .shadow(color: MaudeTheme.cardShadow, radius: 10, y: 4)

            Text("Scan with your My DfG wallet — or open it on this phone. The offer expires in a few minutes.")
                .font(.lato(11.5))
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(MaudeTheme.ink4)
                .frame(maxWidth: 280)

            Link(destination: offer.url) {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.lato(14, .medium))
                    Text("Open in My DfG wallet")
                        .font(.lato(14, .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(MaudeTheme.ink)
                .foregroundStyle(MaudeTheme.invertFG)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Citizen credential (UC-A) — QR-first, unchanged anatomy

    private var credentialBody: some View {
        VStack(spacing: 16) {
            MaudeApertureMark(size: 38, reversed: false)
                .padding(.top, 2)

            VStack(spacing: 7) {
                Text("Your Maude Citizen credential")
                    .font(.maudeSerif(20))
                    .kerning(-0.2)
                    .foregroundStyle(MaudeTheme.ink)
                Text("Your sign-in and participation credential — role and member ID only, pseudonymous by design. No name, no health data. Issuance is recorded in your consent record.")
                    .font(.lato(13))
                    .lineSpacing(2.5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MaudeTheme.ink3)
                    .frame(maxWidth: 300)
            }

            qr
                .frame(width: 224, height: 224)
                .padding(18)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(MaudeTheme.line))
                .shadow(color: MaudeTheme.cardShadow, radius: 10, y: 4)

            if let until = offer.validUntil {
                Text("Valid until \(until.formatted(date: .abbreviated, time: .omitted)) — short validity by design. Renew any time from this screen.")
                    .font(.lato(11.5, .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MaudeTheme.moss)
                    .frame(maxWidth: 280)
            }
            Text("Scan with your My DfG wallet — or open it on this phone. The offer expires in a few minutes.")
                .font(.lato(11.5))
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(MaudeTheme.ink4)
                .frame(maxWidth: 280)

            Link(destination: offer.url) {
                HStack(spacing: 9) {
                    Image(systemName: "wallet.pass")
                        .font(.lato(15, .medium))
                    Text("Open in My DfG wallet")
                        .font(.lato(15, .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(MaudeTheme.ink)
                .foregroundStyle(MaudeTheme.invertFG)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Text("Provenance only · no raw samples leave your phone")
                .font(.maudeKicker(10))
                .tracking(0.6)
                .foregroundStyle(MaudeTheme.moss)
                .padding(.top, 2)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 30)
    }

    // MARK: - QR

    @ViewBuilder private var qr: some View {
        #if canImport(UIKit)
        if let img = Self.qrImage(from: offer.url.absoluteString) {
            Image(uiImage: img)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            ProgressView()
        }
        #else
        ProgressView()
        #endif
    }

    #if canImport(UIKit)
    /// QR tinted to A7.2 ink (#2A4FAE) on white — brand-true and reliably
    /// scannable (dark cobalt keeps well above scanner contrast floors).
    static func qrImage(from string: String) -> UIImage? {
        let ctx = CIContext()
        let gen = CIFilter.qrCodeGenerator()
        gen.message = Data(string.utf8)
        gen.correctionLevel = "M"
        guard let base = gen.outputImage else { return nil }
        let fc = CIFilter.falseColor()
        fc.inputImage = base
        fc.color0 = CIColor(red: 0.165, green: 0.310, blue: 0.682) // A7.2 ink 0x2A4FAE
        fc.color1 = CIColor(red: 1, green: 1, blue: 1)
        guard let out = fc.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = ctx.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
    #endif
}
