# Backstage v0.1.1 — what this build is proven to do (generated 2026-08-31 06:13Z)

Backstage is sold as the current version it is at: the first, smallest high-impact build.
Every claim below is generated from a falsifier that ran end-to-end on real machines; the
scorecard rows are the source of truth. Nothing on this page is hand-written marketing.

## Proven, end-to-end
- **S1+S6 CDP raise storm bounced then breaker** — 6 bounces max 4ms, BREAKER_OPEN at 7th — guard can never become the load _(mode: Backstage.app v0.1.0, live seat, HS guard stopped; 2026-08-31_0231Z)_
- **S2 alternate raise path (AppleScript frontmost) bounced** — non-CDP steal path caught _(mode: Backstage.app v0.1.0; 2026-08-31_0229Z)_
- **S3 user-initiated raise of a jailed app passes** — USER_PASS logged, no bounce _(mode: Backstage.app v0.1.0 · synthetic HID (posted shift flagsChanged); real-user evidence accrues in live use; 2026-08-31_0229Z)_
- **S4 dictation shield blocks ALL programmatic raises (manual mode; auto ships OFF on warm-mic boxes)** — non-jailed programmatic raise bounced why=shield _(mode: Backstage.app v0.1.0; 2026-08-31_0231Z)_
- **S5 allow token: pass for exactly TTL, bounce after expiry** — ALLOW during TTL, BOUNCE 3ms post-expiry (first run was a harness flaw: seat already frontmost → no activation event) _(mode: Backstage.app v0.1.0 + backstage-allow CLI; 2026-08-31_0232Z)_
- **S7 per-instance discrimination: seat bounced, user-profile Chrome never** — seat 3/3 bounced, user instance 0 bounces _(mode: Backstage.app v0.1.0, two same-bundle Chromes interleaved; 2026-08-31_0229Z)_

## The build you are downloading
- Signed with Developer ID and notarized by Apple — it opens like any Mac app, no
  right-click needed. Integrity also rides the published SHA-256 and the ssh-ed25519 release
  signature (`RELEASE.sha256.sig`, namespace `backstage-app`, signer `release@voxordo.io`).

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
ssh-keygen -Y verify -f allowed_signers -I release@voxordo.io -n backstage-app \
  -s RELEASE.sha256.sig < RELEASE.sha256
```
