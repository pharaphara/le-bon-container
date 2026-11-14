#!/bin/bash
#
# Run the image, ask the browser what it looks like, and look at the viewer.
#
# The third of three: package/windows/smoke.ps1 and package/macos/smoke.sh do this
# for the two installers. The container was the one that had only ever been built,
# never started, which left the part it does that no desktop does entirely
# unchecked: a display nobody watches, a window onto it over a web page, and a
# profile on a volume that has to survive the container being recreated.
#
# It never asks leboncoin.fr anything: a runner is a data centre address, exactly
# the kind this project tells you not to read the site from.
#
#   ./package/container/smoke.sh [image tag]
#
set -uo pipefail

IMAGE="${1:-lbc:smoke}"
NAME="lbc-smoke"
WORK="${LBC_SMOKE_DIR:-$PWD/smoke}"
PROFILE="$WORK/profile"
FAILURES=0

say() { echo "  $1"; }
fail() { echo "  FAIL $1"; FAILURES=$((FAILURES + 1)); }

rm -rf "$WORK"
mkdir -p "$PROFILE" "$WORK/data" "$WORK/screens"
# The image runs as uid 1000 and these are bind mounts, so they have to be
# writable by it rather than by whoever is running this.
chmod 777 "$PROFILE" "$WORK/data"

cleanup() { docker rm -f "$NAME" > /dev/null 2>&1 || true; }
trap cleanup EXIT

say "image     $IMAGE"
docker rm -f "$NAME" > /dev/null 2>&1 || true
docker run -d --name "$NAME" --shm-size=1gb \
    -p 127.0.0.1:8788:8788 -p 127.0.0.1:7900:7900 \
    -v "$PROFILE:/profile" -v "$WORK/data:/data" \
    "$IMAGE" > /dev/null || { fail "the container would not start"; exit 1; }

UP=0
for i in $(seq 1 90); do
    sleep 1
    if curl -s -o /dev/null --max-time 2 "http://127.0.0.1:8788/mcp" \
        -X POST -H 'Content-Type: application/json' -d '{}' 2>/dev/null; then
        UP=1
        break
    fi
done
[ "$UP" -eq 1 ] && say "answering on 8788 after about $i s" || fail "nothing on 8788 after 90 s"

# ----------------------------------------------------------------- mcp
H="Content-Type: application/json"
A="Accept: application/json, text/event-stream"
curl -s -D "$WORK/h.txt" -H "$H" -H "$A" -X POST http://127.0.0.1:8788/mcp \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}' \
    > /dev/null
SID=$(grep -i "mcp-session-id" "$WORK/h.txt" | tr -d '\r' | awk '{print $2}')
if [ -z "$SID" ]; then
    fail "no session id in the initialize response"
else
    curl -s -H "$H" -H "$A" -H "Mcp-Session-Id: $SID" -X POST http://127.0.0.1:8788/mcp \
        -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null
    curl -s --max-time 180 -H "$H" -H "$A" -H "Mcp-Session-Id: $SID" \
        -X POST http://127.0.0.1:8788/mcp \
        -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"status","arguments":{"browser":true}}}' \
        > "$WORK/status.txt"
    grep -q "webdriver false" "$WORK/status.txt" \
        && say "the browser says webdriver false" \
        || fail "the browser did not say webdriver false: $(head -c 300 "$WORK/status.txt")"
    grep -q "localhost:7900" "$WORK/status.txt" \
        && say "it points a human at the viewer, not at a window on a desktop" \
        || fail "the viewer url is missing from status"
fi

# ----------------------------------------------------------------- the viewer
CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7900/vnc.html)
[ "$CODE" = "200" ] && say "the viewer page answers $CODE" || fail "the viewer page answered $CODE"

# A picture of it, because the readme asks someone to open this page and a
# sentence describing a screen is never as good as the screen.
if command -v npx > /dev/null 2>&1; then
    npx -y playwright@1.49.1 screenshot --wait-for-timeout=6000 \
        --viewport-size=1280,860 \
        "http://127.0.0.1:7900/vnc_lite.html?autoconnect=1&resize=scale&reconnect=1" \
        "$WORK/screens/container-viewer.png" > /dev/null 2>&1 \
        && say "viewer screenshot at $WORK/screens/container-viewer.png" \
        || say "no screenshot: playwright would not run here"
fi

docker logs "$NAME" > "$WORK/container.log" 2>&1
grep -q "le bon container" "$WORK/container.log" \
    && say "the banner is in the logs, where a detached container leaves it" \
    || fail "no banner in the container logs"

# ----------------------------------------------------------------- stopping
docker stop -t 30 "$NAME" > /dev/null
CODE=$(docker inspect -f '{{.State.ExitCode}}' "$NAME")
# 143 is a java that handled the term signal and left: the shutdown hooks ran.
case "$CODE" in
    0 | 143) say "stopped cleanly, exit $CODE" ;;
    *) fail "stopped with exit $CODE" ;;
esac

PREFS="$PROFILE/Default/Preferences"
if [ -f "$PREFS" ]; then
    EXIT_TYPE=$(grep -o '"exit_type":"[^"]*"' "$PREFS" | head -1 | cut -d'"' -f4)
    [ "$EXIT_TYPE" = "Crashed" ] \
        && fail "the profile is marked Crashed, so the next start offers to restore" \
        || say "profile closed as '${EXIT_TYPE:-unset}'"
else
    fail "nothing was written to the profile volume"
fi
[ -s "$WORK/data" ] || true

echo
if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES failed"
    exit 1
fi
echo "all good on $(docker version -f '{{.Server.Version}}' 2>/dev/null || echo docker)"
