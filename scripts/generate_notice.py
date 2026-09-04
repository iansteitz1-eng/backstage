#!/usr/bin/env python3
"""generate_notice.py — GENERATE NOTICE.md + VERSION.json from the falsifier scorecard.
House law (canon _pricing update_2026-08-26b, SELL-AS-CURRENT-VERSION): a micro ships at v0
ONLY with a notice generated from its scorecard — it lists exactly the scenarios that passed,
states what the product will not do, and names the escalation path. Never hand-write claims.
Usage: generate_notice.py  (reads the lane scorecard + dist/release.json; writes NOTICE.md,
VERSION.json into the repo root — build-app.sh packs them into the zip)."""
import json, os, re, sys, datetime

HOME = os.path.expanduser("~")
SCORECARD = f"{HOME}/Desktop/lore/ops/backstage-lane/scorecard.md"
RELEASE = f"{HOME}/dev/backstage/dist/release.json"
OUT_DIR = f"{HOME}/dev/backstage"

rows = []
for line in open(SCORECARD, encoding="utf-8"):
    m = re.match(r"\|\s*([0-9_TZ-]+)\s*\|([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\|", line)
    if not m:
        continue
    stamp, scenario, mode, result, evidence = (g.strip() for g in m.groups())
    if stamp.lower() == "stamp":
        continue
    rows.append({"stamp": stamp, "scenario": scenario, "mode": mode,
                 "result": result, "passed": result.startswith("✅"),
                 "evidence": evidence})

# The store page claims ONLY what passed on the sold artifact — prototype/probe rows are
# lane evidence, not product claims.
product_rows = [r for r in rows if "Backstage.app" in r["mode"]]
passed = [r for r in product_rows if r["passed"]]
if not passed:
    sys.exit("no ✅ Backstage.app rows — nothing to sell; a notice cannot be generated")

rel = json.load(open(RELEASE)) if os.path.exists(RELEASE) else {}
version = rel.get("version", "0.1.0")
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%MZ")

notice = f"""# Backstage v{version} — what this build is proven to do (generated {now})

Backstage is sold as the current version it is at: the first, smallest high-impact build.
Every claim below is generated from a falsifier that ran end-to-end on real machines; the
scorecard rows are the source of truth. Nothing on this page is hand-written marketing.

## Proven, end-to-end
"""
for r in passed:
    notice += f"- **{r['scenario']}** — {r['result'].lstrip('✅ ').strip()} _(mode: {r['mode']}; {r['stamp']})_\n"

codesign = rel.get("codesign", "ad-hoc")
if "notarized" in codesign:
    sig_line = """- Signed with Developer ID and notarized by Apple — it opens like any Mac app, no
  right-click needed. Integrity also rides the published SHA-256 and the ssh-ed25519 release
  signature (`RELEASE.sha256.sig`, namespace `backstage-app`, signer `release@voxordo.io`)."""
else:
    sig_line = """- No Developer ID signature on this build (ad-hoc signed): macOS Gatekeeper requires
  right-click → Open on first launch. Integrity rides the published SHA-256 and the
  ssh-ed25519 release signature (`RELEASE.sha256.sig`, namespace `backstage-app`,
  signer `release@voxordo.io`, `allowed_signers` shipped beside the artifact)."""

notice += f"""
## The build you are downloading
{sig_line}

## What it will NOT do (yet, honestly)
- Zero-TCC-prompt install is the design (NSRunningApplication only, no Accessibility) but the
  clean-account proof (S8) has not run yet — it is the next scorecard row.
- The dictation-shield **auto** mode (mic-in-use trigger) ships OFF: machines with an
  always-warm mic pipeline read the input device as busy at idle. Manual shield is proven.
- Voice-driven app switching (Voice Control, "Hey Siri, open X") produces no keyboard/mouse
  input, so the shield will bounce it once while engaged. Known caveat, documented.
- Windows/Linux: no. macOS 13+ only.

## Escalation
Something bounced that shouldn't have (or didn't that should)? Every decision is in
`~/Library/Logs/backstage/decisions.jsonl` — send it with a note to hello@voxordo.io and it
becomes a falsifier in the next build. Storming apps trip a breaker (6 bounces/60s per app,
5-minute pause) so the guard can never become its own problem.

## Verify your download
```
shasum -a 256 -c SHA256SUMS
ssh-keygen -Y verify -f allowed_signers -I release@voxordo.io -n backstage-app \\
  -s RELEASE.sha256.sig < RELEASE.sha256
```
"""

open(f"{OUT_DIR}/NOTICE.md", "w", encoding="utf-8").write(notice)

# No artifact hash in here — VERSION.json ships INSIDE the zip; the zip's hash lives in the
# external SHA256SUMS + release.json beside the download.
vj = {
    "product": "backstage",
    "version": version,
    "generated": now,
    "scorecard_rows_passed": [f"{r['stamp']} {r['scenario']}" for r in passed],
    "scorecard_rows_open": [f"{r['stamp']} {r['scenario']}" for r in rows if not r["passed"]],
    "codesign": rel.get("codesign"),
}
json.dump(vj, open(f"{OUT_DIR}/VERSION.json", "w", encoding="utf-8"), indent=2)
print(f"NOTICE.md + VERSION.json generated from {len(passed)} ✅ rows ({len(rows)} total)")
