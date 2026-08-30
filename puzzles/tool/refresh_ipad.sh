#!/bin/sh
# Reinstall Actufree on a connected iPad.
#
# A free Apple account signs apps with a provisioning profile that lasts seven
# days, after which the app stops launching. Rebuilding and reinstalling gives
# it another seven. Installing over the top keeps the app's data, so saved
# games and best scores survive the refresh.
#
# Usage: tool/refresh_ipad.sh [udid]
set -e

UDID="${1:-00008101-00111DAE1450801E}"
APP_DIR="$(cd "$(dirname "$0")/../app" && pwd)"
APP="$APP_DIR/build/ios/iphoneos/Runner.app"

cd "$APP_DIR"

echo "Building..."
flutter build ios --release

echo "Installing to $UDID..."
# Flutter's own install step fails where Apple's tool succeeds, so use devicectl.
xcrun devicectl device install app --device "$UDID" "$APP"

echo "Done. If it refuses to launch, trust the developer profile again:"
echo "  Settings > General > VPN & Device Management"
