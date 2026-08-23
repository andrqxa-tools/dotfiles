# Active Oberon SDK (minia2) for Windows. The Windows SDK is ob.exe with its library —
# no bash, no Cygwin, no WSL — so there is nothing to build and nothing to elevate.
$ErrorActionPreference = "Stop"

$Repo = "active-oberon/minia2"
$Dest = "$env:LOCALAPPDATA\Programs\a2sdk"

Write-Host "Fetching latest release info..."
$Release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
$Asset = $Release.assets | Where-Object { $_.name -like "*windows-amd64.tar.gz" } | Select-Object -First 1
if (-not $Asset) { throw "no windows-amd64 asset in the latest release of $Repo" }

$Archive = Join-Path $env:TEMP $Asset.name
Write-Host "Downloading $($Asset.browser_download_url)"
Invoke-WebRequest $Asset.browser_download_url -OutFile $Archive

# tar ships with Windows 10 1803 and later, so the tar.gz needs no extra tool.
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
tar -xzf $Archive -C $Dest --strip-components 1
Remove-Item $Archive -Force

# Per-user environment: what the language server and the editor configs read (docs/IDE.md).
[Environment]::SetEnvironmentVariable("A2_HOME", $Dest, "User")
[Environment]::SetEnvironmentVariable("A2_OB", "$Dest\ob.exe", "User")
[Environment]::SetEnvironmentVariable("A2_SYMS", "$Dest\lib", "User")

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$Dest*") {
    [Environment]::SetEnvironmentVariable("Path", "$Dest;$UserPath", "User")
}

Write-Host "Installed to $Dest. Open a new terminal, then: ob --version"
