#!/usr/bin/env python3
"""List / expire TestFlight builds via the App Store Connect API.

  asc_cleanup_builds.py list         # read-only: show every build + beta groups
  asc_cleanup_builds.py expire-old   # expire EVERY build except the latest VALID one

Expiring removes a build from testers (public link + internal). The latest VALID
build is always kept; the script refuses to run if there is no VALID build to keep.
ES256 JWT signed with openssl (no third-party deps).
"""
import base64, json, subprocess, sys, time, urllib.request, urllib.error, os

KEY_ID    = "656L9P8JY3"
ISSUER_ID = "830c96d2-1922-4e68-9736-56940ebf9bc2"
KEY_PATH  = os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_656L9P8JY3.p8")
BUNDLE_ID = "xyz.ppcn.maude"
API       = "https://api.appstoreconnect.apple.com"


def b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    assert der[0] == 0x30
    i = 2
    if der[1] & 0x80:
        i = 2 + (der[1] & 0x7F)
    assert der[i] == 0x02
    rlen = der[i + 1]
    r = der[i + 2 : i + 2 + rlen]
    j = i + 2 + rlen
    assert der[j] == 0x02
    slen = der[j + 1]
    s = der[j + 2 : j + 2 + slen]
    return r.lstrip(b"\x00").rjust(32, b"\x00") + s.lstrip(b"\x00").rjust(32, b"\x00")


def token() -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    payload = {"iss": ISSUER_ID, "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"}
    si = b64url(json.dumps(header).encode()) + "." + b64url(json.dumps(payload).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
                         input=si.encode(), capture_output=True, check=True).stdout
    return si + "." + b64url(der_to_raw(der))


def api(method, path, body=None):
    url = path if path.startswith("http") else API + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + token())
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def ver_key(v):
    try:
        return tuple(int(x) for x in str(v).split("."))
    except Exception:
        return (0,)


def get_app_id():
    st, apps = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    if st != 200 or not apps.get("data"):
        print("app lookup failed", st, apps); sys.exit(1)
    return apps["data"][0]["id"]


def beta_groups(app_id):
    st, d = api("GET", f"/v1/betaGroups?filter[app]={app_id}&limit=200")
    if st != 200:
        return []
    return d.get("data", [])


def all_builds(app_id):
    builds, idx = [], {}
    url = (f"/v1/builds?filter[app]={app_id}&limit=200&include=betaGroups"
           "&fields[builds]=version,processingState,expired,uploadedDate,betaGroups"
           "&fields[betaGroups]=name&sort=-uploadedDate")
    while url:
        st, d = api("GET", url)
        if st != 200:
            print("builds query failed", st, d); sys.exit(1)
        for inc in d.get("included", []):
            if inc["type"] == "betaGroups":
                idx[inc["id"]] = inc["attributes"].get("name", inc["id"])
        builds += d.get("data", [])
        url = d.get("links", {}).get("next")
    return builds, idx


def group_names(b, idx):
    rel = b.get("relationships", {}).get("betaGroups", {}).get("data", []) or []
    return [idx.get(g["id"], g["id"]) for g in rel]


def build_group_ids(b):
    return [g["id"] for g in (b.get("relationships", {}).get("betaGroups", {}).get("data") or [])]


def review_state(build_id):
    st, d = api("GET", f"/v1/betaAppReviewSubmissions?filter[build]={build_id}")
    if st != 200 or not d.get("data"):
        return None
    return d["data"][0]["attributes"].get("betaReviewState")


