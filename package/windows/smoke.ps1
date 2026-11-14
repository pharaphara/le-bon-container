<#
.SYNOPSIS
    Install it, run it, and ask the browser what it looks like.

.DESCRIPTION
    Everything else in this repository is tested without a browser and without a
    network, against frozen samples, which is the right way round for domain logic
    and says nothing at all about the thing that actually breaks on a desktop: a
    real installer, a real Chrome, a real profile directory, and a process that has
    to let go of its browser when it stops.

    So this runs against the installed application, on a machine that has a screen
    and a browser, which is what a CI runner is. Two ways in, because they fail
    differently:

      http    The server a container exposes. Start it, ask it what the browser
              looks like from inside a page, and the answer that matters is
              webdriver false: a browser somebody started, not one a library did.

      stdio   What a desktop client does. Speak the protocol on standard input,
              close the stream, and the process must leave on its own, with its
              browser closed and the profile not marked as crashed.

    It never asks leboncoin.fr anything. A runner is a data centre address, which
    is precisely the kind this project tells you not to read the site from.

    Exits non zero on the first thing that is wrong, and says which.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Exe,
    [string]$WorkDir = "$env:TEMP\lbc-smoke"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$profileDir = Join-Path $env:LOCALAPPDATA "le-bon-container\profile"
$failures = @()

function Say($what) { Write-Host "  $what" }
function Fail($what) { $script:failures += $what; Write-Host "  FAIL $what" }
function Browsers { @(Get-Process chrome, msedge -ErrorAction SilentlyContinue) }

if (-not (Test-Path $Exe)) { throw "not installed: $Exe" }
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Say "exe       $Exe"
Say "size      $([math]::Round((Get-Item $Exe).Length / 1KB)) kB launcher"

# ----------------------------------------------------------------- http
Write-Host "`nhttp"
$app = Start-Process -FilePath $Exe -PassThru -RedirectStandardOutput "$WorkDir\http.out" `
    -RedirectStandardError "$WorkDir\http.err" -WindowStyle Hidden
$up = $false
foreach ($i in 1..60) {
    Start-Sleep -Seconds 1
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $c.Connect("127.0.0.1", 8788)
        $c.Close()
        $up = $true
        break
    }
    catch { }
}
if (-not $up) {
    Fail "nothing listening on 8788 after 60 s"
}
else {
    Say "listening on 8788 after about $i s"
    $headers = @{ Accept = "application/json, text/event-stream" }
    $init = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}'
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:8788/mcp" -Method Post -Body $init `
        -ContentType "application/json" -Headers $headers -UseBasicParsing
    $session = $r.Headers["Mcp-Session-Id"]
    if (-not $session) { Fail "no session id in the initialize response" }
    $headers["Mcp-Session-Id"] = $session
    Invoke-WebRequest -Uri "http://127.0.0.1:8788/mcp" -Method Post `
        -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}' `
        -ContentType "application/json" -Headers $headers -UseBasicParsing | Out-Null

    # The one question worth asking a real browser.
    $call = '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"status","arguments":{"browser":true}}}'
    $status = (Invoke-WebRequest -Uri "http://127.0.0.1:8788/mcp" -Method Post -Body $call `
            -ContentType "application/json" -Headers $headers -UseBasicParsing -TimeoutSec 180).Content
    if ($status -match "webdriver false") {
        Say "the browser says webdriver false"
    }
    else {
        Fail "the browser did not say webdriver false: $status"
    }
    if ($status -match "talking to it over its debugging port") {
        Say "attached to a browser it started, rather than one the library launched"
    }
    else {
        Fail "not attached over a debugging port: $status"
    }
    if (Test-Path $profileDir) { Say "profile at $profileDir" }
    else { Fail "no profile directory at $profileDir" }
}
# Stop-Process is a terminate, not a request, so nothing is concluded from what
# the browser does here. The stdio half is where leaving cleanly is checked.
Stop-Process -Id $app.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Browsers | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# ----------------------------------------------------------------- stdio
Write-Host "`nstdio"
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $Exe
$psi.Arguments = "--stdio"
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$p = [System.Diagnostics.Process]::Start($psi)
# Read both asynchronously: a full pipe nobody drains is a deadlock.
$outTask = $p.StandardOutput.ReadToEndAsync()
$errTask = $p.StandardError.ReadToEndAsync()
$p.StandardInput.WriteLine('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}')
Start-Sleep -Seconds 25
$p.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"notifications/initialized"}')
$p.StandardInput.WriteLine('{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
Start-Sleep -Seconds 10
$p.StandardInput.Close()
if ($p.WaitForExit(90000)) {
    Say "left on its own when the stream closed, exit $($p.ExitCode)"
}
else {
    Fail "still running 90 s after the stream closed"
    $p.Kill()
}
$out = $outTask.Result
$err = $errTask.Result
$out | Set-Content "$WorkDir\stdio.out"
$err | Set-Content "$WorkDir\stdio.err"

$lines = @($out -split "`r?`n" | Where-Object { $_.Trim() -ne "" })
$notJson = @($lines | Where-Object { -not $_.StartsWith("{") })
if ($notJson.Count -eq 0) {
    Say "$($lines.Count) lines on standard output, every one of them protocol"
}
else {
    Fail "standard output carries $($notJson.Count) lines that are not protocol: $($notJson[0])"
}
if ($out -match '"id":1' -and $out -match '"tools"') { Say "initialize and tools/list answered" }
else { Fail "initialize or tools/list went unanswered" }
if ($err -match "le bon container") { Say "banner on standard error, where it belongs" }
else { Fail "no banner on standard error" }

$left = Browsers
if ($left.Count -eq 0) { Say "no browser left behind" }
else { Fail "$($left.Count) browser processes outlived the server"; $left | Stop-Process -Force }

$prefs = Join-Path $profileDir "Default\Preferences"
if (Test-Path $prefs) {
    $exit = (Get-Content $prefs -Raw | ConvertFrom-Json).profile.exit_type
    if ($exit -eq "Crashed") { Fail "the profile is marked Crashed, so the next window offers to restore" }
    else { Say "profile closed as '$exit'" }
}

# ----------------------------------------------------------------- verdict
Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "$($failures.Count) failed:"
    $failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host "all good on $([System.Environment]::OSVersion.VersionString)"
