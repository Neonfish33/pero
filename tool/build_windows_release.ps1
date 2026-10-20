$ErrorActionPreference = 'Stop'

$source = Split-Path -Parent $PSScriptRoot
$buildRoot = 'C:\pero_build'
$release = Join-Path $buildRoot 'build\windows\x64\runner\Release'
$dist = Join-Path $source 'dist\pero-windows-x64'
$zip = Join-Path $source 'dist\pero-windows-x64.zip'

Write-Host "Синхронизация исходников в $buildRoot"
robocopy $source $buildRoot /E /XD build .dart_tool .git ephemeral dist /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) {
  throw "robocopy завершился с ошибкой: $LASTEXITCODE"
}

Push-Location $buildRoot
try {
  flutter clean
  if ($LASTEXITCODE -ne 0) { throw 'flutter clean завершился с ошибкой' }

  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get завершился с ошибкой' }

  powershell -ExecutionPolicy Bypass -File tool/prepare_windows_links.ps1
  if ($LASTEXITCODE -ne 0) { throw 'prepare_windows_links.ps1 завершился с ошибкой' }

  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'flutter build windows --release завершился с ошибкой' }
} finally {
  Pop-Location
}

if (Test-Path -LiteralPath $dist) {
  Remove-Item -LiteralPath $dist -Recurse -Force
}
New-Item -ItemType Directory -Path $dist -Force | Out-Null
Copy-Item -Path (Join-Path $release '*') -Destination $dist -Recurse -Force

if (Test-Path -LiteralPath $zip) {
  Remove-Item -LiteralPath $zip -Force
}
Compress-Archive -Path (Join-Path $dist '*') -DestinationPath $zip -CompressionLevel Optimal

Write-Host "Готово: $dist"
Write-Host "Архив: $zip"
