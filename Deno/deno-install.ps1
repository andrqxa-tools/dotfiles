<#
.SYNOPSIS
  Install or update the Deno runtime on Windows (no vendor install script).

.DESCRIPTION
  Downloads the Deno .zip from dl.deno.land and extracts the single deno.exe to
  $DenoRoot\bin (default C:\Programms\deno — the folder used for installer-less
  programs). Sets persistent per-user environment variables (DENO_INSTALL_ROOT,
  DENO_DIR) and prepends the bin dirs to the user PATH, so the runtime is
  available in both new terminals and GUI apps. Re-running upgrades in place.

  Why Deno is here at all: yt-dlp needs a JavaScript runtime to decipher
  YouTube signatures, and deno is the only runtime it enables by default.
  Without it `yt-dlp -F` returns a truncated format list and warns
  "No supported JavaScript runtime could be found".

.PARAMETER Version
  Deno version to install, e.g. "2.9.4". Defaults to the latest release.

.PARAMETER Arch
  Target architecture: amd64 | arm64. Defaults to the current machine.

.PARAMETER DenoRoot
  Install location for the runtime. Default: C:\Programms\deno

.EXAMPLE
  .\deno-install.ps1                 # install/update to the latest release
  .\deno-install.ps1 -Version 2.9.4
#>

[CmdletBinding()]
param(
  [string]$Version,
  [ValidateSet("amd64", "arm64")]
  [string]$Arch,
  [string]$DenoRoot = "C:\Programms\deno"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- resolve version (default: latest) ----------------------------------
if (-not $Version) {
  Write-Host "Resolving latest Deno version..."
  $Version = (Invoke-RestMethod "https://dl.deno.land/release-latest.txt").Trim().Split("`n")[0]
}
$Version = "v" + ($Version -replace '^v', '')   # normalize "2.9.4" -> "v2.9.4"

# --- resolve architecture -----------------------------------------------
if (-not $Arch) {
  switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { $Arch = "amd64" }
    "ARM64" { $Arch = "arm64" }
    default { $Arch = "amd64" }
  }
}
$target = switch ($Arch) {
  "amd64" { "x86_64-pc-windows-msvc" }
  "arm64" { "aarch64-pc-windows-msvc" }
}

# --- paths --------------------------------------------------------------
$binDir     = Join-Path $DenoRoot "bin"
$denoExe    = Join-Path $binDir "deno.exe"
$installRoot = Join-Path $env:USERPROFILE ".deno"
$denoDir     = Join-Path $env:LOCALAPPDATA "deno"
$archive    = "deno-$target.zip"
$url        = "https://dl.deno.land/release/$Version/$archive"
$tmp        = Join-Path $env:TEMP $archive

# --- note a no-op reinstall ---------------------------------------------
if (Test-Path $denoExe) {
  $current = "v" + ((& $denoExe --version | Select-Object -First 1).Split(" ")[1])
  if ($current -eq $Version) {
    Write-Host "Deno $Version is already installed at $denoExe."
  }
}

# --- download -----------------------------------------------------------
Write-Host "Downloading $url..."
Invoke-WebRequest -Uri $url -OutFile $tmp

# --- install (single exe, extracted fresh) ------------------------------
Write-Host "Installing to $denoExe..."
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
Expand-Archive -Path $tmp -DestinationPath $binDir -Force
Remove-Item $tmp -Force

New-Item -ItemType Directory -Force -Path (Join-Path $installRoot "bin") | Out-Null
New-Item -ItemType Directory -Force -Path $denoDir | Out-Null

# --- persistent per-user environment (console + GUI) --------------------
Write-Host "Setting user environment variables..."
[Environment]::SetEnvironmentVariable("DENO_INSTALL_ROOT", $installRoot, "User")
[Environment]::SetEnvironmentVariable("DENO_DIR",          $denoDir,     "User")

# --- prepend bin dirs to the user PATH (idempotent) ---------------------
$binDirs  = @((Join-Path $installRoot "bin"), $binDir)
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$parts    = @()
if ($userPath) { $parts = $userPath.Split(";") | Where-Object { $_ -ne "" } }
$parts    = $parts | Where-Object { $binDirs -notcontains $_ }   # drop stale deno entries
$newPath  = (($binDirs + $parts) -join ";")
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

# --- verify -------------------------------------------------------------
Write-Host ""
& $denoExe --version

# Warn if a different deno.exe (e.g. from the vendor install script in
# %USERPROFILE%\.deno\bin) still shadows this one on the current PATH.
$onPath = (Get-Command deno -ErrorAction SilentlyContinue).Source
if ($onPath -and $onPath -ne $denoExe) {
  Write-Warning "Another deno.exe is ahead on PATH: $onPath"
}

Write-Host ""
Write-Host "Done. Open a NEW terminal (or sign out/in) so the updated PATH and variables apply."
