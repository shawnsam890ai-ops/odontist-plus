<#
    Refresh-AndroidBuild.ps1

    Purpose:
      Automates cleanup and refresh of the Flutter Android build environment when
      encountering Gradle version mismatch errors (e.g. plugins complaining about
      Gradle 8.10 when wrapper already set to 8.13).

    What it does (in order):
      1. Validates it is run from (or passed) a Flutter project root.
      2. Stops any running Gradle daemons (best-effort).
      3. Runs `flutter clean`.
      4. Deletes local project build caches: .gradle/ and build/ (root & android/ if present).
      5. (Optional) Purges Gradle 8.10 wrapper distributions from %USERPROFILE%\.gradle\wrapper\dists.
      6. Runs `flutter pub get`.
      7. (Optional) Builds an APK or launches `flutter run` based on switches.

    Usage examples (PowerShell):
      # Basic refresh only
      ./tools/Refresh-AndroidBuild.ps1

      # Also build an APK at the end
      ./tools/Refresh-AndroidBuild.ps1 -BuildApk

      # Run the app on attached device/emulator after refresh
      ./tools/Refresh-AndroidBuild.ps1 -Run

      # Aggressively purge old Gradle 8.10 distributions in USERPROFILE\.gradle
      ./tools/Refresh-AndroidBuild.ps1 -PurgeOldGradle

      # Specify project root explicitly
      ./tools/Refresh-AndroidBuild.ps1 -ProjectRoot 'C:\path\to\mydentalapk'

    NOTE:
      If execution policy blocks the script, start a new PowerShell session and run:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    Safe to re-run multiple times.
#>
[CmdletBinding()]
param(
    [string] $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch] $PurgeOldGradle,     # Remove gradle-8.10* dists under user .gradle
    [switch] $BuildApk,           # Run flutter build apk after refresh
    [switch] $Run,                # Run flutter run after refresh (mutually exclusive with -BuildApk)
    [switch] $SkipPubGet,         # Skip flutter pub get (not usually recommended)
    [switch] $ZipLogs             # Compress the log directory after run
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Info($msg)    { Write-Host "[INFO] $msg" -ForegroundColor DarkCyan }
function Write-Warn($msg)    { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-ErrLine($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

 # Log setup
 $logRoot = Join-Path $ProjectRoot 'tools/logs'
 if (!(Test-Path $logRoot)) { New-Item -ItemType Directory -Path $logRoot | Out-Null }
 $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
 $sessionDir = Join-Path $logRoot "android_$timestamp"
 New-Item -ItemType Directory -Path $sessionDir | Out-Null
 $sessionLog = Join-Path $sessionDir 'session.log'

 function Append-Log($text) { if ($null -ne $text -and $text.Length -gt 0) { $text | Out-File -FilePath $sessionLog -Append -Encoding UTF8 } }

function Exec($cmd, $args) {
    Write-Info "$cmd $($args -join ' ')"
    Append-Log "\n> $cmd $($args -join ' ')"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $cmd
    $psi.Arguments = ($args -join ' ')
    $psi.WorkingDirectory = $ProjectRoot
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    if ($out.Trim()) { Write-Host $out; Append-Log $out }
    if ($err.Trim()) { Write-Warn $err; Append-Log "[stderr] $err" }
    if ($p.ExitCode -ne 0) { Append-Log "ExitCode: $($p.ExitCode)"; throw "Command failed ($cmd): exit $($p.ExitCode)" }
}

if (!(Test-Path $ProjectRoot)) { throw "ProjectRoot not found: $ProjectRoot" }
if (!(Test-Path (Join-Path $ProjectRoot 'pubspec.yaml'))) {
    throw "pubspec.yaml not found under $ProjectRoot — not a Flutter project root. Use -ProjectRoot to specify." }

Write-Section "Project Root"
Write-Info "Using project root: $ProjectRoot"

$androidDir = Join-Path $ProjectRoot 'android'
if (!(Test-Path $androidDir)) { throw "Android directory missing: $androidDir" }

Write-Section "Show Current Gradle Wrapper Version"
$wrapperFile = Join-Path $androidDir 'gradle/wrapper/gradle-wrapper.properties'
if (Test-Path $wrapperFile) {
    (Get-Content $wrapperFile) | Where-Object { $_ -match 'distributionUrl' } | ForEach-Object { Write-Host $_ }
} else {
    Write-Warn "gradle-wrapper.properties not found (unexpected)."
}

Write-Section "Stopping Gradle Daemons"
try {
    Push-Location $androidDir
    if (Test-Path (Join-Path $androidDir 'gradlew.bat')) {
        & .\gradlew.bat --stop 2>$null | Out-Null
        Write-Info "Gradle daemons stop requested."
    } else {
        Write-Warn "gradlew.bat not found; skipping daemon stop."
    }
} catch { Write-Warn "Stopping daemons failed: $($_.Exception.Message)" } finally { Pop-Location }

Write-Section "Flutter Clean"
Exec 'flutter' @('clean')

Write-Section "Removing Local Build Caches"
function Remove-Dir($p) {
    if (Test-Path $p) {
        Write-Info "Deleting $p"
        try { Remove-Item -Recurse -Force -LiteralPath $p } catch { Write-Warn "Failed to delete $p : $($_.Exception.Message)" }
    }
}
Remove-Dir (Join-Path $ProjectRoot '.gradle')
Remove-Dir (Join-Path $ProjectRoot 'build')
Remove-Dir (Join-Path $androidDir  '.gradle')
Remove-Dir (Join-Path $androidDir  'build')

if ($PurgeOldGradle) {
    Write-Section "Purging Old Gradle Distributions (8.10*)"
    $userGradle = Join-Path $env:USERPROFILE '.gradle\wrapper\dists'
    if (Test-Path $userGradle) {
        Get-ChildItem $userGradle -Directory -Filter 'gradle-8.10*' -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Info "Removing dist: $($_.FullName)"
            try { Remove-Item -Recurse -Force -LiteralPath $_.FullName } catch { Write-Warn "Failed: $($_.Exception.Message)" }
        }
    } else {
        Write-Warn "User Gradle dists directory not found: $userGradle"
    }
} else {
    Write-Info "Skipping purge of old Gradle dists (use -PurgeOldGradle to enable)."
}

if (-not $SkipPubGet) {
    Write-Section "flutter pub get"
    Exec 'flutter' @('pub','get')
} else {
    Write-Warn "Skipping flutter pub get per -SkipPubGet"
}

if ($BuildApk -and $Run) {
    Write-Warn "Both -BuildApk and -Run specified; -Run will be ignored."
}

if ($BuildApk) {
    Write-Section "Building APK"
    Exec 'flutter' @('build','apk')
} elseif ($Run) {
    Write-Section "Launching flutter run"
    Exec 'flutter' @('run')
}

if ($ZipLogs) {
    Write-Section 'Zipping Logs'
    $zipPath = "$sessionDir.zip"
    if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($sessionDir, $zipPath)
    Write-Info "Created log archive: $zipPath"
}

Write-Section "Done"
Write-Info "Refresh completed successfully. Logs: $sessionDir"
if ($ZipLogs) { Write-Info "Zip: $sessionDir.zip" }
Write-Host "`nNext steps: If errors persist, send session.log or zip for analysis." -ForegroundColor Green
