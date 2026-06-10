# iOS → Backend handoffs (frozen-contract exceptions)

The iOS go-live session consumes the FROZEN backend HTTP contract. When a task needs a
new or changed endpoint/DTO, it is appended here instead of inventing a client call.

_As of 2026-06-10: none. The existing routes cover the go-live daily-use loop._

## iGrant.io real integration (researched 2026-06-10)
Refs: https://docs.igrant.io/docs/category/openid4vc-api/issuer · https://github.com/L3-iGrant
- **iOS SDK** `L3-iGrant/data-wallet-sdk-ios` = Aries Mobile Agent (`ama-ios-sdk`), **CocoaPods**, deps:
  Hyperledger **Indy SDK**, secp256k1, "COVID-19 Global SDK". Heavy + supply-chain-significant; Liviqa
  has no CocoaPods. **Not recommended** to embed for this app.
- **Recommended real path = OpenID4VP via the iGrant Data Wallet app** (no heavy SDK): Liviqa is a
  *verifier* — open the wallet with an OpenID4VP request (deep link/QR), receive an SD-JWT VP, verify it.
  Mirrors the existing `DfGWalletService` OpenID4VP seam. **Needs (backend/credentials):**
  1. iGrant **verifier/relying-party registration** → `client_id`.
  2. A verifier endpoint that builds the OpenID4VP `request_uri` (presentation_definition / DCQL) and
     verifies the returned SD-JWT VP (nonce, issuer trust list).
  3. iGrant **org id + API key** (and, for issuing, OpenID4VCI credential definitions).
- Until those exist, the in-app iGrant flow stays the high-fidelity **simulation** (OpenID4VP + SD-JWT +
  consent receipt) — correct for demos/pilots.
- Reusable: `L3-iGrant/qr-code-scanner-ios` (Swift, SPM/CocoaPod) if a QR step is wanted.

## iGrant.io — how to start a real (test-environment) integration (2026-06-10)
Ref: https://docs.igrant.io/docs/getting-started/ — there is NO self-serve sandbox.
1. **Email iGrant Developer Support** (developer support address on their docs) to request **API keys +
   organisation id** and **demo-environment** access. Business/onboarding step — must be done by Claus/team.
2. **Verifier (OpenID4VP)**: backend endpoint that builds the presentation request
   (presentation_definition / DCQL) and verifies the returned SD-JWT VP (nonce, issuer trust).
3. **iOS seam**: open the iGrant Data Wallet via same-device OpenID4VP deep link → handle redirect_uri
   callback (mirror `DfGWalletService`). Liviqa-side, ready to build once #1 provides keys/org id.
- Until keys exist, the in-app iGrant flow stays the simulation (amber "SIMULATION · NOT YET INTEGRATED").
  After: flip to green "TEST ENVIRONMENT" like the DfG/Partisia track.
