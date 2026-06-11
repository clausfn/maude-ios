// HealthVaultView.swift — the vault file browser + Open Banking & Screen Time
// connect sheets (v01 · 2026-06-11, CN feedback).
//
// VAULT: the citizen's own document store — labs, clinical letters, food
// photos, finance, device exports — visible at FILE level only. Previews stay
// locked until the live production test; every row says so plainly. The
// structure below is the project's reference layout.
//
// OPEN BANKING: no bank brand on the source row; the citizen picks their bank
// from the PSD2 list. Before any connect, two things in plain language: WHY
// money patterns can explain health patterns, and the confidentiality promise
// — financial patterns are often more private than health data, so they live
// in the Health Vault on this device and never enter any clinician share.
import SwiftUI

// MARK: - Vault model (file level only)

struct VaultFile: Identifiable {
    let id = UUID()
    let name: String
    let kind: String      // SF symbol
    let date: String
    let size: String
}
struct VaultFolder: Identifiable {
    let id = UUID()
    let name: String
    let files: [VaultFile]
}

enum VaultSeed {
    static let folders: [VaultFolder] = [
        VaultFolder(name: "01 · Lab results", files: [
            VaultFile(name: "2026-02-09 HbA1c + lipid panel.pdf", kind: "doc.text.fill", date: "9 Feb 2026", size: "184 KB"),
            VaultFile(name: "2025-08-06 Lab panel.pdf", kind: "doc.text.fill", date: "6 Aug 2025", size: "176 KB"),
            VaultFile(name: "2025-02-02 Lab panel.pdf", kind: "doc.text.fill", date: "2 Feb 2025", size: "171 KB"),
        ]),
        VaultFolder(name: "02 · Clinical letters", files: [
            VaultFile(name: "2026-02-09 Annual review summary.pdf", kind: "doc.text.fill", date: "9 Feb 2026", size: "92 KB"),
            VaultFile(name: "2025-11-12 Cardiology outpatient note.pdf", kind: "doc.text.fill", date: "12 Nov 2025", size: "88 KB"),
            VaultFile(name: "2025-09-03 Imaging report — no findings.pdf", kind: "doc.text.fill", date: "3 Sep 2025", size: "85 KB"),
        ]),
        VaultFolder(name: "03 · Medication & supplements", files: [
            VaultFile(name: "Supplement list.pdf", kind: "pills.fill", date: "1 Jun 2026", size: "41 KB"),
            VaultFile(name: "2025-04-22 GP medication review.pdf", kind: "doc.text.fill", date: "22 Apr 2025", size: "77 KB"),
        ]),
        VaultFolder(name: "04 · Food photos", files: [
            VaultFile(name: "2026-06-08 Lunch.jpg", kind: "photo.fill", date: "8 Jun 2026", size: "2.1 MB"),
            VaultFile(name: "2026-06-05 Dinner.jpg", kind: "photo.fill", date: "5 Jun 2026", size: "1.9 MB"),
            VaultFile(name: "2026-05-30 Breakfast.jpg", kind: "photo.fill", date: "30 May 2026", size: "1.7 MB"),
        ]),
        VaultFolder(name: "05 · Finance", files: [
            VaultFile(name: "2026-05 Spending categories.csv", kind: "tablecells.fill", date: "31 May 2026", size: "12 KB"),
            VaultFile(name: "Open Banking consent.pdf", kind: "doc.text.fill", date: "11 Jun 2026", size: "54 KB"),
        ]),
        VaultFolder(name: "06 · Consents & insurance", files: [
            VaultFile(name: "Research participation consent.pdf", kind: "checkmark.seal.fill", date: "2 Jun 2026", size: "63 KB"),
            VaultFile(name: "Health insurance card.pdf", kind: "doc.text.fill", date: "14 Jan 2026", size: "38 KB"),
        ]),
        VaultFolder(name: "07 · Device exports", files: [
            VaultFile(name: "Apple Health export 2025-07-12.zip", kind: "archivebox.fill", date: "12 Jul 2025", size: "3.1 GB"),
            VaultFile(name: "CGM export 2026-05.csv", kind: "tablecells.fill", date: "31 May 2026", size: "8.4 MB"),
        ]),
    ]
    static var fileCount: Int { folders.reduce(0) { $0 + $1.files.count } }
}

// MARK: - Vault browser (file level only; previews locked)

