#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="build/device/Build/Products/Release-iphoneos/Tornadobreak.app"
test -d "$app"
mkdir -p build/package/Payload dist
cp -R "$app" build/package/Payload/
# No provisioning profile or restricted entitlements: SideStore supplies the user's signature.
rm -rf build/package/Payload/Tornadobreak.app/_CodeSignature
rm -f build/package/Payload/Tornadobreak.app/embedded.mobileprovision
(cd build/package && zip -qry ../../dist/Tornadobreak.ipa Payload)
cat > dist/SIDELOAD.txt <<'NOTES'
Tornadobreak 1.0 — iPhone, iOS 16 or later

This IPA is unsigned. It cannot be installed by tapping it in Files.
Extract this ZIP, then import Tornadobreak.ipa in an already configured SideStore.
SideStore re-signs the app with your Apple ID. A free personal account can work;
Apple's device/app limits and periodic signing refresh still apply.
SideStore setup and a compatible pairing file are prerequisites; initial setup
may require a computer. This build does not require a paid developer membership.

No accounts, in-app purchases, tracking, or location permission in the game.
Internet access is used only for Apple Maps. If a map is unavailable, the game
shows a labeled reference grid and remains playable.

Progress is on-device. Removing the app can remove progress.
NOTES
(cd dist && zip -q Tornadobreak-iPhone.zip Tornadobreak.ipa SIDELOAD.txt)
unzip -tq dist/Tornadobreak.ipa
unzip -tq dist/Tornadobreak-iPhone.zip
python3 scripts/verify_archives.py dist/Tornadobreak.ipa dist/Tornadobreak-iPhone.zip
