$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$ephemeral = Join-Path $projectRoot 'windows\flutter\ephemeral'
$links = Join-Path $ephemeral '.plugin_symlinks'
New-Item -ItemType Directory -Path $links -Force | Out-Null

$flutterCommand = Get-Command flutter -ErrorAction Stop
$flutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
$wrapperTarget = Join-Path $flutterRoot 'bin\cache\artifacts\engine\windows-x64\cpp_client_wrapper'
if (-not (Test-Path -LiteralPath $wrapperTarget)) {
  throw "Flutter Windows artifacts not found. Run 'flutter precache --windows' first."
}

$wrapperLink = Join-Path $ephemeral 'cpp_client_wrapper'
if (-not (Test-Path -LiteralPath $wrapperLink)) {
  cmd /c mklink /J "$wrapperLink" "$wrapperTarget" | Out-Null
}

$pluginsFile = Join-Path $projectRoot '.flutter-plugins-dependencies'
if (Test-Path -LiteralPath $pluginsFile) {
  $data = Get-Content -LiteralPath $pluginsFile -Raw | ConvertFrom-Json
  foreach ($plugin in $data.plugins.windows) {
    $destination = Join-Path $links $plugin.name
    if (-not (Test-Path -LiteralPath $destination)) {
      $target = $plugin.path.TrimEnd('\')
      cmd /c mklink /J "$destination" "$target" | Out-Null
    }
  }
}

Write-Host 'Windows plugin links are ready.'
