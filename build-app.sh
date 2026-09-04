#!/bin/bash
# build-app.sh — build Backstage.app + release zip with the RecoveryOne signing pattern:
# reproducible-ish release build → .app bundle → codesign (Developer ID if present, ad-hoc
# otherwise) → Backstage-v<V>.zip + SHA256SUMS + RELEASE.sha256 signed with the voxordo
# ed25519 release key (namespace backstage-app) + release.json manifest.
# Usage: ./build-app.sh [--install]   (--install also copies to ~/Applications and opens it)
set -euo pipefail
cd "$(dirname "$0")"

V=$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)
APP="Backstage.app"
OUT="dist"
KEY="$HOME/.ssh/vox_recovery_release_ed25519"   # the M4 release key (same key as RecoveryOne)

echo "▸ swift build -c release (v$V)"
swift build -c release
BIN=".build/release/Backstage"
CLI=".build/release/backstage-allow"
[ -x "$BIN" ] && [ -x "$CLI" ] || { echo "build missing binaries"; exit 1; }

echo "▸ assembling $APP"
rm -rf "$OUT"; mkdir -p "$OUT"
BUNDLE="$OUT/$APP"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/Backstage"
cp "$CLI" "$OUT/backstage-allow"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

# Developer ID if the keychain has one; ad-hoc otherwise (RecoveryOne parity: trust rides
# the ed25519 manifest; Gatekeeper-clean distribution = Developer ID + notarization, flagged).
DEVID=$( (security find-identity -v -p codesigning 2>/dev/null | grep -o '"Developer ID Application[^"]*"' | head -1 | tr -d '"') || true)
if [ -n "$DEVID" ]; then
  echo "▸ codesign: $DEVID"
  codesign --force --options runtime --sign "$DEVID" "$OUT/backstage-allow" "$BUNDLE"
else
  echo "▸ codesign: ad-hoc (no Developer ID identity in keychain)"
  codesign --force --sign - "$OUT/backstage-allow" "$BUNDLE"
fi

echo "▸ packaging"
ZIP="Backstage-v$V.zip"
for doc in NOTICE.md VERSION.json README.md; do [ -f "$doc" ] && cp "$doc" "$OUT/"; done
(cd "$OUT" && zip -qry "$ZIP" "$APP" backstage-allow $(for d in NOTICE.md VERSION.json README.md; do [ -f "$d" ] && echo "$d"; done))
(cd "$OUT" && shasum -a 256 "$ZIP" > SHA256SUMS)
(cd "$OUT" && cp SHA256SUMS RELEASE.sha256)
if [ -f "$KEY" ]; then
  echo "release@voxordo.io $(cut -d' ' -f1-2 "$KEY.pub")" > "$OUT/allowed_signers"
  (cd "$OUT" && ssh-keygen -Y sign -f "$KEY" -n backstage-app RELEASE.sha256)
  echo "▸ signed RELEASE.sha256 (namespace backstage-app)"
  (cd "$OUT" && ssh-keygen -Y verify -f allowed_signers -I release@voxordo.io -n backstage-app \
    -s RELEASE.sha256.sig < RELEASE.sha256) && echo "▸ signature VERIFIES against shipped allowed_signers" \
    || { echo "▸ FAIL: signature does not verify"; exit 1; }
else
  echo "▸ WARNING: release key absent — zip is unsigned"
fi

SHA=$(cut -d' ' -f1 "$OUT/SHA256SUMS")
cat > "$OUT/release.json" <<EOF
{
  "product": "backstage",
  "version": "$V",
  "artifact": "$ZIP",
  "sha256": "$SHA",
  "min_macos": "13.0",
  "codesign": "$([ -n "$DEVID" ] && echo developer-id || echo ad-hoc)",
  "manifest_sig": "RELEASE.sha256.sig (ssh-ed25519, namespace backstage-app, signer release@voxordo.io)",
  "built": "$(date -u +%FT%TZ)"
}
EOF
echo "▸ dist/: $ZIP  sha256=$SHA"

if [ "${1:-}" = "--install" ]; then
  rm -rf "$HOME/Applications/$APP"
  cp -R "$BUNDLE" "$HOME/Applications/$APP"
  open "$HOME/Applications/$APP"
  echo "▸ installed + launched: ~/Applications/$APP"
fi
