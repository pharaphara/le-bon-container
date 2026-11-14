<#
.SYNOPSIS
    Build the Windows install: an installer, and a folder that needs no installing.

.DESCRIPTION
    A Windows box already has the three things the container has to build for
    itself: a screen, a browser, and a user who can see both. What it does not have
    is a Java runtime, so one is cut to size with jlink and shipped inside the
    install. Nothing has to be installed first, Docker included.

    The steps, in the order they matter:

      extract   The Spring Boot jar is a jar of jars, and jpackage wants plain ones.
                The jarmode tool unpacks it into a classic jar plus its lib folder,
                which is also what makes the next step possible.

      prune     Playwright's bundle carries a Node runtime for five platforms. This
                install runs one of them, and the other four are 169 MB of nothing.

      jlink     A runtime holding the modules this application actually loads, which
                is 57 MB against the 286 MB of a whole JDK. The list is not guessed:
                it was cut down until the application stopped starting, then the last
                one was put back.

      jpackage  Twice. An app-image, which is a folder you can copy onto a machine
                and run, zipped for the people who would rather not install
                anything. Then an msi, which is the same folder with a Start menu
                entry and an uninstaller.

    The msi needs WiX 3 on the PATH (candle.exe and light.exe). The zip does not, so
    the script says so and carries on rather than failing the lot.

.PARAMETER Type
    both, msi or portable.

.EXAMPLE
    mvn -B -DskipTests package
    pwsh package/windows/package.ps1
