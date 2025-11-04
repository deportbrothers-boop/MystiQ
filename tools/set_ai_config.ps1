param(
  [string]$PublicUrl,
  [string]$AppToken = "",
  [switch]$Local
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve project root (script is under tools/)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
$aiJsonPath = Join-Path $root 'assets\config\ai.json'

if ($Local) {
  $base = 'http://127.0.0.1:8787'
} else {
  if ([string]::IsNullOrWhiteSpace($PublicUrl)) {
    Write-Error "PublicUrl is required unless -Local is specified. Example: -PublicUrl https://mystiq-ai.onrender.com"
  }
  $base = $PublicUrl.TrimEnd('/')
}

$serverUrl = "$base/generate"
$streamUrl = "$base/stream"

$obj = [ordered]@{
  serverUrl = $serverUrl
  streamUrl = $streamUrl
  model = 'gpt-4o-mini'
  appToken = $AppToken
}

$json = $obj | ConvertTo-Json -Depth 5
Set-Content -Path $aiJsonPath -Value $json -Encoding UTF8

Write-Host "Updated $aiJsonPath" -ForegroundColor Green
Write-Host "serverUrl: $serverUrl" -ForegroundColor DarkGray
Write-Host "streamUrl: $streamUrl" -ForegroundColor DarkGray
if ($AppToken) { Write-Host "appToken: (set)" -ForegroundColor DarkGray } else { Write-Host "appToken: (empty)" -ForegroundColor DarkGray }

