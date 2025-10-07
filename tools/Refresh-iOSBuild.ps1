<#
    Refresh-iOSBuild.ps1

    Purpose:
      Automates cleanup and refresh of the Flutter iOS build environment.
      Designed for Windows PowerShell running against a remote Mac build share OR
      for direct use on macOS PowerShell (pwsh). On Windows without a Mac host
      you can still run the Flutter-side cleanup (flutter clean).

    Features:
      1. flutter clean
      2. Optionally remove ios/Pods, Podfile.lock, DerivedData
      3. Re-run pod install (if CocoaPods present and not -SkipPods)
      4. flutter pub get (unless -SkipPubGet)
      5. Optional build modes: -BuildIpa (archive + export) or -BuildRunner (flutter build ios --no-codesign)
      6. Collect build logs into tools/logs (timestamped)
      7. Optional -ZipLogs to compress logs into a zip

    Usage:
      ./tools/Refresh-iOSBuild.ps1
      ./tools/Refresh-iOSBuild.ps1 -CleanPods
      ./tools/Refresh-iOSBuild.ps1 -CleanPods -BuildRunner
      ./tools/Refresh-iOSBuild.ps1 -CleanPods -BuildIpa -Scheme MyApp -ExportOptions ./ExportOptions.plist
      ./tools/Refresh-iOSBuild.ps1 -ZipLogs

    NOTE:
      For code signing archive export you must run on macOS with Xcode + cocoapods.
#>
[CmdletBinding()]
param(
    [string] $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch] $CleanPods,
    [switch] $SkipPubGet,
    [switch] $SkipPods,
    [switch] $BuildRunner,    # flutter build ios --no-codesign
    [switch] $BuildIpa,       # xcodebuild archive + export (requires Scheme)
    [string] $Scheme = 'Runner',
    [string] $Configuration = 'Release',
    [string] $ExportOptions,  # path to ExportOptions.plist
    [switch] $ZipLogs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Section($m){ Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Info($m){ Write-Host "[INFO] $m" -ForegroundColor DarkCyan }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function ErrLine($m){ Write-Host "[ERROR] $m" -ForegroundColor Red }

if (!(Test-Path (Join-Path $ProjectRoot 'pubspec.yaml'))) { throw "pubspec.yaml not found under $ProjectRoot" }
$iosDir = Join-Path $ProjectRoot 'ios'
if (!(Test-Path $iosDir)) { throw "iOS directory missing: $iosDir" }

$logRoot = Join-Path $ProjectRoot 'tools/logs'
if (!(Test-Path $logRoot)) { New-Item -ItemType Directory -Path $logRoot | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sessionDir = Join-Path $logRoot "ios_$timestamp"
New-Item -ItemType Directory -Path $sessionDir | Out-Null
$sessionLog = Join-Path $sessionDir 'session.log'

function Tee($text){ $text | Tee-Object -FilePath $sessionLog -Append }

function RunCapture($cmd, $args){
    Info "$cmd $($args -join ' ')"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $cmd
    $psi.Arguments = ($args -join ' ')
    $psi.WorkingDirectory = $ProjectRoot
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    if ($out.Trim()){ Tee $out }
    if ($err.Trim()){ Tee "[stderr] $err" }
    if ($p.ExitCode -ne 0) { throw "Command failed ($cmd) exit $($p.ExitCode)" }
}

Section 'flutter clean'
RunCapture 'flutter' @('clean')

if (-not $SkipPubGet){
  Section 'flutter pub get'
  RunCapture 'flutter' @('pub','get')
} else { Warn 'Skipping flutter pub get' }

if ($CleanPods){
  Section 'Cleaning Pods'
  $podDir = Join-Path $iosDir 'Pods'
  $podLock = Join-Path $iosDir 'Podfile.lock'
  if (Test-Path $podDir){ Info 'Removing Pods dir'; Remove-Item -Recurse -Force -LiteralPath $podDir }
  if (Test-Path $podLock){ Info 'Removing Podfile.lock'; Remove-Item -Force -LiteralPath $podLock }
  $derived = Join-Path ([Environment]::GetFolderPath('UserProfile')) "Library/Developer/Xcode/DerivedData"
  if (Test-Path $derived){ Warn "(Optional) Manually clear DerivedData if needed: $derived" }
}

if (-not $SkipPods){
  Section 'pod install'
  try {
    Push-Location $iosDir
    if (Get-Command pod -ErrorAction SilentlyContinue) {
      RunCapture 'pod' @('install')
    } else { Warn 'CocoaPods not installed (pod command missing); skipping.' }
  } finally { Pop-Location }
} else { Warn 'Skipping pod install per -SkipPods' }

if ($BuildRunner -and $BuildIpa){ Warn '-BuildRunner and -BuildIpa both set; using -BuildIpa only.'; $BuildRunner = $false }

if ($BuildRunner){
  Section 'flutter build ios --no-codesign'
  RunCapture 'flutter' @('build','ios','--no-codesign')
}

if ($BuildIpa){
  if (-not $ExportOptions){ Warn 'No -ExportOptions provided; archive only (no export)'; }
  Section 'xcodebuild archive'
  $archivePath = Join-Path $sessionDir "$Scheme.xcarchive"
  Push-Location $iosDir
  try {
    RunCapture 'xcodebuild' @('archive',"-scheme","$Scheme","-configuration","$Configuration","-archivePath","$archivePath")
    if ($ExportOptions){
      Section 'xcodebuild -exportArchive'
      $exportDir = Join-Path $sessionDir 'export'
      New-Item -ItemType Directory -Path $exportDir | Out-Null
      RunCapture 'xcodebuild' @('-exportArchive','-archivePath',"$archivePath",'-exportOptionsPlist',"$ExportOptions",'-exportPath',"$exportDir")
    }
  } finally { Pop-Location }
}

if ($ZipLogs){
  Section 'Zipping Logs'
  $zipPath = "$sessionDir.zip"
  if (Test-Path $zipPath){ Remove-Item -Force $zipPath }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::CreateFromDirectory($sessionDir, $zipPath)
  Info "Created log archive: $zipPath"
}

Section 'Done'
Tee 'iOS refresh complete.'
Write-Host "Logs: $sessionDir" -ForegroundColor Green
if ($ZipLogs){ Write-Host "Zip: $sessionDir.zip" -ForegroundColor Green }
