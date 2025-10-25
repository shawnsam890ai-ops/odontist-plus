Param(
  [switch]$Confirm = $true
)

Write-Host "This script will build and deploy Cloud Functions for the Odontist Plus project." -ForegroundColor Cyan
if ($Confirm) {
  $ok = Read-Host "Proceed? (y/n)"
  if ($ok -ne 'y') { Write-Host "Aborted"; exit 1 }
}

Write-Host "Installing dependencies..." -ForegroundColor Green
npm install

Write-Host "Building TypeScript..." -ForegroundColor Green
npm run build

Write-Host "Deploying functions..." -ForegroundColor Green
firebase deploy --only "functions"

Write-Host "Done." -ForegroundColor Cyan
