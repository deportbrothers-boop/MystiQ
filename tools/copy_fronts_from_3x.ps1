# Usage (PowerShell):
#   cd C:\MystiQ
#   pwsh -File tools\copy_fronts_from_3x.ps1

$base = "assets/images/tarot/fronts"
$dir3x = Join-Path $base "3.0x"
if (!(Test-Path $dir3x)) {
  Write-Error "3.0x klasörü bulunamadı: $dir3x"
  exit 1
}
$files = Get-ChildItem $dir3x -Filter *.png -File
if ($files.Count -eq 0) {
  Write-Error "3.0x klasöründe .png bulunamadı. Önce görselleri kopyalayın."
  exit 1
}
foreach ($f in $files) {
  Copy-Item $f.FullName (Join-Path $base $f.Name) -Force
}
Write-Output "Kopyalandı: $($files.Count) dosya 3.0x -> 1.0x"