def phase1(app_id, groups, builds, gidx, execute):
    """Option A — internal cleanup now, submit latest for external review; keep
    current public-link builds live until the latest is approved."""
    internal_gids = {g["id"] for g in groups if g["attributes"].get("isInternalGroup")}
    external_gids = [g["id"] for g in groups if not g["attributes"].get("isInternalGroup")]
    valid = [b for b in builds if b["attributes"].get("processingState") == "VALID" and not b["attributes"].get("expired")]
    valid.sort(key=lambda b: ver_key(b["attributes"]["version"]), reverse=True)
    if not valid:
        print("ABORT: no VALID build to keep."); sys.exit(2)
    latest = valid[0]
    lid, lver = latest["id"], latest["attributes"]["version"]

    expire, unlink_internal, attach_external = [], [], []
    for b in builds:
        if b["id"] == lid or b["attributes"].get("expired"):
            continue
        bgids = build_group_ids(b)
        if any(g in external_gids for g in bgids):
            # On the public link — keep available externally; remove from internal only.
            for ig in (internal_gids & set(bgids)):
                unlink_internal.append((b, ig))
        else:
            expire.append(b)
    for eg in external_gids:
        if eg not in build_group_ids(latest):
            attach_external.append((latest, eg))

    print(f"PLAN (latest kept = v{lver}):")
    print(f"  expire {len(expire)} internal-only build(s): " + ", ".join("v" + b['attributes']['version'] for b in expire))
    print(f"  remove from internal group: " + (", ".join("v" + b['attributes']['version'] for b, _ in unlink_internal) or "none"))
    print(f"  attach v{lver} to external group(s): " + (", ".join(gidx.get(eg, eg) for _, eg in attach_external) or "already attached"))
    print(f"  submit v{lver} for Beta App Review")
    if not execute:
        print("\n(dry-run — pass `apply` to execute.)"); return

    print("\nEXECUTING:")
    for b in expire:
        st, r = api("PATCH", f"/v1/builds/{b['id']}", {"data": {"type": "builds", "id": b["id"], "attributes": {"expired": True}}})
        print(f"  expire v{b['attributes']['version']:<6} → {'OK' if st in (200, 204) else f'FAIL {st} {r}'}")
    for b, ig in unlink_internal:
        st, r = api("DELETE", f"/v1/betaGroups/{ig}/relationships/builds", {"data": [{"type": "builds", "id": b["id"]}]})
        print(f"  unlink v{b['attributes']['version']:<6} from internal → {'OK' if st in (200, 204) else f'FAIL {st} {r}'}")
    for b, eg in attach_external:
        st, r = api("POST", f"/v1/betaGroups/{eg}/relationships/builds", {"data": [{"type": "builds", "id": b["id"]}]})
        print(f"  attach v{b['attributes']['version']} → {gidx.get(eg, eg)} → {'OK' if st in (200, 201, 204) else f'FAIL {st} {r}'}")
    # Submit latest for Beta App Review (external availability).
    st, r = api("POST", "/v1/betaAppReviewSubmissions",
                {"data": {"type": "betaAppReviewSubmissions", "relationships": {"build": {"data": {"type": "builds", "id": lid}}}}})
    if st in (200, 201):
        print(f"  beta review v{lver} → SUBMITTED")
    else:
        print(f"  beta review v{lver} → {st} {r.get('errors', [{}])[0].get('detail', r)}")
    print("\nPhase 1 done. After v{0} is approved for external, run `expire-old` to retire the old public-link builds.".format(lver))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    app_id = get_app_id()
    groups = beta_groups(app_id)
    builds, gidx = all_builds(app_id)

    valid = [b for b in builds
             if b["attributes"].get("processingState") == "VALID" and not b["attributes"].get("expired")]
    valid.sort(key=lambda b: ver_key(b["attributes"]["version"]), reverse=True)
    latest = valid[0] if valid else None

    print(f"App {app_id} ({BUNDLE_ID}) · {len(builds)} build(s)\n")
    print("Beta groups:")
    for g in groups:
        a = g["attributes"]
        kind = "INTERNAL" if a.get("isInternalGroup") else "EXTERNAL"
        pub = f" public-link={'ON' if a.get('publicLinkEnabled') else 'off'}"
        link = f" {a.get('publicLink')}" if a.get('publicLink') else ""
        print(f"  - {a.get('name'):<22} [{kind}]{pub}{link}")
    print()
    print("Builds (newest first):")
    for b in sorted(builds, key=lambda b: ver_key(b["attributes"]["version"]), reverse=True):
        a = b["attributes"]
        mark = "  <<< KEEP (latest VALID)" if latest and b["id"] == latest["id"] else ""
        gnames = ", ".join(group_names(b, gidx)) or "—"
        print(f"  v{str(a.get('version')):<7} {str(a.get('processingState')):<11} "
              f"expired={str(a.get('expired')):<5} {str(a.get('uploadedDate'))[:19]}  groups=[{gnames}]{mark}")

    if cmd == "list":
        print("\n(dry-run — nothing changed. Run `expire-old` to expire all but the latest VALID build.)")
        return

    if cmd in ("phase1", "phase1-apply"):
        phase1(app_id, groups, builds, gidx, execute=(cmd == "phase1-apply"))
        return

    if cmd == "watch-finish":
        # Self-contained finisher: when the latest build is approved for external
        # testing, expire every other non-expired build (so only the latest
        # remains on internal + public link). Prints a one-line status with a
        # machine-readable prefix (DONE: / PENDING: / ALERT:).
        if not latest:
            print("ALERT: no VALID build found"); return
        state = review_state(latest["id"])
        if state == "APPROVED":
            targets = [b for b in builds if b["id"] != latest["id"] and not b["attributes"].get("expired")]
            ok = 0
            for b in targets:
                st, _ = api("PATCH", f"/v1/builds/{b['id']}",
                            {"data": {"type": "builds", "id": b["id"], "attributes": {"expired": True}}})
                ok += 1 if st in (200, 204) else 0
            print(f"DONE: v{latest['attributes']['version']} APPROVED for external; expired {ok}/{len(targets)} old build(s). Only v{latest['attributes']['version']} remains.")
        elif state == "REJECTED":
            print(f"ALERT: v{latest['attributes']['version']} beta review REJECTED — needs attention.")
        else:
            print(f"PENDING: v{latest['attributes']['version']} beta review = {state or 'not yet submitted'}")
        return

    if cmd == "expire-old":
        if not latest:
            print("\nABORT: no VALID non-expired build to keep — expiring would leave testers with nothing.")
            sys.exit(2)
        targets = [b for b in builds if b["id"] != latest["id"] and not b["attributes"].get("expired")]
        print(f"\nKeeping v{latest['attributes']['version']} ({latest['id']}). "
              f"Expiring {len(targets)} build(s):")
        for b in targets:
            a = b["attributes"]
            st, resp = api("PATCH", f"/v1/builds/{b['id']}",
                           {"data": {"type": "builds", "id": b["id"], "attributes": {"expired": True}}})
            print(f"  v{str(a.get('version')):<7} → {'EXPIRED OK' if st in (200, 204) else f'FAILED {st} {resp}'}")
        print("\nDone. Only the latest VALID build remains available to testers.")


if __name__ == "__main__":
    main()
