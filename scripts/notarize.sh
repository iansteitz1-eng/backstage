#!/bin/bash
# notarize.sh — Developer ID + notarization finishing pass (runs once credentials exist).
# ONE-TIME SETUP (after Ian reads the Issuer ID off appstoreconnect.apple.com/access/integrations/api):
#   xcrun notarytool store-credentials voxordo-notary \
#     --key ~/Downloads/AuthKey_7X2B8VCUH7.p8 --key-id 7X2B8VCUH7 --issuer <ISSUER-UUID>
# and a "Developer ID Application" identity in the keychain (Xcode → Settings → Accounts →
# Manage Certificates → + → Developer ID Application; Account Holder role required).
# Then: ./scripts/notarize.sh   → re-signs with Developer ID, notarizes, staples, re-zips.
set -euo pipefail
cd "$(dirname "$0")/.."

DEVID=$( (security find-identity -v -p codesigning | grep -o '"Developer ID Application[^"]*"' | head -1 | tr -d '"') || true)
[ -n "$DEVID" ] || { echo "no Developer ID Application identity in keychain — see header"; exit 1; }
xcrun notarytool history --keychain-profile voxordo-notary >/dev/null 2>&1 || { echo "no voxordo-notary keychain profile — see header"; exit 1; }

V=$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)
[ -d dist/Backstage.app ] || { echo "run ./build-app.sh first"; exit 1; }

echo "▸ re-sign with $DEVID (hardened runtime)"
codesign --force --options runtime --timestamp --sign "$DEVID" dist/backstage-allow dist/Backstage.app

echo "▸ notarize"
ZIP="Backstage-v$V.zip"
(cd dist && rm -f "$ZIP" && zip -qry "$ZIP" Backstage.app backstage-allow NOTICE.md VERSION.json README.md 2>/dev/null || true)
xcrun notarytool submit "dist/$ZIP" --keychain-profile voxordo-notary --wait

echo "▸ staple + final zip"
xcrun stapler staple dist/Backstage.app
(cd dist && rm -f "$ZIP" && zip -qry "$ZIP" Backstage.app backstage-allow NOTICE.md VERSION.json README.md 2>/dev/null || true)
(cd dist && shasum -a 256 "$ZIP" > SHA256SUMS && cp SHA256SUMS RELEASE.sha256)
(cd dist && rm -f RELEASE.sha256.sig && ssh-keygen -Y sign -f "$HOME/.ssh/vox_recovery_release_ed25519" -n backstage-app RELEASE.sha256)
(cd dist && ssh-keygen -Y verify -f allowed_signers -I release@voxordo.io -n backstage-app -s RELEASE.sha256.sig < RELEASE.sha256)
python3 - <<'EOF'
import json
r = json.load(open('dist/release.json')); import hashlib
r['sha256'] = open('dist/SHA256SUMS').read().split()[0]
r['codesign'] = 'developer-id+notarized+stapled'
json.dump(r, open('dist/release.json','w'), indent=2)
EOF
echo "▸ DONE — notarized release in dist/; update the hosted bundle + release.json"
