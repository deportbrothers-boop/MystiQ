<#
Converts PNG/JPG assets under assets/images to WebP (lossy, quality 85 by default).
Requires: cwebp in PATH (install libwebp or Google WebP utilities).

Usage (PowerShell):
  # dry run
  .\tools\convert_to_webp.ps1 -DryRun

  # convert all under assets/images (recursively)
  .\tools\convert_to_webp.ps1

  # custom quality
  .\tools\convert_to_webp.ps1 -Quality 80

Notes:
  - Generates side-by-side .webp files next to originals (does not delete originals).
  - Flutter can load WebP via Image.asset when the asset path points to .webp.
#>

param(
  [int]$Quality = 85,
  [switch]$DryRun
)

function Convert-File($path) {
  $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
  if ($ext -ne '.png' -and $ext -ne '.jpg' -and $ext -ne '.jpeg') { return }
  $out = [System.IO.Path]::ChangeExtension($path, '.webp')
  if (Test-Path $out) { return }
  $cmd = "cwebp -q $Quality `"$path`" -o `"$out`""
  if ($DryRun) {
    Write-Host "[DRY] $cmd"
  } else {
    Write-Host "[WEBP] $path -> $out"
    cmd /c $cmd | Out-Null
  }
}

$root = Join-Path (Get-Location) 'assets/images'
if (!(Test-Path $root)) { Write-Error "assets/images not found"; exit 1 }
Get-ChildItem -Recurse -File $root | ForEach-Object { Convert-File $_.FullName }

