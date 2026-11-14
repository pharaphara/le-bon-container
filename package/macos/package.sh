#!/bin/bash
#
# Build the macOS install: a disk image, and a .app in a zip.
#
# The same idea as the Windows script, and the same three steps, because the
# reasons do not change with the operating system: a Mac already has a screen, a
# browser and someone looking at both, and has no reason to have a Java runtime.
# So the Spring Boot jar is unpacked into plain jars, the four platforms this build
# will never run are dropped out of Playwright's bundle, jlink cuts a runtime to
# the modules the application loads, and jpackage puts the lot in a .app.
#
# What is different is the signing. Apple requires a signature even to run locally
# on Apple silicon, so jpackage signs the app with an ad hoc signature, which is
# enough to run and not enough to pass Gatekeeper on a machine that downloaded it.
# Notarising needs a paid developer account, so the README explains the two
# gestures instead of pretending the warning is not there.
#
#   ./package/macos/package.sh [--build N] [--suffix edge] [--type dmg|portable|both]
#
set -euo pipefail

BUILD=""
SUFFIX=""
TYPE="both"
while [ $# -gt 0 ]; do
    case "$1" in
        --build) BUILD="$2"; shift 2 ;;
        --suffix) SUFFIX="$2"; shift 2 ;;
        --type) TYPE="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

cd "$(dirname "$0")/../.."
NAME="le-bon-container"
VENDOR="pharaphara"
OUT="target/macos"
STAGE="$OUT/stage"
APP="$STAGE/app"
RUNTIME="$STAGE/runtime"

# The modules the application loads, including the ones only reflection asks for.
MODULES="java.base,java.desktop,java.instrument,java.logging,java.management,\
java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.security.jgss,\
java.sql,java.transaction.xa,java.xml,jdk.crypto.ec,jdk.crypto.cryptoki,\
jdk.unsupported,jdk.zipfs,jdk.management"

# Apple silicon and Intel take different halves of the bundle, and neither takes
# the other's.
case "$(uname -m)" in
    arm64) ARCH="arm64"; KEEP="driver/mac-arm64"; DROP="driver/mac/* driver/linux/* driver/linux-arm64/* driver/win32_x64/*" ;;
    *)     ARCH="x64";   KEEP="driver/mac";       DROP="driver/mac-arm64/* driver/linux/* driver/linux-arm64/* driver/win32_x64/*" ;;
esac

JAR=$(ls target/lbc-*.jar 2>/dev/null | grep -v '\.original$' | head -1 || true)
[ -n "$JAR" ] || { echo "no jar in target. Run: mvn -B -DskipTests package" >&2; exit 1; }
VERSION=$(basename "$JAR" | sed -n 's/^lbc-\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
[ -n "$VERSION" ] || VERSION="0.0.1"
# A build number so a later build outranks the one before it, the same reason it
# exists on Windows: an installer that calls itself what is already installed.
[ -z "$BUILD" ] || VERSION=$(echo "$VERSION" | sed "s/\.[0-9]*$/.$BUILD/")
LABEL="${SUFFIX:-$VERSION}"

echo "jar       $JAR"
echo "version   $VERSION"
echo "arch      $ARCH, keeping $KEEP"

rm -rf "$OUT"
mkdir -p "$APP"

# ---------------------------------------------------------------- extract
java -Djarmode=tools -jar "$JAR" extract --destination "$APP"
mv "$APP"/lbc-*.jar "$APP/lbc.jar"

# ---------------------------------------------------------------- prune
BUNDLE=$(ls "$APP"/lib/driver-bundle-*.jar | head -1)
BEFORE=$(( $(stat -f%z "$BUNDLE" 2>/dev/null || stat -c%s "$BUNDLE") / 1048576 ))
zip -q -d "$BUNDLE" $DROP
AFTER=$(( $(stat -f%z "$BUNDLE" 2>/dev/null || stat -c%s "$BUNDLE") / 1048576 ))
echo "driver    $BEFORE MB -> $AFTER MB, $KEEP only"

# ---------------------------------------------------------------- jlink
jlink --add-modules "$MODULES" --output "$RUNTIME" \
    --strip-debug --no-man-pages --no-header-files --compress=zip-6
echo "runtime   $(du -sm "$RUNTIME" | cut -f1) MB"

# ---------------------------------------------------------------- icon
# Built here rather than committed: macOS carries the two tools that make one,
# and a binary nobody can read in a review is a binary worth not having.
ICON=""
if command -v iconutil >/dev/null 2>&1 && [ -f assets/brand/avatar.png ]; then
    SET="$STAGE/lbc.iconset"
    mkdir -p "$SET"
    for s in 16 32 128 256 512; do
        sips -z $s $s assets/brand/avatar.png --out "$SET/icon_${s}x${s}.png" >/dev/null
        sips -z $((s * 2)) $((s * 2)) assets/brand/avatar.png \
            --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$SET" -o "$STAGE/lbc.icns"
    ICON="$STAGE/lbc.icns"
fi

# ---------------------------------------------------------------- jpackage
common=(
    --name "$NAME"
    --app-version "$VERSION"
    --vendor "$VENDOR"
    --description "Browse leboncoin.fr with an AI, through a real browser, over MCP"
    --copyright "pharaphara, MIT"
    --input "$APP"
    --main-jar lbc.jar
    --runtime-image "$RUNTIME"
    --mac-package-identifier io.github.pharaphara.lbc
    # 70 percent of the machine, like the container, and a server that answers this
    # machine only. The tools drive a browser holding a signed in session, so there
    # is nothing here anyone else on the network should reach.
    --java-options "-XX:MaxRAMPercentage=70"
    --java-options "-Dserver.address=127.0.0.1"
)
[ -z "$ICON" ] || common+=(--icon "$ICON")

if [ "$TYPE" != "dmg" ]; then
    jpackage --type app-image "${common[@]}" --dest "$OUT/image"
    # ditto rather than zip: it keeps the bundle's symlinks and its signature.
    ditto -c -k --keepParent "$OUT/image/$NAME.app" "$OUT/$NAME-$LABEL-macos-$ARCH.zip"
    echo "portable  $OUT/$NAME-$LABEL-macos-$ARCH.zip"
fi

if [ "$TYPE" != "portable" ]; then
    jpackage --type dmg "${common[@]}" --dest "$OUT"
    mv "$OUT"/*.dmg "$OUT/$NAME-$LABEL-macos-$ARCH.dmg"
    echo "dmg       $OUT/$NAME-$LABEL-macos-$ARCH.dmg"
fi

rm -rf "$STAGE" "$OUT/image"
ls -lh "$OUT" | awk 'NR>1 {printf "%-52s %6s\n", $9, $5}'
