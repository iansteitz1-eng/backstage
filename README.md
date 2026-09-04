# Backstage

Your AI agents keep grabbing your screen. Backstage makes them stay backstage.

Anyone running browser automation (Claude, CDP seats, Playwright, agent stacks) knows the moment: a window you did not ask for jumps in front of you, your dictation dies mid-sentence, your typing lands in the wrong app. Backstage is a macOS menu-bar app that ends it. Your agents keep working, in the background, where they belong. Your screen stays yours.

![Backstage menu](docs/menu.png)

## What it does

- Bounces uninvited grabs and puts you back where you were, measured in single-digit milliseconds on the shipped build.
- Knows your browser from your agent's browser, per running process. Your own Chrome is never touched, even though it is the same app.
- Your clicks always win. When you open a guarded app, it opens. Only programmatic grabs get bounced.
- Dictation shield. Engage it and nothing may steal focus at all while you speak.
- Agents can ask permission. A one-line CLI grants a timed on-screen pass, for the login your agent genuinely needs you to type. It expires by itself.
- Storm-proof by design. A misbehaving agent trips a breaker (6 bounces per 60 seconds per app, then a 5-minute pause) instead of turning the guard into its own problem.
- Every decision is logged, locally, in `~/Library/Logs/backstage/decisions.jsonl`.
- Runs entirely on your machine. No account, no network calls, nothing leaves your Mac.

## Why it exists

We built Backstage because it happened to us. Our own agent's browser stole the founder's screen every fifteen minutes, mid-dictation, until the words he was speaking were being typed into the agent's window instead of his own. We traced the exact line of code that does it, a standard call every browser-automation stack makes, and realized every AI-agent user has this problem.

## Build it from source

Requires macOS 13 or newer and Xcode command line tools.

```
git clone https://github.com/iansteitz1-eng/backstage.git
cd backstage
./build-app.sh
open dist/Backstage.app
```

The unsigned build you make yourself is the same code; macOS will ask you to allow it the first time. The `backstage-allow` CLI is built alongside it.

## Get the signed build

The notarized, Developer ID-signed `Backstage.app` is at [voxordo.io/backstage](https://voxordo.io/backstage?utm_source=github&utm_medium=readme&utm_campaign=backstage). It opens like any Mac app, no right-click needed, and updates come with it.

## What it will not do (yet)

- The dictation-shield auto mode (mic-in-use trigger) ships off: machines with an always-warm mic pipeline read the input device as busy at idle. The manual shield is proven.
- Voice-driven app switching (Voice Control, "Hey Siri, open X") produces no keyboard or mouse input, so the shield bounces it once while engaged.
- Zero-permission-prompt install is the design (no Accessibility access requested); the clean-account proof is the next scorecard row.
- Windows and Linux: no. macOS 13 or newer only.

## Proven, end-to-end

Every claim above comes from a falsifier that ran on real machines; the rows are in `VERSION.json` and `NOTICE.md` in each release: CDP raise storm bounced then breaker; alternate raise path (AppleScript frontmost) bounced; user-initiated raise passes; dictation shield blocks all programmatic raises; allow token passes for exactly its TTL and bounces after; per-instance discrimination between two Chromes of the same bundle.

## Verify your download

Every release publishes `SHA256SUMS`, `RELEASE.sha256`, `RELEASE.sha256.sig`, and `allowed_signers` on the [Releases](https://github.com/iansteitz1-eng/backstage/releases) page:

```
shasum -a 256 -c SHA256SUMS
ssh-keygen -Y verify -f allowed_signers -I release@voxordo.io -n backstage-app -s RELEASE.sha256.sig < RELEASE.sha256
```

## Updates

Use Watch → Custom → Releases on this repository to be told when a new signed build ships. Email updates arrive with the next release.

## Support

hello@voxordo.ai. Something bounced that should not have, or did not that should? Send `~/Library/Logs/backstage/decisions.jsonl` with a note and it becomes a falsifier in the next build.

## License

Apache-2.0. "Backstage", "voxordo", and "InsyncTech" are trademarks of InsyncTech; see `TRADEMARKS.md`. Backstage is made by InsyncTech, the company behind voxordo.
