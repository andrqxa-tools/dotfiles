#!/bin/bash

# Check for project name argument
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <project_name> <http_port>"
    exit 1
fi

PROJECT_NAME=$1
HTTP_PORT=$2

# Create the directory structure
mkdir -p "$PROJECT_NAME/cmd/$PROJECT_NAME"
mkdir -p "$PROJECT_NAME/pkg/api/v1"
mkdir -p "$PROJECT_NAME/pkg/db"
mkdir -p "$PROJECT_NAME/pkg/util"
mkdir -p "$PROJECT_NAME/internal/auth"
mkdir -p "$PROJECT_NAME/api"
mkdir -p "$PROJECT_NAME/configs"
mkdir -p "$PROJECT_NAME/scripts"
mkdir -p "$PROJECT_NAME/test"

# Initialize a new Go module in the project directory
cd "$PROJECT_NAME"
go mod init "$PROJECT_NAME"

# Create a simple main.go file
cat <<EOF > "cmd/$PROJECT_NAME/main.go"
package main

import (
    "fmt"
    "log"
    "os"

    "$PROJECT_NAME/configs"
)

func main() {
    // Port is read from the environment so both \`make run\` and the
    // container (CMD ["./app"]) start without positional arguments.
    addr := os.Getenv("HTTP_ADDR")
    if addr == "" {
        addr = ":$HTTP_PORT"
    }

    if err := run(); err != nil {
        log.Fatal(err)
    }

    fmt.Println("Hello, $PROJECT_NAME! Listening on", addr)

    os.Exit(0)
}

func run() error {
    // read config from env
    _ = configs.Read()

    return nil
}
EOF

cat <<EOF > "configs/mainConfig.go"
package configs

func Read() error {
    return nil
}
EOF

# Create simple .gitignore
cat <<EOF > ".gitignore"
# === Golang specific ===
# Compiled Object files, Static and Dynamic libs (Shared Objects)
*.o
*.a
*.so
*.exe
**/*.exe
*.exe~
*.dll
*.dylib

# Folders
_obj
_test

# Architecture specific extensions/prefixes
*.[568vq]
[568vq].out
*.cgo1.go
*.cgo2.c
_cgo_defun.c
_cgo_gotypes.go
_cgo_export.*
_testmain.go
*.prof

# Test binary, built with 'go test -c'
*.test

# Output of the go coverage tool, specifically when used with LiteIDE
*.out

# === Dependency directories (remove the comment below to include it) ===
# vendor/

# Go workspace file
go.work

# === VS Code specific ===
.vscode/*
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
*.code-workspace

# Local History for Visual Studio Code
.history/

# === IntelliJ Idea specific ===
.idea/

# Git merge
*.orig

# === Project specific ===
/tmp

# NAME_OF_APPLICATION (from Makefile) - for avoiding linux executing files
$PROJECT_NAME
${PROJECT_NAME}.exe

# === Docker specific ===
**/db-data/*
EOF

# Create simple Makefile
cat <<EOF > "Makefile"
.PHONY: dc run test lint

dc:
	docker-compose up --remove-orphans --build

run:
	go build -o $PROJECT_NAME ./cmd/$PROJECT_NAME && HTTP_ADDR=:$HTTP_PORT ./$PROJECT_NAME

test:
	go test -race ./...

lint:
	golangci-lint run
EOF

# Create simple Dockerfile
cat <<EOF > "Dockerfile"
# Start from a small, secure base image
FROM golang:1.23-alpine AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy the Go module files
COPY go.mod go.sum ./

# Download the Go module dependencies
RUN go mod download

# Copy the source code into the container
COPY . .

# Build the Go binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app ./cmd/$PROJECT_NAME/main.go

# Create a minimal production image
FROM alpine:latest

# It's essential to regularly update the packages within the image to include security patches
RUN apk update && apk upgrade

# Reduce image size
RUN rm -rf /var/cache/apk/* && \
    rm -rf /tmp/*

# Avoid running code as a root user
RUN adduser -D appuser
USER appuser

# Set the working directory inside the container
WORKDIR /app

# Copy only the necessary files from the builder stage
COPY --from=builder /app/app .

# Set any environment variables required by the application
ENV HTTP_ADDR=:8080

# Expose the port that the application listens on
EXPOSE 8080

# Run the binary when the container starts
CMD ["./app"]
EOF

# Create simple docker-compose.yml
cat <<EOF > "docker-compose.yml"
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - 8080:8080
EOF

cd ..

echo "Project structure for $PROJECT_NAME has been successfully created."