struct HealthVaultView: View {
    @State private var lockedNote = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.doc")
                        .font(.lato(14))
                        .foregroundStyle(LiviqaTheme.clay)
                    Text("Your documents, on this device, encrypted. File previews open after the live production test — until then the vault shows files, not contents.")
                        .font(.caption)
                        .lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink2)
                }
                .padding(12)
                .background(LiviqaTheme.clay2)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                ForEach(VaultSeed.folders) { folder in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.lato(13))
                                .foregroundStyle(LiviqaTheme.moss)
                            Text(folder.name)
                                .font(.lato(13, .bold))
                                .foregroundStyle(LiviqaTheme.ink)
                            Spacer()
                            Text("\(folder.files.count)")
                                .font(.liviqaKicker(10))
                                .foregroundStyle(LiviqaTheme.ink4)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)

                        ForEach(folder.files) { f in
                            Divider().padding(.leading, 40)
                            Button { lockedNote = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: f.kind)
                                        .font(.lato(13))
                                        .foregroundStyle(LiviqaTheme.ink3)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(f.name)
                                            .font(.lato(12.5))
                                            .foregroundStyle(LiviqaTheme.ink)
                                            .lineLimit(1)
                                        Text("\(f.date) · \(f.size)")
                                            .font(.caption2)
                                            .foregroundStyle(LiviqaTheme.ink4)
                                    }
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(LiviqaTheme.ink4)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(LiviqaTheme.paper)
        .navigationTitle("Health Vault")
        .alert("Locked until the live production test", isPresented: $lockedNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This file is stored encrypted on your device. Previews open once the production environment is live.")
        }
    }
}

// MARK: - Open Banking connect sheet

struct OpenBankingSheet: View {
    var onConnect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let banks = ["Danske Bank", "Nordea", "Jyske Bank", "Sydbank", "Nykredit",
                         "Arbejdernes Landsbank", "Lunar", "Revolut", "N26", "Wise"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Money and health move together. Stress often shows in spending before it shows in symptoms — late-evening purchases track short sleep; quiet grocery weeks track low-energy weeks. Liviqa reads daily totals and category patterns only — never single transactions, never merchant names.")
                        .font(.lato(13.5)).lineSpacing(3)
                        .foregroundStyle(LiviqaTheme.ink2)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(LiviqaTheme.clay)
                            Text("More private than health data — treated that way")
                                .font(.lato(13, .bold))
                                .foregroundStyle(LiviqaTheme.ink)
                        }
                        Text("Your financial patterns stay in your Health Vault on this phone, beside your other documents. Encrypted, never part of any clinician share, never sent anywhere. Disconnect and erase them in one tap, any time.")
                            .font(.lato(12.5)).lineSpacing(2.5)
                            .foregroundStyle(LiviqaTheme.ink2)
                    }
                    .padding(12)
                    .background(LiviqaTheme.clay2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("CHOOSE YOUR BANK")
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(LiviqaTheme.ink3)

                    VStack(spacing: 0) {
                        ForEach(banks, id: \.self) { bank in
                            if bank != banks.first { Divider().padding(.leading, 14) }
                            Button { onConnect(bank); dismiss() } label: {
                                HStack {
                                    Image(systemName: "building.columns.fill")
                                        .font(.lato(13))
                                        .foregroundStyle(LiviqaTheme.ink3)
                                    Text(bank)
                                        .font(.lato(14))
                                        .foregroundStyle(LiviqaTheme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(LiviqaTheme.ink4)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))

                    Text("Open Banking (PSD2): read-only access through your bank's official API, authorised with MitID, revocable at your bank at any time.")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink4)
                }
                .padding(20)
            }
            .background(LiviqaTheme.paper)
            .navigationTitle("Connect a bank")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Screen Time connect sheet

struct ScreenTimeSheet: View {
    var onConnect: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("One number per day — total screen time. Long evenings on the phone often pair with later nights and shorter sleep; the pattern helps explain your mornings.")
                    .font(.lato(13.5)).lineSpacing(3)
                    .foregroundStyle(LiviqaTheme.ink2)
                Text("App names, websites and content are never accessed. The daily total stays on this device.")
                    .font(.lato(12.5)).lineSpacing(2.5)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LiviqaTheme.clay2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Button { onConnect(); dismiss() } label: {
                    Text("Connect Screen Time")
                        .font(.lato(15, .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(LiviqaTheme.moss)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
            }
            .padding(20)
            .background(LiviqaTheme.paper)
            .navigationTitle("Screen Time")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
