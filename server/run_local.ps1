param(
  [string]$OpenAIKey = $env:OPENAI_API_KEY,
  [string]$AppToken = $env:APP_TOKEN,
  [string]$Port = $env:PORT
)

Write-Host "Installing dependencies..." -ForegroundColor Cyan
npm install

if (![string]::IsNullOrWhiteSpace($OpenAIKey)) {
  $env:OPENAI_API_KEY = $OpenAIKey
}
if (![string]::IsNullOrWhiteSpace($AppToken)) {
  $env:APP_TOKEN = $AppToken
}
if (![string]::IsNullOrWhiteSpace($Port)) {
  $env:PORT = $Port
}

Write-Host "Starting server..." -ForegroundColor Cyan
npm start

