<#
.SYNOPSIS
  Scaffold a Go project (Windows counterpart of create_go_project.sh).

.DESCRIPTION
  Generates a working net/http server (/healthz + graceful shutdown), a
  Taskfile (Make replacement), a Dockerfile (alpine) + compose, and a
  type-specific directory layout. Empty dirs get a .gitkeep so they survive
  git. Linting runs through a pinned golangci-lint Docker image so everyone
  uses the exact same version.

.PARAMETER Name  Project (module) name.
.PARAMETER Type  web | microservice | clean | minimal   (prompted if omitted)
.PARAMETER Port  Listen port (default 8080).

.EXAMPLE
  .\create_go_project.ps1 svcdemo clean 9090
#>

[CmdletBinding()]
param(
  [string]$Name,
  [ValidateSet("web", "microservice", "clean", "minimal")]
  [string]$Type,
  [int]$Port = 8080
)

$ErrorActionPreference = "Stop"
$GolangciImage = "golangci/golangci-lint:v2.12.2"

# --- gather inputs ------------------------------------------------------
if (-not $Name) { $Name = Read-Host "Project name" }
if (-not $Name) { throw "Project name is required." }

if (-not $Type) {
  $choices = @("web", "microservice", "clean", "minimal")
  for ($i = 0; $i -lt $choices.Count; $i++) { Write-Host "$($i + 1)) $($choices[$i])" }
  do { $sel = Read-Host "Project type [1-4]" } while ($sel -notmatch '^[1-4]$')
  $Type = $choices[[int]$sel - 1]
}

# Go minor version for the builder image, matched to the local toolchain.
$GoMM = "1.26"
try {
  $gv = (& go env GOVERSION) -replace '^go', ''
  if ($gv -match '^(\d+\.\d+)') { $GoMM = $Matches[1] }
}
catch { }

# --- helpers ------------------------------------------------------------
function Keep([string]$p) {
  New-Item -ItemType Directory -Force -Path $p | Out-Null
  New-Item -ItemType File -Force -Path (Join-Path $p ".gitkeep") | Out-Null
}

function Write-File([string]$rel, [string]$content) {
  $full = Join-Path (Get-Location).Path $rel
  New-Item -ItemType Directory -Force -Path (Split-Path $full) | Out-Null
  $content = ($content -replace "`r`n", "`n")
  [IO.File]::WriteAllText($full, $content, (New-Object System.Text.UTF8Encoding($false)))
}

# --- directory layout ---------------------------------------------------
New-Item -ItemType Directory -Force -Path "$Name/cmd/$Name", "$Name/configs" | Out-Null

switch ($Type) {
  "web" {
    Keep "$Name/internal/handler"; Keep "$Name/internal/service"
    Keep "$Name/internal/repository"; Keep "$Name/internal/model"
    Keep "$Name/web/templates"; Keep "$Name/web/static"; Keep "$Name/migrations"
  }
  "microservice" {
    Keep "$Name/internal/handler"; Keep "$Name/internal/service"
    Keep "$Name/internal/repository"; Keep "$Name/internal/model"
    Keep "$Name/api/proto"; Keep "$Name/deploy"; Keep "$Name/migrations"
  }
  "clean" {
    Keep "$Name/internal/domain"; Keep "$Name/internal/usecase"
    Keep "$Name/internal/adapter/handler"; Keep "$Name/internal/adapter/repository"
    Keep "$Name/internal/infrastructure"
  }
  "minimal" { Keep "$Name/internal" }
}

Push-Location $Name
try {
  & go mod init $Name

  # --- cmd/<name>/main.go ---
  Write-File "cmd/$Name/main.go" @"
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"$Name/configs"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	cfg := configs.Load()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	srv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		log.Printf("listening on %s", cfg.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
	}()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		log.Println("shutting down...")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	}
}
"@

  # --- configs/config.go ---
  Write-File "configs/config.go" @"
package configs

import "os"

// Config holds runtime configuration read from the environment.
type Config struct {
	Addr string
}

// Load reads configuration from the environment, applying defaults.
func Load() Config {
	addr := os.Getenv("HTTP_ADDR")
	if addr == "" {
		addr = ":$Port"
	}
	return Config{Addr: addr}
}
"@

  # --- .gitignore ---
  Write-File ".gitignore" @"
# Binaries
/$Name
/$Name.exe
*.exe
*.test
*.out
*.prof

# Go
go.work
go.work.sum
vendor/

# Env / secrets
.env
*.local

# Editors
.vscode/*
!.vscode/settings.json
!.vscode/launch.json
!.vscode/tasks.json
!.vscode/extensions.json
.idea/
*.orig

# Docker / runtime
**/db-data/*
/tmp
"@

  # --- Taskfile.yml ---
  Write-File "Taskfile.yml" @"
version: "3"

vars:
  APP: $Name
  PORT: "$Port"
  GOLANGCI: $GolangciImage

tasks:
  run:
    desc: Build and run locally
    cmds:
      - go build -o {{.APP}} ./cmd/{{.APP}}
      - HTTP_ADDR=:{{.PORT}} ./{{.APP}}

  build:
    desc: Build the binary
    cmds:
      - go build -o {{.APP}} ./cmd/{{.APP}}

  test:
    desc: Run tests with the race detector
    cmds:
      - go test -race ./...

  tidy:
    desc: Tidy go.mod / go.sum
    cmds:
      - go mod tidy

  lint:
    desc: Lint via a pinned golangci-lint Docker image (same version for everyone)
    cmds:
      - docker run --rm -v "{{.TASKFILE_DIR}}:/app" -v golangci-lint-cache:/root/.cache -w /app {{.GOLANGCI}} golangci-lint run

  dc:
    desc: Build and start the stack with Docker Compose
    cmds:
      - docker compose up --build --remove-orphans
"@

  # --- .golangci.yml (golangci-lint v2 schema) ---
  Write-File ".golangci.yml" @'
version: "2"

run:
  timeout: 5m

linters:
  default: standard
  # Add extra linters here so everyone shares them, e.g.:
  # enable:
  #   - revive
  #   - misspell
'@

  # --- Dockerfile (alpine) ---
  Write-File "Dockerfile" @"
# syntax=docker/dockerfile:1
FROM golang:$GoMM-alpine AS builder
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/$Name

FROM alpine:latest
RUN apk add --no-cache ca-certificates \
    && adduser -D -u 10001 app
USER app
WORKDIR /app
COPY --from=builder /out/app .
ENV HTTP_ADDR=:$Port
EXPOSE $Port
CMD ["./app"]
"@

  # --- docker-compose.yml ---
  Write-File "docker-compose.yml" @"
services:
  app:
    build:
      context: .
    ports:
      - "${Port}:${Port}"
    environment:
      HTTP_ADDR: ":$Port"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:$Port/healthz"]
      interval: 10s
      timeout: 3s
      retries: 3
"@

  # --- tidy + format ---
  & go mod tidy
  & gofmt -w .

  # --- ensure Task is available ---
  if (-not (Get-Command task -ErrorAction SilentlyContinue)) {
    Write-Host "Task runner not found - installing via 'go install'..."
    & go install github.com/go-task/task/v3/cmd/task@latest
    Write-Host "Installed to $(& go env GOPATH)\bin (make sure it is on PATH)."
  }
}
finally {
  Pop-Location
}

Write-Host ""
Write-Host "Project '$Name' ($Type, port $Port) created."
Write-Host "Next:  cd $Name; task run     # then curl http://localhost:$Port/healthz"
Write-Host "Lint:  task lint              # runs $GolangciImage in Docker"
