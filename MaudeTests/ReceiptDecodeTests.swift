import Testing
import Foundation
@testable import Maude

// T1 TestProd wave — consent-engine evidence receipts in the ledger.
// The backend's ledger events may carry a `detail.ce` block (CE_MODE=sim):
// {receipt_id, grant_ref, contract_sig, event_hash, tx_hash, ce_scope_keys,
// excluded_scope_keys}. Decode must be optional/backward-compatible: pre-CE
// events, mock data, and older backends carry none.
struct ReceiptDecodeTests {

    @Test func decodesLedgerEventWithEvidence() throws {
        let json = #"""
        [{"id":"evt_1","type":"grant","grantId":"g1",
          "detail":{"scopeKeys":["glucose","sleep"],"role":"clinical_nurse",
            "ce":{"receipt_id":"rcpt_9f2c4","grant_ref":"grant_chain_7",
                  "contract_sig":"sig_abc","event_hash":"a1b2c3d4e5f6a7b8",
                  "tx_hash":"0xdeadbeef","ce_scope_keys":["glucose"],
                  "excluded_scope_keys":["labs"]}},
          "occurredAt":"2026-07-06T10:00:00.000Z"}]
        """#
        let dtos = try JSONDecoder().decode([LedgerEventDTO].self, from: Data(json.utf8))
        let event = MaudeBackendService.walletEvent(from: dtos[0])

        #expect(event.eventType == .consentGranted)
        #expect(event.scopeKeys == ["glucose", "sleep"])
        let ce = try #require(event.ce)
        #expect(ce.receiptId == "rcpt_9f2c4")
        #expect(ce.grantRef == "grant_chain_7")
        #expect(ce.contractSig == "sig_abc")
        #expect(ce.eventHash == "a1b2c3d4e5f6a7b8")
        #expect(ce.txHash == "0xdeadbeef")
        #expect(ce.ceScopeKeys == ["glucose"])
        #expect(ce.excludedScopeKeys == ["labs"])
        #expect(ce.shortHash == "a1b2c3d4e5")   // first 10 chars, display form
    }

    @Test func eventWithoutEvidenceDecodesWithNilCE() throws {
        let json = #"""
        [{"id":"evt_2","type":"access","grantId":null,
          "detail":{"actorName":"Diabetes Nurse"},
          "occurredAt":"2026-07-06T11:00:00Z"},
         {"id":"evt_3","type":"revoke","detail":null,"occurredAt":"2026-07-06T12:00:00Z"}]
        """#
        let dtos = try JSONDecoder().decode([LedgerEventDTO].self, from: Data(json.utf8))
        let events = dtos.map(MaudeBackendService.walletEvent(from:))
        #expect(events[0].ce == nil)     // detail without ce → nil, no throw
        #expect(events[1].ce == nil)     // null detail → nil, no throw
    }

    @Test func partialEvidenceBlockDecodes() throws {
        // Older/stub evidence may miss fields — every CE field is optional.
        let json = #"""
        [{"id":"evt_4","type":"grant",
          "detail":{"ce":{"receipt_id":"rcpt_only"}},
          "occurredAt":"2026-07-06T13:00:00Z"}]
        """#
        let dtos = try JSONDecoder().decode([LedgerEventDTO].self, from: Data(json.utf8))
        let ce = try #require(MaudeBackendService.walletEvent(from: dtos[0]).ce)
        #expect(ce.receiptId == "rcpt_only")
        #expect(ce.eventHash == nil)
        #expect(ce.shortHash == nil)
    }

    @Test func walletGrantDecodesWithoutCeGrantRef() throws {
        // Backward compatibility: a grant persisted/serialized BEFORE the CE
        // fields existed must still decode (ceGrantRef defaults to nil).
        let legacy = #"""
        {"id":"6BA7B810-9DAD-11D1-80B4-00C04FD430C8","recipient_name":"Steno Diabetes Center",
         "recipient_type":"clinical","scope_keys":["glucose"],"is_active":true}
        """#
        let grant = try JSONDecoder().decode(WalletGrant.self, from: Data(legacy.utf8))
        #expect(grant.ceGrantRef == nil)
        #expect(grant.recipientName == "Steno Diabetes Center")
    }

    @Test func walletGrantRoundTripsCeGrantRef() throws {
        let grant = WalletGrant(
            id: UUID(), recipientName: "Steno Diabetes Center",
            recipientType: .clinical, scopeKeys: ["glucose"], isActive: true,
            ceGrantRef: "grant_chain_7")
        let data = try JSONEncoder().encode(grant)
        let back = try JSONDecoder().decode(WalletGrant.self, from: data)
        #expect(back.ceGrantRef == "grant_chain_7")
    }
}
