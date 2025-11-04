# Usage (PowerShell):
#   cd C:\MystiQ
#   pwsh -File tools\copy_categories_from_3x.ps1

$base = "assets/images/categories"
$dir3x = Join-Path $base "3.0x"
if (!(Test-Path $dir3x)) {
  Write-Error "3.0x klasörü bulunamadı: $dir3x"
  exit 1
}
New-Item -ItemType Directory -Force $base | Out-Null
Get-ChildItem $dir3x -File -Filter *.png | ForEach-Object {
  Copy-Item $_.FullName (Join-Path $base $_.Name) -Force
}
Write-Output "3.0x -> 1.0x kopyalama tamamlandı."

