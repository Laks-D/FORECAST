param(
  [string]$VapidKey = ""
)

$ErrorActionPreference = 'Stop'

# Keep build temp files off C: (common failure on low-space system drives).
# User preference: keep caches under D:\.
$tempBase = 'D:\Temp'
New-Item -ItemType Directory -Force -Path $tempBase | Out-Null
$env:TEMP = $tempBase
$env:TMP = $tempBase

# Keep pub cache under D: as well (safe if already configured).
if ([string]::IsNullOrWhiteSpace($env:PUB_CACHE)) {
  $env:PUB_CACHE = 'D:\PubCache'
}

# Run from the Flutter project root.
Set-Location (Join-Path $PSScriptRoot '..')

if (-not [string]::IsNullOrWhiteSpace($VapidKey)) {
  flutter run -d chrome --dart-define=FIREBASE_VAPID_KEY=$VapidKey
} else {
  flutter run -d chrome
}
