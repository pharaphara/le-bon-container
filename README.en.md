<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/brand/banner-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/brand/banner-light.png">
  <img alt="le bon container. A browser with a head. A container with a purpose. MCP server, headed Chromium, Docker." src="assets/brand/banner-light.png" width="100%">
</picture>

[Français](README.md) · **English**

# le bon container

**A browser with a head. A container with a purpose.**

Browse [leboncoin.fr](https://www.leboncoin.fr) with an AI, through a real
browser, over [MCP](https://modelcontextprotocol.io).

![build](https://github.com/pharaphara/le-bon-container/actions/workflows/build.yml/badge.svg)

One container, nine tools, and results an assistant can actually work with: market
markers first, a compact table next, the full detail on disk, and ad numbers that
never move.

```
search "vtt electrique", place 12, price max 1500

search "vtt-electrique-8778" | 47 announced | 46 collected | 1 calls
prices: median 915 EUR, middle half 500 EUR to 1 250 EUR, range 30 EUR to 1 500 EUR
market: 45 private, 1 pro, median age 118 d, 6 bumped since first posted
---
  n      price  place              age   by   title
  1    1 050 €  Auriac-Lagast (1…  14 j  P    VTT electrique
  2      800 €  Rodez (12)         50 j  P    Vtt electrique giant
  3    1 400 €  Nauviale (12)      30 j  P    Vtt electrique
  …
!! condition the site applied: global_BDC
- more: results(offset=25) for the remaining 21
```

## Quick start

```bash
docker compose up -d
```

Then point your client at it: see [connecting a
client](#connecting-a-client) just below, for Claude Code, Claude, ChatGPT and
Codex.

Nothing to compile and no JDK to install: the image is built and published by CI.

**On Windows, Docker is not needed.** There is an installer, and a folder you can
just unzip: see [on Windows, without Docker](#on-windows-without-docker).

The first time, run `docker compose up` without `-d`: the container prints a
short banner with both addresses and the state of the profile. Afterwards
`docker compose logs lbc` shows it again at any time. Docker prints nothing from
inside a detached container, which is a Docker limit rather than an oversight.

**Once, at the beginning**, open <http://localhost:7900>. You are looking at the
container's own browser, and this is where a human does the one thing no tool
should: pass the anti robot check, and sign in if you want to.

This is not optional, and it is worth knowing why. Measured on a brand new
container: the site renders its pages happily, but refuses the data calls with a
403 carrying an anti robot marker, and after a few requests it challenges the page
itself. A fresh profile simply has no clearance yet. Pass the check by hand once,
and the profile remembers it. Whether an account adds anything on top has not been
measured, so this readme does not claim it does.

## On Windows, without Docker

Two files on the [releases
page](https://github.com/pharaphara/le-bon-container/releases):

- **`le-bon-container-x.y.z-windows-x64.msi`** — installs, adds a Start menu
  entry, uninstalls like anything else. No administrator needed: it installs for
  your account.
- **`le-bon-container-x.y.z-windows-x64-portable.zip`** — unzip it anywhere, run
  `le-bon-container.exe`. Nothing is installed.

**No Java to install**: both carry a runtime cut to the modules this application
loads. Measured at build time: 100 MB for the msi, 99 MB for the zip, of which
50 MB is the Java runtime and 33 MB the Node runtime Playwright carries. Around
120 MB on disk once installed, against 2.2 GB for the Docker image, because the
browser and the screen are already there.

**Updates follow the same rhythm as the image.** Two channels, both built and
published by CI:

| | Docker image | Windows |
|---|---|---|
| On every change to `main` | `ghcr.io/pharaphara/lbc:latest` | the [`edge`](https://github.com/pharaphara/le-bon-container/releases/tag/edge) prerelease |
| On every published version | `ghcr.io/pharaphara/lbc:0.1.0` | the numbered release |

The two `edge` addresses never change, and always serve the newest build:

```
…/releases/download/edge/le-bon-container-edge-windows-x64.msi
…/releases/download/edge/le-bon-container-edge-windows-x64-portable.zip
```

Every `edge` build carries a higher version than the one before, on purpose:
Windows decides between installing and doing nothing by comparing versions, so two
installers that both call themselves `0.1.0` are one product it already has. With
a number that climbs, the msi installs over the previous one and nothing has to be
uninstalled.

**Nothing updates itself on your machine**, though: it is an msi to run again, or a
folder to replace. The profile and the searches live elsewhere, under
`%LOCALAPPDATA%`, so reinstalling touches neither your session nor your data.

**Windows will say "unknown publisher"** the first time, because the executable is
not signed: More info, then Run anyway. A code signing certificate costs a few
hundred a year, this project has none, and saying so is more honest than
pretending the warning is not there.

What changes against the container, mostly in the desktop's favour:

| | Container | Windows install |
|---|---|---|
| Browser | a downloaded Chromium, brand new profile | your own Chrome or Edge |
| Seeing the page | <http://localhost:7900>, a viewer | the window is on your desktop |
| Profile and data | Docker volumes | `%LOCALAPPDATA%\le-bon-container\` |
| MCP address | `http://localhost:8788/mcp` | the same, bound to `127.0.0.1` only |
| To install first | Docker | nothing |

The browser opens by itself at startup, on a **profile of its own**, not the one
you browse with: Chrome refuses to open a debugging port on a profile that is
already open, and mixing the two would be unpleasant anyway. The first time, go to
the site in that window, pass the anti robot check, and sign in if you want to. The
profile remembers it.

To stop it: close the console window. The browser closes with it, and cleanly, so
there is no "restore session" bar on the next start.

To build it yourself, on a Windows machine with a JDK 21:

```powershell
mvn -B -DskipTests package
pwsh package/windows/package.ps1          # -Type msi or -Type portable
```

The msi needs [WiX 3](https://github.com/wixtoolset/wix3/releases); without it the
script says so and still produces the zip.

## Connecting a client

The server speaks MCP over HTTP at `http://localhost:8788/mcp`. Here are the four
common cases.

**Claude Code**

```bash
claude mcp add --transport http lbc http://localhost:8788/mcp
```

**Claude desktop app**

In the MCP servers configuration file:

```json
{ "mcpServers": { "lbc": { "type": "http", "url": "http://localhost:8788/mcp" } } }
```

Recent versions also let you add a custom connector from the settings, with the
same address.

**ChatGPT**

This one needs a **public HTTPS address**: ChatGPT will never reach your
`localhost`. Put a reverse proxy with TLS in front of port 8788, say
`lbc.example.org`, then add it as a custom connector in your account settings.
Whether that feature is available depends on your plan and settings, which this
document cannot know for you. And do not expose it without authentication in
front: these tools drive a browser carrying your session.

**Codex**

In `~/.codex/config.toml`:

```toml
[mcp_servers.lbc]
command = "npx"
args = ["-y", "mcp-remote", "http://localhost:8788/mcp"]
```

That form goes through a bridge, so it works whatever the version. If yours takes
an http address directly, declaring it that way skips the bridge.

**Any other client that only speaks stdio** connects the same way, through a
bridge such as `mcp-remote` pointed at the same address.

## The tools

| Tool | What it does |
|---|---|
| `search` | Collect a search. One page render, then paging by data calls. Returns markers, then a table. |
| `results` | Re-read what was collected: filter and sort, offline, as often as you like. |
| `ad` | Everything about one ad, with no network. `refresh=true` checks the site again. |
| `stats` | The market in numbers, optionally grouped by brand, year, city or seller. |
| `filters` | What the site kept of a search url, and what it quietly threw away. |
| `categories` | List the 45 measured categories, or probe any id on the spot. |
| `searches` | What is on disk, and which search the other tools default to. |
| `forget` | Delete a search and its ads. |
| `status` | How the container is wired, and where to click if a wall appears. |

## How it works

Four things were measured rather than assumed, and they are the whole design.

**The page hands over its own search payload.** A results page embeds the exact
query the site derived from the URL. So LBC never invents a filter name: it builds
a URL out of parameters that were each measured against the total the site
announces, renders it once, then replays the site's own payload to page through the
rest. Rendering is the expensive part, and it happens once.

**Paging is on `offset` alone.** The `pivot` the site returns looks like a cursor
but is a list of ids already shown, and replaying it from offset zero hands back
the same ads. `max_pages` comes out at 2 for 122 ads, so it is reported and never
trusted.

**The list already carries everything.** Measured on one ad: 6588 characters of
description in the search results, exactly as many as on the ad's own page, plus
every attribute and every photo. So `ad` costs nothing and touches no network.
Visiting an ad only tells you one thing the list cannot: whether the price moved
or it has been sold since.

**The api repeats itself.** Three responses totalling 224 lines once carried only
120 distinct ids. Deduplication is a requirement here, not a precaution, and the
count you read is always the count of unique ads.

**And when the data calls are refused, the rendered pages still work.** Until a
profile has clearance, LBC reads what the page itself renders, about thirty five
ads at a time, and pages by url instead. It is slower, one render per page, and the
answer says so in as many words rather than pretending otherwise. Pass the check
once and the fast path opens by itself.

And one thing that is not about the site at all: **numbers never move.** An ad
keeps the number it was given the first time it was seen. `ad(number=7)` means the
same ad ten messages later, after two more pages and a sort by price. That single
property is what makes a long conversation with a marketplace bearable.

## Categories are measured, not copied

Forty five of them, and every id came from the site's own data rather than from
somebody's notes. Each ad carries both its `category_id` and its `category_name`,
so browsing the whole site sorted by date hands back canonical pairs by the dozen:
210 ads over six pages gave 44 of them in one sitting.

That method immediately corrected two ids that looked right and were not. Toys is
41, while 40 is Collection. Garden is 52, and 32 is industrial equipment. Either
one would have returned an empty market with no error at all, which is the failure
that matters here: a wrong id does not fail, it just quietly finds nothing.

So a name that was never measured is refused rather than used. Any numeric id works
directly, and `categories(verify=["70"])` probes one on the spot and tells you what
the site calls it.

## No disguise, ever

The wall on this kind of site is a JavaScript challenge, not a fingerprint. Six
sessions across four spoofed fingerprints were all refused, while one real browser
with a real session walked straight through. A better disguise is the wrong
dimension.

So LBC drives a real browser with your own session. It does not patch `navigator`,
it does not forge a user agent, it does not even pass the flag that hides
automation, and it never calls a captcha solving service. Faced with a check it
waits, because a real browser usually clears one on its own, then ticks at most one
checkbox. A puzzle is where it stops and tells you to look at
<http://localhost:7900>. A test enforces all of this: fifteen patterns are banned
from the source tree, and the scanner is itself tested against a known disguise.

## How the browser is started, and why that matters more than anything

This is the most useful thing this project learned, and it was measured by
comparing this container against a browser that has been reading this kind of site
daily for months without ever being restricted.

| Seen from inside a page | Browser started by the library | Browser started normally |
|---|---|---|
| `navigator.webdriver` | `true` | `false` |
| `navigator.plugins` | 0 | 5 |

Letting Playwright launch the browser adds the automation flag, and the page can
see it. Starting an ordinary desktop browser with a debugging port open, then
merely attaching to it, does not. That was the only structural difference between
the two setups.

So the application starts an ordinary browser itself, with a debugging port open,
and attaches to it. That is what `LBC_BROWSER: attach` does. Nothing is forged and
nothing is hidden: a flag is simply not added. No `navigator` is patched, the well
known flag that hides automation is still not passed, and the whole difference
comes down to how the program is started.

Which browser it starts depends on the machine, and the order is not innocent:
your Chrome, Edge or Chromium first, Playwright's Chromium last. A browser somebody
installed and reads the web with carries a profile, a history and a reputation; the
copy a test library downloaded carries none of that, and the sites that hand out
walls can tell. In the container that copy is the only one there is, which is one
more reason to prefer the Windows install when you have the choice.

If a browser is already listening on port 9222, that one is used and nothing is
started: yours, with your session, still beats ours.

`LBC_BROWSER: launch` gives the old behaviour back, where the library launches the
browser itself: simpler, and louder. `LBC_BROWSER: off` starts nothing at all.

## Nothing silent

Every reduction is counted and shown, on a line starting with `!!`. A criterion the
site ignored, an ad set aside because it came from another section, a duplicate, a
collection that stopped early, a search served from disk: each one produces a
number in the output.

This is the failure the project is built against. A table that dropped a third of
its rows without saying so reads exactly like a thin market, and an assistant has
no way to tell the difference.

## What it takes to run

Measured, not estimated, on a six core machine.

| | Measured |
|---|---|
| Image | 2.2 GB |
| RAM at rest | 467 MiB, browser running included |
| RAM during a search | 960 MiB at peak |
| CPU at rest | 0.5% |
| Data | about 8 kB per ad, so 8 MB per thousand |

The Windows install needs far less disk, because everything it does not carry is
already on the machine: the browser, and a screen.

| | Measured |
|---|---|
| msi installer | 100 MB |
| Portable zip | 99 MB |
| Of which the Java runtime | 50 MB, cut to the modules loaded, against 286 MB for a whole JDK |
| On disk | around 120 MB |

Memory was not measured on Windows, and this document will not invent it: it is
the same browser and the same Java runtime, without the display server and the
viewer.

In practice: **1.5 GB of RAM for the container, 3 GB of disk, two cores**, and no
graphics card. On a machine that is already busy, `LBC_BROWSER: launch` keeps no
browser running between calls, at the cost of a startup per session and a browser
that announces being driven.

A container carrying a real browser cannot be small, and here is where the 2.2 GB
go: 780 MB for Chromium and its libraries, 520 MB for the display server and the
viewer, 250 MB for the Java runtime, the rest for the application. The first lead
for slimming down is a variant without the viewer, for people attaching to their
own browser: that alone removes 520 MB.

## Configuration

Everything has a working default. Set what you need in `compose.yaml` for the
container, or as environment variables for a Windows install.

| Variable | Default | What it is |
|---|---|---|
| `LBC_DATA` | `/data`, else `%LOCALAPPDATA%\le-bon-container\data` | One folder per search. Mount it to keep your searches. |
| `LBC_PROFILE` | `/profile`, else `…\le-bon-container\profile` | The browser profile, so a sign in survives a restart. |
| `LBC_BROWSER` | `attach` | `attach` starts an ordinary browser and talks to it, `launch` lets the library start it, `off` starts nothing. |
| `LBC_HEADLESS` | `false` | A human must be able to see the page to pass a check. |
| `LBC_CDP_URL` | unset | Attach to a browser already running instead of starting one. |
| `LBC_VNC_URL` | the viewer's address in the image, unset elsewhere | Where to send a human when a wall needs a click. Unset, the messages point at the window on the desktop. |
| `LBC_VNC_PASSWORD` | unset | Set this before exposing port 7900 anywhere but localhost. |
| `LBC_VIEWER` | `on` | `off` skips the display and the viewer entirely. Container only. |
| `LBC_PACE_CALL_MIN_MS` | `1500` | Shortest pause between two data calls. |
| `LBC_PACE_CALL_MAX_MS` | `3500` | Longest, picked at random in between. |
| `LBC_PACE_RENDER_MIN_MS` | `6000` | Between two page renders, which cost the site far more. |
| `LBC_PACE_RENDER_MAX_MS` | `10000` | Same, upper bound. |
| `LBC_PACE_CALLS_PER_MINUTE` | `20` | Ceiling, whatever the pauses say. |
| `LBC_PACE_PAGES_MAX` | `20` | Hard stop on pages per collection. |
| `LBC_PACE_RENDERED_PAGES_MAX` | `3` | Pages per call on the slow way in. |
| `LBC_MAX_ADS` | `2000` | Hard stop on ads per search. |
| `SERVER_PORT` | `8788` | Where MCP listens. |

**Bring your own browser.** With `LBC_CDP_URL` pointing at a Chromium that is
already running with remote debugging on, LBC attaches to it and uses its first
context, which is the real profile with the real session. Nothing is launched and
nothing is closed: the browser is yours.

**Behind a reverse proxy.** Port 7900 is a web page, so any reverse proxy can put
it behind a name of your own, for instance `lbc.example.org`. Do set
`LBC_VNC_PASSWORD` first: whoever opens that page drives a browser that carries
your session, which is exactly why the compose file binds both ports to localhost
until you decide otherwise.

**Behind a VPN.** Nothing to build: Docker already does this with
`network_mode: "service:<vpn>"`, moving the published ports onto the VPN
container. Think first though, because it usually backfires here. A commercial VPN
exit is a datacenter address, and address reputation is exactly what anti robot
checks score: the wall will show up more often, not less. The case that does make
sense is the opposite one, a VPN back to your own network, which keeps a
residential address and lets the container run elsewhere while still coming out of
your home.

**Where your data lives.** One folder per search under `/data`:

```
/data/<search>/
  search.json    the url, the payload the site derived, totals, where paging stopped
  ads.jsonl      one line per ad, the site's own object, numbered
  skipped.jsonl  ads set aside, with the reason, so you can check the filter was fair
  seen.tsv       the id to number registry, which is why numbers never move
  ads/<id>.json  what a refresh brought back
```

The raw object is what gets stored, not a compact view. The full description is in
there anyway, and recomputing the view on read avoids stale columns the day the
formula changes.

**The pace is set in the compose file.** These are the numbers that decide whether
the site treats you as a visitor or as a nuisance. The defaults come from a browser
that has been reading this kind of site daily for months: one to three seconds
between calls, six to ten between page renders. Going faster does not collect more,
it collects for less time.

## If access gets temporarily restricted

It happens, and it was measured: a profile with no clearance that keeps pushing
ends up seeing "access temporarily restricted". That is not a check to pass, it is
a pause to take. Clicking will not help, and retrying makes it worse.

The tool recognises it and words it differently from a plain wall: it asks you to
stop rather than to go and click. Two things worth keeping in mind. Your address is
probably shared with your other tools, so leaning on it from this container
degrades what works elsewhere. And the way out is not a workaround: it is a profile
with a real session and a slower pace.

## Development

```bash
mvn verify              # the domain logic: no browser, no network, frozen samples
mvn spring-boot:run     # run it on your machine
docker build -t lbc .   # the image
```

```powershell
pwsh package/windows/package.ps1   # the msi and the zip, on Windows, after mvn package
```

Run by hand, the server picks up the machine's own browser and writes under your
data directory: no container needed for everyday development.

Playwright ships its own Node runtime for five platforms, which is how it
guarantees the version it needs. The image keeps the one it runs and drops the
other four, saving 155 MB; the Windows install does the same sort and goes from
204 MB to 35 MB.

## Roadmap

**Messaging over MCP**, reading and replying, so an assistant can carry a
negotiation on a single item by itself. The line to hold is depth against breadth:
many messages in one thread is a negotiation, many threads with strangers is spam.
So the caps will sit on threads opened per day rather than on replies, autonomy
will be an explicit level rather than a default, everything sent will be logged,
and the rule that an assistant never states a fact that is not true belongs in the
tool description where it will actually be read.

**Slimming the image.** 2.2 GB is what a real browser costs, but some of it
comes back. A variant without the viewer removes 520 MB for anyone attaching to
their own browser. A tailored Java runtime removes another hundred or so. And the
libraries installed alongside Chromium are a superset of what it actually links.
First gain already taken: 942 MB, by reordering two Dockerfile instructions so the
browser is not stored twice.

**Signing in** without touching the viewer, for people who would rather put
credentials in the compose file. It will stay an option and not the default: a
marketplace password sitting in plain text is a poor trade for a gesture you make
once.

## Responsible use

This is a personal automation tool. It drives your own browser and your own
session, at a human pace, and reads pages you could open yourself. Automated
access is against the site's terms of use, so what you do with it is on you. Keep
it to your own searches and your own conversations: there is deliberately no way
to message many people at once, and there never will be.

## Licence

MIT. See [LICENSE](LICENSE).

Independent project, not affiliated with Leboncoin.
