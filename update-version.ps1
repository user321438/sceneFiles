$now = Get-Date
$version = $now.ToString("yyyy.MM.dd.HHmm")
$xml = "<app>`n  <version>$version</version>`n</app>`n"
# This script lives in scripts\, so version.xml is one level up. Getting this wrong writes a
# version.xml nobody reads and the sidebar label silently never changes.
$versionXml = Join-Path (Split-Path -Parent $PSScriptRoot) 'PovCliNet.Web\version.xml'
Set-Content -Path $versionXml -Value $xml -NoNewline -Encoding UTF8
Write-Host "Version updated to $version"
