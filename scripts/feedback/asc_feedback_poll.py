#!/usr/bin/env python3
# asc_feedback_poll.py — poll App Store Connect TestFlight feedback, emit NEW items.
# Prints a JSON array of submissions not seen before, and updates the seen-state file.
# Used by the scheduled "liviqa-feedback-monitor" task; safe to run by hand.
import jwt, time, json, os, urllib.request, urllib.error, sys

KEY_ID="656L9P8JY3"
ISSUER_ID="830c96d2-1922-4e68-9736-56940ebf9bc2"
KEY_PATH=os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_656L9P8JY3.p8")
APP="6776228205"
STATE=os.path.expanduser("~/.liviqa-feedback-seen.json")

def token():
    pk=open(KEY_PATH).read()
    return jwt.encode({"iss":ISSUER_ID,"iat":int(time.time()),"exp":int(time.time())+1200,
                       "aud":"appstoreconnect-v1"},pk,algorithm="ES256",
                      headers={"kid":KEY_ID,"typ":"JWT"})

def get(url,tok):
    req=urllib.request.Request(url,headers={"Authorization":f"Bearer {tok}"})
    with urllib.request.urlopen(req) as r: return json.load(r)

def fetch():
    tok=token()
    base="https://api.appstoreconnect.apple.com/v1"
    d=get(f"{base}/apps/{APP}/betaFeedbackScreenshotSubmissions?limit=50&sort=-createdDate&include=build,tester",tok)
    inc={i["id"]:i for i in d.get("included",[])}
    out=[]
    for fb in d.get("data",[]):
        a=fb["attributes"]; rel=fb.get("relationships",{})
        bid=(rel.get("build",{}).get("data") or {}).get("id")
        tid=(rel.get("tester",{}).get("data") or {}).get("id")
        build=inc.get(bid,{}).get("attributes",{}).get("version","?") if bid else "?"
        t=inc.get(tid,{}).get("attributes",{}) if tid else {}
        shots=a.get("screenshots") or []
        out.append({"id":fb["id"],"fb":"FB-"+fb["id"][:8],"date":(a.get("createdDate") or "")[:10],
                    "build":build,"device":a.get("deviceModel"),"os":a.get("osVersion"),
                    "tester":f'{t.get("firstName","")} {t.get("lastName","")}'.strip(),
                    "email":t.get("email"),"comment":(a.get("comment") or "").strip(),
                    "screenshot":(shots[0].get("url") if shots else None)})
    return out

def main():
    seen=set()
    if os.path.exists(STATE):
        try: seen=set(json.load(open(STATE)).get("seen",[]))
        except Exception: pass
    items=fetch()
    seed = "--seed" in sys.argv      # mark all current as seen, emit nothing (first run)
    new=[i for i in items if i["id"] not in seen] if not seed else []
    json.dump({"seen":[i["id"] for i in items],"updated":int(time.time())},open(STATE,"w"))
    print(json.dumps(new,ensure_ascii=False,indent=2))

if __name__=="__main__": main()
