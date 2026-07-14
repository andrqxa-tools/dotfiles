#!/usr/bin/env bash
set -euo pipefail

# Scaffold a Go project.
#   Usage: create_go_project.sh [name] [type] [port]
#     type : web | microservice | clean | minimal   (prompted if omitted)
#     port : listen port, default 8080
#
# Generates a working net/http server (with /healthz + graceful shutdown),
# a Taskfile (Make replacement), a Dockerfile (alpine) + compose, and a
# type-specific directory layout. Empty dirs get a .gitkeep so they survive
# git. Linting runs through a pinned golangci-lint Docker image so everyone
# uses the exact same version.

GOLANGCI_IMAGE="golangci/golangci-lint:v2.12.2"

NAME="${1:-}"
TYPE="${2:-}"
PORT="${3:-}"

# --- gather inputs ------------------------------------------------------
if [ -z "$NAME" ]; then read -rp "Project name: " NAME; fi
[ -n "$NAME" ] || { echo "Project name is required." >&2; exit 1; }

if [ -z "$TYPE" ]; then
  echo "Project type:"
  select t in web microservice clean minimal; do
    [ -n "${t:-}" ] && TYPE="$t" && break
    echo "Invalid choice, try again."
  done
fi

PORT="${PORT:-8080}"

# Go minor version for the builder image, matched to the local toolchain.
GO_MM="$(go env GOVERSION 2>/dev/null | sed -E 's/^go([0-9]+\.[0-9]+).*/\1/')"
[ -n "$GO_MM" ] || GO_MM="1.26"

# --- directory layout ---------------------------------------------------
keep() { mkdir -p "$1"; touch "$1/.gitkeep"; }

mkdir -p "$NAME/cmd/$NAME" "$NAME/configs"

case "$TYPE" in
  web)
    keep "$NAME/internal/handler"
    keep "$NAME/internal/service"
    keep "$NAME/internal/repository"
    keep "$NAME/internal/model"
    keep "$NAME/web/templates"
    keep "$NAME/web/static"
    keep "$NAME/migrations"
    ;;
  microservice)
    keep "$NAME/internal/handler"
    keep "$NAME/internal/service"
    keep "$NAME/internal/repository"
    keep "$NAME/internal/model"
    keep "$NAME/api/proto"
    keep "$NAME/deploy"
    keep "$NAME/migrations"
    ;;
  clean)
    keep "$NAME/internal/domain"
    keep "$NAME/internal/usecase"
    keep "$NAME/internal/adapter/handler"
    keep "$NAME/internal/adapter/repository"
    keep "$NAME/internal/infrastructure"
    ;;
  minimal)
    keep "$NAME/internal"
    ;;
  *)
    echo "Unknown type: $TYPE (want web|microservice|clean|minimal)" >&2
    exit 1
    ;;
esac

cd "$NAME"
go mod init "$NAME"

# --- cmd/<name>/main.go -------------------------------------------------
cat > "cmd/$NAME/main.go" <<EOF
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

	"$NAME/configs"
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
EOF

# --- configs/config.go --------------------------------------------------
cat > "configs/config.go" <<EOF
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
		addr = ":$PORT"
	}
	return Config{Addr: addr}
}
EOF

# --- .gitignore ---------------------------------------------------------
cat > ".gitignore" <<EOF
# Binaries
/$NAME
/$NAME.exe
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
EOF

# --- Taskfile.yml (Make replacement) ------------------------------------
cat > "Taskfile.yml" <<EOF
version: "3"

vars:
  APP: $NAME
  PORT: "$PORT"
  GOLANGCI: $GOLANGCI_IMAGE

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
EOF

# --- .golangci.yml (shared config, golangci-lint v2 schema) -------------
cat > ".golangci.yml" <<'EOF'
version: "2"

run:
  timeout: 5m

linters:
  default: standard
  # Add extra linters here so everyone shares them, e.g.:
  # enable:
  #   - revive
  #   - misspell
EOF

# --- Dockerfile (alpine) ------------------------------------------------
cat > "Dockerfile" <<EOF
# syntax=docker/dockerfile:1
FROM golang:$GO_MM-alpine AS builder
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/$NAME

FROM alpine:latest
RUN apk add --no-cache ca-certificates \\
    && adduser -D -u 10001 app
USER app
WORKDIR /app
COPY --from=builder /out/app .
ENV HTTP_ADDR=:$PORT
EXPOSE $PORT
CMD ["./app"]
EOF

# --- docker-compose.yml -------------------------------------------------
cat > "docker-compose.yml" <<EOF
services:
  app:
    build:
      context: .
    ports:
      - "$PORT:$PORT"
    environment:
      HTTP_ADDR: ":$PORT"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:$PORT/healthz"]
      interval: 10s
      timeout: 3s
      retries: 3
EOF

# --- tidy + format ------------------------------------------------------
go mod tidy
gofmt -w .

# --- ensure Task is available -------------------------------------------
if ! command -v task >/dev/null 2>&1; then
  echo "Task runner not found — installing via 'go install'..."
  go install github.com/go-task/task/v3/cmd/task@latest
  echo "Installed to \$(go env GOPATH)/bin (make sure it is on PATH)."
fi

cd ..

echo
echo "Project '$NAME' ($TYPE, port $PORT) created."
echo "Next:  cd $NAME && task run     # then curl http://localhost:$PORT/healthz"
echo "Lint:  task lint                # runs $GOLANGCI_IMAGE in Docker"