#>
[CmdletBinding()]
param(
    [string]$Jar,
    [string]$Version,
    [string]$Out = "target/windows",
    [ValidateSet("both", "msi", "portable")]
    [string]$Type = "both"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# The product's identity for Windows installer upgrades. Generated once and never
# again: change it and an upgrade becomes a second copy sitting next to the first.
$UpgradeUuid = "37510255-ae20-42e2-a2bc-6073183e265a"

$Name = "le-bon-container"
$Vendor = "pharaphara"
$Description = "Browse leboncoin.fr with an AI, through a real browser, over MCP"

# The modules the application loads, including the ones only reflection asks for.
$Modules = @(
    "java.base", "java.desktop", "java.instrument", "java.logging", "java.management",
    "java.naming", "java.net.http", "java.prefs", "java.rmi", "java.scripting",
    "java.security.jgss", "java.sql", "java.transaction.xa", "java.xml",
    "jdk.crypto.ec", "jdk.crypto.cryptoki", "jdk.unsupported", "jdk.zipfs",
    "jdk.management"
) -join ","

# The four platforms this install will never run on.
$ForeignDrivers = @("driver/mac/", "driver/mac-arm64/", "driver/linux/", "driver/linux-arm64/")

$root = Resolve-Path (Join-Path $PSScriptRoot "../..")
Push-Location $root
try {
    if (-not $Jar) {
        $Jar = (Get-ChildItem "target" -Filter "lbc-*.jar" -File |
            Where-Object { $_.Name -notlike "*.original" } |
            Select-Object -First 1 -ExpandProperty FullName)
    }
    if (-not $Jar -or -not (Test-Path $Jar)) {
        throw "no jar in target. Run: mvn -B -DskipTests package"
    }
    if (-not $Version) {
        # An msi version is three numbers and nothing else, so -SNAPSHOT goes.
        if ((Split-Path $Jar -Leaf) -match "lbc-(\d+\.\d+\.\d+)") {
            $Version = $Matches[1]
        }
        else {
            $Version = "0.0.1"
        }
    }

    $stage = Join-Path $Out "stage"
    $app = Join-Path $stage "app"
    $runtime = Join-Path $stage "runtime"
    if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
    New-Item -ItemType Directory -Path $app -Force | Out-Null

    Write-Host "jar       $Jar"
    Write-Host "version   $Version"

    # ---------------------------------------------------------------- extract
    & java "-Djarmode=tools" -jar $Jar extract --destination $app
    if ($LASTEXITCODE -ne 0) { throw "extracting the jar failed" }
    Get-ChildItem $app -Filter "lbc-*.jar" -File |
        ForEach-Object { Move-Item $_.FullName (Join-Path $app "lbc.jar") -Force }

    # ---------------------------------------------------------------- prune
    $bundle = Get-ChildItem (Join-Path $app "lib") -Filter "driver-bundle-*.jar" -File |
        Select-Object -First 1
    if ($bundle) {
        $before = [math]::Round($bundle.Length / 1MB)
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::Open($bundle.FullName, "Update")
        try {
            $doomed = @($zip.Entries | Where-Object {
                    $entry = $_.FullName
                    $ForeignDrivers | Where-Object { $entry.StartsWith($_) }
                })
            foreach ($entry in $doomed) { $entry.Delete() }
        }
        finally { $zip.Dispose() }
        $after = [math]::Round((Get-Item $bundle.FullName).Length / 1MB)
        Write-Host "driver    $before MB -> $after MB, win32_x64 only"
    }

    # ---------------------------------------------------------------- jlink
    & jlink --add-modules $Modules --output $runtime `
        --strip-debug --no-man-pages --no-header-files --compress=zip-6
    if ($LASTEXITCODE -ne 0) { throw "jlink failed" }
    $runtimeMb = [math]::Round(((Get-ChildItem $runtime -Recurse -File |
                Measure-Object Length -Sum).Sum) / 1MB)
    Write-Host "runtime   $runtimeMb MB"

    # ---------------------------------------------------------------- jpackage
    $common = @(
        "--name", $Name,
        "--app-version", $Version,
        "--vendor", $Vendor,
        "--description", $Description,
        "--copyright", "pharaphara, MIT",
        "--input", $app,
        "--main-jar", "lbc.jar",
        "--runtime-image", $runtime,
        "--icon", (Join-Path $PSScriptRoot "lbc.ico"),
        # 70 percent of the machine, like the container, and a server that answers
        # this machine only. The tools drive a browser holding a signed in session,
        # so there is nothing here anyone else on the network should reach.
        "--java-options", "-XX:MaxRAMPercentage=70",
        "--java-options", "-Dserver.address=127.0.0.1"
    )

    if ($Type -ne "msi") {
        $imageDir = Join-Path $Out "image"
        & jpackage --type app-image @common --dest $imageDir
        if ($LASTEXITCODE -ne 0) { throw "jpackage app-image failed" }
        $zipPath = Join-Path $Out "$Name-$Version-windows-x64-portable.zip"
        Compress-Archive -Path (Join-Path $imageDir $Name) -DestinationPath $zipPath -Force
        Write-Host "portable  $zipPath"
    }

    if ($Type -ne "portable") {
        if (-not (Get-Command "candle.exe" -ErrorAction SilentlyContinue)) {
            # Installed but not on the PATH is the normal state of WiX on a fresh
            # machine, and jpackage only ever looks on the PATH.
            $candle = Get-ChildItem "C:\Program Files*\WiX Toolset v3*\bin\candle.exe" `
                -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($candle) {
                $env:PATH = "$($candle.DirectoryName);$env:PATH"
                Write-Host "wix       $($candle.DirectoryName)"
            }
        }
        if (-not (Get-Command "candle.exe" -ErrorAction SilentlyContinue)) {
            Write-Warning ("WiX 3 was not found (candle.exe), so no msi was built." +
                " Install it with: choco install wixtoolset --version 3.14.1 -y")
        }
        else {
            # Per user: no administrator, and the profile and the searches live under
            # the user's own AppData anyway.
            & jpackage --type msi @common --dest $Out `
                --win-menu --win-menu-group $Name --win-shortcut --win-dir-chooser `
                --win-per-user-install --win-upgrade-uuid $UpgradeUuid --win-console
            if ($LASTEXITCODE -ne 0) { throw "jpackage msi failed" }
            Get-ChildItem $Out -Filter "*.msi" -File | ForEach-Object {
                $target = Join-Path $Out "$Name-$Version-windows-x64.msi"
                if ($_.FullName -ne $target) { Move-Item $_.FullName $target -Force }
                Write-Host "msi       $target"
            }
        }
    }

    Remove-Item $stage -Recurse -Force
    Get-ChildItem $Out -File | ForEach-Object {
        "{0,-52} {1,6} MB" -f $_.Name, [math]::Round($_.Length / 1MB)
    }
}
finally {
    Pop-Location
}
