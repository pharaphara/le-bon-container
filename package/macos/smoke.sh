#!/bin/bash
#
# Install it, run it, and ask the browser what it looks like.
#
# The counterpart of package/windows/smoke.ps1, and it checks the same things for
# the same reasons: everything else here is tested with no browser and no network,
# against frozen samples, which says nothing about a real app bundle on a machine
# that has a screen, a Chrome and a profile directory of its own.
#
#   http    Start the server, ask it what the browser looks like from inside a
#           page. The answer that matters is webdriver false: a browser somebody
#           started, not one a library did.
#
#   stdio   What a desktop client does. Speak the protocol on standard input,
#           close the stream, and the process must leave on its own, with its
#           browser closed and the profile not marked as crashed.
#
# It never asks leboncoin.fr anything: a runner is a data centre address, exactly
# the kind this project tells you not to read the site from.
#
#   ./package/macos/smoke.sh /Applications/le-bon-container.app/Contents/MacOS/le-bon-container
#
set -uo pipefail

EXE="${1:?usage: smoke.sh <path to the installed binary>}"
WORK="${LBC_SMOKE_DIR:-${TMPDIR:-/tmp}/lbc-smoke}"
PROFILE="$HOME/Library/Application Support/le-bon-container/profile"
FAILURES=0

say() { echo "  $1"; }
fail() { echo "  FAIL $1"; FAILURES=$((FAILURES + 1)); }
browsers() { pgrep -f "remote-debugging-port=" 2>/dev/null | wc -l | tr -d ' '; }

[ -x "$EXE" ] || { echo "not installed: $EXE" >&2; exit 1; }
rm -rf "$WORK"; mkdir -p "$WORK"
say "exe       $EXE"
say "arch      $(uname -m), $(sw_vers -productName) $(sw_vers -productVersion)"

# ----------------------------------------------------------------- http
echo
echo "http"
"$EXE" > "$WORK/http.out" 2> "$WORK/http.err" &
APP=$!
UP=0
for i in $(seq 1 60); do
    sleep 1
    if nc -z 127.0.0.1 8788 2>/dev/null; then UP=1; break; fi
done
if [ "$UP" -eq 0 ]; then
    fail "nothing listening on 8788 after 60 s"
else
    say "listening on 8788 after about $i s"
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
        # The one question worth asking a real browser.
        curl -s --max-time 180 -H "$H" -H "$A" -H "Mcp-Session-Id: $SID" \
            -X POST http://127.0.0.1:8788/mcp \
            -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"status","arguments":{"browser":true}}}' \
            > "$WORK/status.txt"
        if grep -q "webdriver false" "$WORK/status.txt"; then
            say "the browser says webdriver false"
        else
            fail "the browser did not say webdriver false: $(head -c 400 "$WORK/status.txt")"
        fi
        if grep -q "talking to it over its debugging port" "$WORK/status.txt"; then
            say "attached to a browser it started, rather than one the library launched"
        else
            fail "not attached over a debugging port"
        fi
    fi
    [ -d "$PROFILE" ] && say "profile at $PROFILE" || fail "no profile directory at $PROFILE"
fi
# A term signal here does run the shutdown hooks, but leaving cleanly is checked
# on the stdio side, where a client closing its end is the real case.
kill -TERM "$APP" 2>/dev/null
sleep 6
pkill -f "remote-debugging-port=" 2>/dev/null
sleep 2

# ----------------------------------------------------------------- stdio
echo
echo "stdio"
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}'
READY='{"jsonrpc":"2.0","method":"notifications/initialized"}'
LIST='{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
(
    printf '%s\n' "$INIT"
    sleep 25
    printf '%s\n' "$READY"
    printf '%s\n' "$LIST"
    sleep 10
) | "$EXE" --stdio > "$WORK/stdio.out" 2> "$WORK/stdio.err" &
APP=$!
# Disowned, so killing it later does not print a job control notice into the
# middle of the results.
{ sleep 120; kill -9 "$APP" 2>/dev/null; } & WATCHDOG=$!
disown "$WATCHDOG" 2>/dev/null
wait "$APP"; RC=$?
kill "$WATCHDOG" 2>/dev/null
if [ "$RC" -eq 0 ]; then
    say "left on its own when the stream closed, exit $RC"
else
    fail "did not leave cleanly when the stream closed, exit $RC"
fi

LINES=$(grep -c . "$WORK/stdio.out" || true)
NOT_JSON=$(grep -c -v '^{' <(grep . "$WORK/stdio.out") || true)
if [ "${NOT_JSON:-0}" -eq 0 ]; then
    say "$LINES lines on standard output, every one of them protocol"
else
    fail "standard output carries $NOT_JSON lines that are not protocol"
fi
grep -q '"id":1' "$WORK/stdio.out" && grep -q '"tools"' "$WORK/stdio.out" \
    && say "initialize and tools/list answered" \
    || fail "initialize or tools/list went unanswered"
grep -q "le bon container" "$WORK/stdio.err" \
    && say "banner on standard error, where it belongs" \
    || fail "no banner on standard error"

LEFT=$(browsers)
if [ "$LEFT" -eq 0 ]; then
    say "no browser left behind"
else
    fail "$LEFT browser processes outlived the server"
    pkill -f "remote-debugging-port=" 2>/dev/null
fi

PREFS="$PROFILE/Default/Preferences"
if [ -f "$PREFS" ]; then
    EXIT_TYPE=$(grep -o '"exit_type":"[^"]*"' "$PREFS" | head -1 | cut -d'"' -f4)
    if [ "$EXIT_TYPE" = "Crashed" ]; then
        fail "the profile is marked Crashed, so the next window offers to restore"
    else
        say "profile closed as '${EXIT_TYPE:-unset}'"
    fi
fi

# ----------------------------------------------------------------- verdict
echo
if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES failed"
    exit 1
fi
echo "all good on $(sw_vers -productName) $(sw_vers -productVersion) $(uname -m)"
