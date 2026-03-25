# Sets PATH so portable Node/NPM global tools (firebase) and FlutterFire are available.
# Usage (from repo root):
#   . .\scripts\dev_env.ps1
#   firebase --version
#   firebase login

$ErrorActionPreference = 'Stop'

$nodeBase = 'D:\Tools\node'
$npmGlobal = 'D:\Tools\npm-global'
$pubCacheBin = 'D:\PubCache\bin'

$nodeDir = Get-ChildItem $nodeBase -Directory -Filter 'node-v*-win-x64' -ErrorAction SilentlyContinue |
  Sort-Object Name -Descending |
  Select-Object -First 1

if (-not $nodeDir) {
  throw "Portable Node not found under $nodeBase. Expected a folder like node-vXX.YY.ZZ-win-x64."
}

$pathsToAdd = @(
  $nodeDir.FullName,
  $npmGlobal,
  (Join-Path $npmGlobal 'node_modules\.bin'),
  $pubCacheBin
)

foreach ($p in $pathsToAdd) {
  if (-not [string]::IsNullOrWhiteSpace($p)) {
    $env:PATH = "$p;" + $env:PATH
  }
}

Write-Host "Using Node: $($nodeDir.FullName)"
Write-Host "PATH updated for this session."