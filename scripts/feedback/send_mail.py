#!/usr/bin/env python3
# send_mail.py — send an email via the Mac's Mail.app (account cn@ppcn.xyz), no
# stored credentials. Usage: echo "<body>" | send_mail.py --to a@b.com --subject "..."
import sys, subprocess, argparse

ap=argparse.ArgumentParser()
ap.add_argument("--to",required=True)
ap.add_argument("--subject",required=True)
ap.add_argument("--from-account",default="cn@ppcn.xyz")
args=ap.parse_args()
body=sys.stdin.read()

def esc(s): return s.replace("\\","\\\\").replace('"','\\"')
# build body via AppleScript list-join to keep newlines intact
lines="{"+", ".join('"'+esc(l)+'"' for l in body.split("\n"))+"}"
script=f'''
set theBody to ""
repeat with ln in {lines}
  set theBody to theBody & (ln as text) & return
end repeat
tell application "Mail"
  set msg to make new outgoing message with properties {{subject:"{esc(args.subject)}", content:theBody, visible:false}}
  tell msg
    make new to recipient at end of to recipients with properties {{address:"{esc(args.to)}"}}
    try
      set sender to "{esc(args.from_account)}"
    end try
  end tell
  send msg
end tell
'''
r=subprocess.run(["osascript","-e",script],capture_output=True,text=True)
if r.returncode!=0:
    sys.stderr.write(r.stderr); sys.exit(r.returncode)
print("sent")
