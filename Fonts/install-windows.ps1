$ErrorActionPreference = "Stop"

$Repo = "ryanoasis/nerd-fonts"
$Font = "JetBrainsMono"
$Dest = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\$($Font)NerdFont"
$Archive = "$Font.zip"

New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Set-Location $Dest

Write-Host "Fetching latest release info..."
$Release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
$Asset = $Release.assets | Where-Object { $_.name -eq $Archive }

if (-not $Asset) { throw "$Archive not found in latest release" }

$Url = $Asset.browser_download_url

Write-Host "Downloading $Url"
Invoke-WebRequest $Url -OutFile $Archive

Write-Host "Extracting ZIP archive..."
Expand-Archive -Path $Archive -DestinationPath $Dest -Force

Remove-Item $Archive -Force

Write-Host "Cleaning up extra variants (Mono/Propo/NL)..."

# Удаляем только variant-файлы, а не всё с 'Mono'
Get-ChildItem -File | Where-Object {
  $_.Extension -in @(".ttf", ".otf") -and (
    $_.Name -like "JetBrainsMonoNerdFontMono-*" -or
    $_.Name -like "JetBrainsMonoNerdFontPropo-*" -or
    $_.Name -like "JetBrainsMonoNLNerdFont*"
  )
} | Remove-Item -Force

Write-Host "Done. Remaining font files:"
Get-ChildItem -File | Where-Object { $_.Extension -in @(".ttf",".otf") } | Select-Object Name
Write-Host "Restart Windows Terminal / VS Code to apply the font."
