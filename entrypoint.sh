#!/bin/sh
# A display, a window onto it, then the server.
#
# The browser runs with a screen rather than headless, because passing an anti
# robot check is something a human does with their eyes and one click. Xvfb gives
# it a screen nobody watches, x11vnc shares that screen, and noVNC turns it into a
# page you can open. Set LBC_VIEWER=off to skip all three.
#
# Starting the browser itself used to be this script's other half. It is Java's
# job now, in browser/Chrome.java, for a reason that has nothing to do with tidying
# up: the same application also ships as a Windows install, where there is no shell
# to run a script at all. One launcher, two platforms, and the container keeps the
# part no desktop needs, which is a screen.
set -e

if [ "${LBC_VIEWER:-on}" != "off" ]; then
    rm -f /tmp/.X99-lock
    Xvfb "$DISPLAY" -screen 0 1440x900x24 -nolisten tcp >/dev/null 2>&1 &
    i=0
    while [ ! -e "/tmp/.X11-unix/X${DISPLAY#:}" ] && [ $i -lt 60 ]; do
        i=$((i + 1))
        sleep 0.25
    done

    # No password means no password: the port is bound to localhost in the compose
    # file for that reason. Whoever opens it can drive a browser holding your
    # session, so set LBC_VNC_PASSWORD before exposing it anywhere else.
    if [ -n "$LBC_VNC_PASSWORD" ]; then
        mkdir -p /tmp/vnc
        x11vnc -storepasswd "$LBC_VNC_PASSWORD" /tmp/vnc/passwd >/dev/null 2>&1
        x11vnc -display "$DISPLAY" -forever -shared -rfbauth /tmp/vnc/passwd \
            -quiet -localhost >/dev/null 2>&1 &
    else
        x11vnc -display "$DISPLAY" -forever -shared -nopw \
            -quiet -localhost >/dev/null 2>&1 &
    fi

    websockify --web=/usr/share/novnc 7900 localhost:5900 >/dev/null 2>&1 &
fi

# The banner, the stale profile lock and the browser are all handled on the other
# side of this line. Docker prints nothing from a detached container, so what the
# application prints at startup lands in "docker compose logs lbc".
exec java $JAVA_OPTS -jar /app/lbc.jar "$@"
