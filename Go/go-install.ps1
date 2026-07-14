<#
.SYNOPSIS
  Install or update the Go toolchain on Windows (no MSI).

.DESCRIPTION
  Downloads the Go .zip from go.dev and extracts it to $GoRoot (default
  C:\Programms\go — the folder used for installer-less programs). Sets
  persistent per-user environment variables (GOROOT, GOPATH, GOMODCACHE,
  GOCACHE) and prepends the bin dirs to the user PATH, so the toolchain is
  available in both new terminals and GUI apps. Re-running upgrades in place.

.PARAMETER Version
  Go version to install, e.g. "1.26.2". Defaults to the latest stable release.

.PARAMETER Arch
  Target architecture: amd64 | arm64 | 386. Defaults to the current machine.

.PARAMETER GoRoot
  Install location for the toolchain. Its leaf must be "go" (the zip contains
  a top-level go\ folder). Default: C:\Programms\go

.EXAMPLE
  .\go-install.ps1                # install/update to the latest release
  .\go-install.ps1 -Version 1.25.5
#>

[CmdletBinding()]
param(
  [string]$Version,
  [ValidateSet("amd64", "arm64", "386")]
  [string]$Arch,
  [string]$GoRoot = "C:\Programms\go"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- resolve version (default: latest stable) ---------------------------
if (-not $Version) {
  Write-Host "Resolving latest Go version..."
  $Version = (Invoke-RestMethod "https://go.dev/VERSION?m=text").Split("`n")[0]
}
$Version = $Version -replace '^go', ''   # normalize "go1.26.2" -> "1.26.2"

# --- resolve architecture -----------------------------------------------
if (-not $Arch) {
  switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { $Arch = "amd64" }
    "ARM64" { $Arch = "arm64" }
    "x86"   { $Arch = "386" }
    default { $Arch = "amd64" }
  }
}

# --- paths --------------------------------------------------------------
$GoPath  = Join-Path $env:USERPROFILE "go"
$GoCache = Join-Path $env:LOCALAPPDATA "go-build"
$goExe   = Join-Path $GoRoot "bin\go.exe"
$parent  = Split-Path $GoRoot -Parent
$archive = "go$Version.windows-$Arch.zip"
$url     = "https://dl.google.com/go/$archive"
$tmp     = Join-Path $env:TEMP $archive

# --- skip if already at this version ------------------------------------
if (Test-Path $goExe) {
  $current = ((& $goExe version).Split(" ")[2]) -replace '^go', ''
  if ($current -eq $Version) {
    Write-Host "Go $Version already installed at $GoRoot."
  }
}

# --- download -----------------------------------------------------------
Write-Host "Downloading Go $Version ($Arch)..."
Invoke-WebRequest -Uri $url -OutFile $tmp

# --- install (remove old, extract fresh) --------------------------------
Write-Host "Installing to $GoRoot..."
if (Test-Path $GoRoot) { Remove-Item -Recurse -Force $GoRoot }
New-Item -ItemType Directory -Force -Path $parent | Out-Null
# The zip has a top-level "go\" folder, so extracting into the parent yields $GoRoot.
Expand-Archive -Path $tmp -DestinationPath $parent -Force
Remove-Item $tmp -Force

# --- create GOPATH layout -----------------------------------------------
foreach ($d in @("$GoPath\src", "$GoPath\bin", "$GoPath\pkg", $GoCache)) {
  New-Item -ItemType Directory -Force -Path $d | Out-Null
}

# --- persistent per-user environment (console + GUI) --------------------
Write-Host "Setting user environment variables..."
[Environment]::SetEnvironmentVariable("GOROOT",     $GoRoot,          "User")
[Environment]::SetEnvironmentVariable("GOPATH",     $GoPath,          "User")
[Environment]::SetEnvironmentVariable("GOMODCACHE", "$GoPath\pkg\mod", "User")
[Environment]::SetEnvironmentVariable("GOCACHE",    $GoCache,         "User")

# --- prepend bin dirs to the user PATH (idempotent) ---------------------
$binDirs  = @("$GoRoot\bin", "$GoPath\bin")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$parts    = @()
if ($userPath) { $parts = $userPath.Split(";") | Where-Object { $_ -ne "" } }
$parts    = $parts | Where-Object { $binDirs -notcontains $_ }   # drop stale go entries
$newPath  = (($binDirs + $parts) -join ";")
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

# --- verify -------------------------------------------------------------
Write-Host ""
& $goExe version

# Warn if a different go.exe (e.g. an old MSI install) still shadows this one
# on the current combined PATH.
$onPath = (Get-Command go -ErrorAction SilentlyContinue).Source
if ($onPath -and $onPath -ne $goExe) {
  Write-Warning "Another go.exe is ahead on PATH: $onPath"
  Write-Warning "If Go was installed via the MSI, uninstall it so $goExe wins."
}

Write-Host ""
Write-Host "Done. Open a NEW terminal (or sign out/in) so the updated PATH and variables apply."
