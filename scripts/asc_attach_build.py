#!/usr/bin/env python3
"""Attach the freshly-uploaded build to a TestFlight beta group via the
App Store Connect API. ES256 JWT is signed with openssl (no third-party deps);
the DER signature is converted to the raw r||s form the JWT spec requires.

Usage:
  asc_attach_build.py <build_version> [group_name]
    build_version : CFBundleVersion of the build (e.g. "10.2")
    group_name    : beta group display name (default "Internal DfG")
"""
import base64, json, subprocess, sys, time, urllib.request, urllib.error, os

KEY_ID    = "656L9P8JY3"
ISSUER_ID = "830c96d2-1922-4e68-9736-56940ebf9bc2"
KEY_PATH  = os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_656L9P8JY3.p8")
BUNDLE_ID = "dev.liviqa.app"
API       = "https://api.appstoreconnect.apple.com"


def b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    # ASN.1: 0x30 len 0x02 rlen r 0x02 slen s
    assert der[0] == 0x30
    i = 2
    if der[1] & 0x80:  # long form length
        i = 2 + (der[1] & 0x7F)
    assert der[i] == 0x02
    rlen = der[i + 1]
    r = der[i + 2 : i + 2 + rlen]
    j = i + 2 + rlen
    assert der[j] == 0x02
    slen = der[j + 1]
    s = der[j + 2 : j + 2 + slen]
    r = r.lstrip(b"\x00").rjust(32, b"\x00")
    s = s.lstrip(b"\x00").rjust(32, b"\x00")
    return r + s


def token() -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    payload = {"iss": ISSUER_ID, "iat": now, "exp": now + 1000,
               "aud": "appstoreconnect-v1"}
    signing_input = b64url(json.dumps(header).encode()) + "." + b64url(json.dumps(payload).encode())
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
        input=signing_input.encode(), capture_output=True, check=True).stdout
    return signing_input + "." + b64url(der_to_raw(der))


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


def main():
    build_version = sys.argv[1] if len(sys.argv) > 1 else "10.2"
    group_name = sys.argv[2] if len(sys.argv) > 2 else "Internal DfG"

    st, apps = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    if st != 200 or not apps.get("data"):
        print("app lookup failed", st, apps); sys.exit(1)
    app_id = apps["data"][0]["id"]
    print("app", apps["data"][0]["attributes"]["name"], app_id)

    # Poll for the build + processing state
    build = None
    for attempt in range(40):  # ~20 min
        st, builds = api("GET",
            f"/v1/builds?filter[app]={app_id}&filter[version]={build_version}&limit=1")
        data = builds.get("data") or []
        if data:
            build = data[0]
            state = build["attributes"].get("processingState")
            print(f"[{attempt}] build {build_version} -> {state}")
            if state == "VALID":
                break
            if state in ("FAILED", "INVALID"):
                print("processing failed"); sys.exit(1)
        else:
            print(f"[{attempt}] build {build_version} not visible yet")
        time.sleep(30)
    if not build:
        print("build never appeared"); sys.exit(1)
    build_id = build["id"]

    if build["attributes"].get("processingState") != "VALID":
        print("build not VALID yet; cannot attach. Re-run later."); sys.exit(2)

    # Find the beta group
    st, groups = api("GET", f"/v1/betaGroups?filter[app]={app_id}&limit=200")
    grp = next((g for g in groups.get("data", [])
                if g["attributes"]["name"].strip().lower() == group_name.lower()), None)
    if not grp:
        names = [g["attributes"]["name"] for g in groups.get("data", [])]
        print("group not found. available:", names); sys.exit(1)
    group_id = grp["id"]
    print("group", group_name, group_id)

    # Attach build to group
    st, resp = api("POST", f"/v1/betaGroups/{group_id}/relationships/builds",
                   {"data": [{"type": "builds", "id": build_id}]})
    print("attach status", st, resp if resp else "(ok)")
    if st in (200, 201, 204):
        print("ATTACHED build", build_version, "to", group_name)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
