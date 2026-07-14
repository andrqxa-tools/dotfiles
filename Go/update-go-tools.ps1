<#
.SYNOPSIS
  Update installed Go tools (gopls, dlv, staticcheck, ...) to @latest.

.DESCRIPTION
  Rebuilds every tool in %GOPATH%\bin with the current Go toolchain by
  reinstalling it at @latest. Run after a major Go upgrade so tools (gopls
  especially) stay in step. The list is auto-discovered from each binary's
  embedded module info (go version -m) — nothing is hardcoded.

  golangci-lint is skipped on purpose: it runs from a pinned Docker image in
  generated projects, so bump that version by hand in the Taskfile instead.
#>

$ErrorActionPreference = "Stop"

$binDir = Join-Path (& go env GOPATH) "bin"
if (-not (Test-Path $binDir)) { Write-Host "No $binDir - nothing to update."; return }

Write-Host "Updating Go tools in $binDir (rebuilding with $(& go env GOVERSION))..."
Write-Host ""

$updated = 0; $skipped = 0; $failed = 0

Get-ChildItem -File -Path $binDir | ForEach-Object {
  $name = $_.BaseName   # strips the .exe suffix on Windows

  if ($name -eq "golangci-lint") {
    Write-Host "skip    $name (Dockerized - pin the version by hand)"
    $skipped++; return
  }

  $info = & go version -m $_.FullName 2>$null
  $match = $info | Select-String '^\s*path\s+(\S+)' | Select-Object -First 1
  if (-not $match) {
    Write-Host "skip    $name (no module info)"
    $skipped++; return
  }
  $pkg = $match.Matches.Groups[1].Value.Trim()

  Write-Host ("update  {0,-20} <- {1}@latest" -f $name, $pkg)
  & go install "$pkg@latest"
  if ($LASTEXITCODE -eq 0) { $updated++ } else { Write-Host "FAIL    $name"; $failed++ }
}

Write-Host ""
Write-Host "Done: $updated updated, $skipped skipped, $failed failed."
