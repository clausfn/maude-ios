// ShareReceiptSheet.swift — the citizen issues a Liviqa Share Receipt into their
// My DfG wallet (UC-21). Provenance only: a proof you shared, the result not the
// raw data. The wallet offer is rendered as a QR (scan from another device) and
// as a deep link (open on this phone). Liviqa-branded — the DfG card is the
// operator credential; this is the citizen's, in Liviqa's own ink/paper.
import SwiftUI
#if canImport(UIKit)
import UIKit
import CoreImage.CIFilterBuiltins
#endif

/// The wallet offer, made Identifiable so it can drive `.sheet(item:)`.
struct WalletReceiptOffer: Identifiable {
    enum Kind { case shareReceipt, citizenCredential }
    let id = UUID()
    let url: URL
    let recipientName: String
    var kind: Kind = .shareReceipt
    /// Short-validity window (revocation stand-in) — shown so renewal is expected.
    var validUntil: Date? = nil
}

struct ShareReceiptSheet: View {
    let offer: WalletReceiptOffer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.lato(14, .bold))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(10)
                }
            }

            ScrollView {
                VStack(spacing: 16) {
                    LiviqaApertureMark(size: 38, reversed: false)
                        .padding(.top, 2)

                    VStack(spacing: 7) {
                        Text(offer.kind == .citizenCredential ? "Your Liviqa Citizen credential" : "Add to My DfG wallet")
                            .font(.lato(20, .black))
                            .kerning(-0.3)
                            .foregroundStyle(LiviqaTheme.ink)
                        Text(offer.kind == .citizenCredential
                             ? "Your sign-in and participation credential — role and member ID only, pseudonymous by design. No name, no health data. Issuance is recorded in your Privacy Record."
                             : "A receipt that proves you shared with \(offer.recipientName) — the result only, never your raw data. Revocable, and recorded on your consent evidence.")
                            .font(.lato(13))
                            .lineSpacing(2.5)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(LiviqaTheme.ink3)
                            .frame(maxWidth: 300)
                    }

                    qr
                        .frame(width: 224, height: 224)
                        .padding(18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line))
                        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 4)

                    if let until = offer.validUntil {
                        Text("Valid until \(until.formatted(date: .abbreviated, time: .omitted)) — short validity by design. Renew any time from this screen.")
                            .font(.lato(11.5, .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(LiviqaTheme.moss)
                            .frame(maxWidth: 280)
                    }
                    Text("Scan with your My DfG wallet — or open it on this phone. The offer expires in a few minutes.")
                        .font(.lato(11.5))
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(LiviqaTheme.ink4)
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
                        .background(LiviqaTheme.ink)
                        .foregroundStyle(LiviqaTheme.invertFG)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)

                    Text("Provenance only · no raw samples leave your phone")
                        .font(.liviqaKicker(10))
                        .tracking(0.6)
                        .foregroundStyle(LiviqaTheme.moss)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 30)
            }
        }
        // A6: Liquid-Glass receipt sheet (keeps the call sites' [.large] detent). The QR
        // card keeps its own opaque white fill for scannability; only the surface is glass.
        .liviqaSheetGlass()
    }

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
    /// QR tinted to Liviqa ink (#0E1A2B) on white — brand-true and reliably scannable.
    static func qrImage(from string: String) -> UIImage? {
        let ctx = CIContext()
        let gen = CIFilter.qrCodeGenerator()
        gen.message = Data(string.utf8)
        gen.correctionLevel = "M"
        guard let base = gen.outputImage else { return nil }
        let fc = CIFilter.falseColor()
        fc.inputImage = base
        fc.color0 = CIColor(red: 0.055, green: 0.102, blue: 0.169) // ink
        fc.color1 = CIColor(red: 1, green: 1, blue: 1)
        guard let out = fc.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = ctx.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
    #endif
}
