#!/usr/bin/env python3
# build_digest_email.py — render the Liviqa TestFlight feedback digest as a
# PPCN-design-system HTML email. Reads a JSON array of items on stdin; writes
# HTML to --out (default /tmp/liviqa_digest.html) and prints the path.
#
# Each item: { "fb", "build", "tester", "date", "comment",
#              "clickup_url" (optional), "screenshot" (optional local path) }
import sys, os, json, html, base64, subprocess, tempfile, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument("--out", default="/tmp/liviqa_digest.html")
args = ap.parse_args()
items = json.load(sys.stdin)
if not isinstance(items, list): items = [items]

def b64_file(path):
    with open(path, "rb") as f: return base64.b64encode(f.read()).decode()

def b64_shot(path, width=300):
    if not path or not os.path.exists(path): return None
    try:
        tmp = tempfile.mktemp(suffix=".jpg")
        subprocess.run(["sips", "--resampleWidth", str(width), path, "--out", tmp],
                       capture_output=True)
        p = tmp if os.path.exists(tmp) else path
        return b64_file(p)
    except Exception:
        return None

def esc(s): return html.escape(str(s or ""))
def br(s): return esc(s).replace("\n", "<br>")

logo = b64_file(os.path.join(HERE, "assets", "ppcn_logo.png"))
n = len(items)
plural = "item" if n == 1 else "items"

cards = ""
for it in items:
    shot = b64_shot(it.get("screenshot"))
    shot_html = (f'<td valign="top" style="padding-right:15px;"><img src="data:image/jpeg;base64,{shot}" '
                 f'width="118" style="display:block;border:1px solid #E4E2DE;border-radius:8px;" alt="screen"></td>') if shot else ""
    url = it.get("clickup_url")
    btn = (f'<a href="{esc(url)}" style="display:inline-block;background:#3563E9;color:#FFFFFF;text-decoration:none;'
           f'font-weight:600;font-size:13px;padding:10px 17px;border-radius:8px;">Open the ClickUp task &rarr;</a>') if url else ""
    meta = " &middot; ".join(x for x in [esc(it.get("fb")),
            "build " + esc(it.get("build")) if it.get("build") else "",
            esc(it.get("tester")), esc(it.get("date"))] if x)
    cards += f'''
  <tr><td style="padding:16px 30px 0;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F3F2EF;border:1px solid #E4E2DE;border-radius:14px;"><tr><td style="padding:17px 19px;">
      <div style="font-family:'JetBrains Mono',Menlo,monospace;font-size:12px;color:#0D1117;font-weight:600;">{meta}</div>
      <div style="margin:12px 0;padding:11px 15px;background:#FFFFFF;border-left:3px solid #D4622F;border-radius:0 8px 8px 0;font-size:14px;line-height:1.55;color:#0D1117;">&ldquo;{br(it.get("comment"))}&rdquo;</div>
      <table role="presentation" cellpadding="0" cellspacing="0" style="margin-top:6px;"><tr>
        {shot_html}
        <td valign="top">
          {btn}
          <div style="font-size:12px;color:#6B7785;margin-top:11px;line-height:1.55;">Approve by moving the task, or reply<br><b style="color:#0D1117;font-family:'JetBrains Mono',Menlo,monospace;">approve {esc(it.get("fb"))}</b> to build.</div>
        </td>
      </tr></table>
    </td></tr></table>
  </td></tr>'''

HTML = f'''<!doctype html><html><head><meta charset="utf-8">
<style>@import url('https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@500;600&display=swap');body{{margin:0;background:#FAFAF8;}}</style></head>
<body style="margin:0;background:#FAFAF8;font-family:'Inter',Helvetica,Arial,sans-serif;color:#0D1117;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#FAFAF8;padding:26px 0;"><tr><td align="center">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:600px;max-width:94%;background:#FFFFFF;border:1px solid #E4E2DE;border-radius:16px;overflow:hidden;">
  <tr><td style="padding:24px 30px 0;"><img src="data:image/png;base64,{logo}" width="118" alt="PPCN" style="display:block;"></td></tr>
  <tr><td style="padding:16px 30px 0;"><div style="height:3px;width:48px;background:#D4622F;border-radius:3px;"></div></td></tr>
  <tr><td style="padding:14px 30px 0;">
     <div style="font-family:'JetBrains Mono',Menlo,monospace;font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:#6B7785;">Liviqa &middot; TestFlight beta</div>
     <div style="font-family:'Outfit',Helvetica,Arial,sans-serif;font-weight:700;font-size:27px;letter-spacing:-.4px;margin-top:7px;color:#0D1117;">{n} new feedback {plural} to approve</div>
     <div style="font-size:14px;color:#46586B;margin-top:9px;line-height:1.55;">{"One tester comment" if n==1 else str(n)+" tester comments"} arrived since the last check. Nothing has been built &mdash; each is logged and waiting for your go-ahead.</div>
  </td></tr>
  {cards}
  <tr><td style="padding:22px 30px 26px;">
     <div style="border-top:1px solid #E4E2DE;padding-top:15px;font-family:'JetBrains Mono',Menlo,monospace;font-size:10px;letter-spacing:.04em;color:#6B7785;line-height:1.8;">PPCN &middot; ppcn.xyz &middot; Liviqa beta operations<br>Automated daily feedback digest &middot; nothing is built without your approval.</div>
  </td></tr>
</table></td></tr></table></body></html>'''
with open(args.out, "w") as f: f.write(HTML)
print(args.out)
