#!/usr/bin/env python3
# send_html_mail.py — send an HTML email via Mac Mail.app (account cn@ppcn.xyz),
# no stored creds. Usage: send_html_mail.py --to a@b.com --subject "..." --html-file /path.html
import sys, subprocess, argparse
ap = argparse.ArgumentParser()
ap.add_argument("--to", required=True)
ap.add_argument("--subject", required=True)
ap.add_argument("--html-file", required=True)
ap.add_argument("--from-account", default="cn@ppcn.xyz")
a = ap.parse_args()
def esc(s): return s.replace("\\", "\\\\").replace('"', '\\"')
script = f'''
set theHTML to read (POSIX file "{esc(a.html_file)}") as «class utf8»
tell application "Mail"
  set msg to make new outgoing message with properties {{subject:"{esc(a.subject)}", visible:false}}
  tell msg
    set html content to theHTML
    make new to recipient at end of to recipients with properties {{address:"{esc(a.to)}"}}
    try
      set sender to "{esc(a.from_account)}"
    end try
  end tell
  send msg
end tell
'''
r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
if r.returncode != 0:
    sys.stderr.write(r.stderr); sys.exit(r.returncode)
print("sent")
