@echo off
SETLOCAL

:: Check for project name argument
IF "%~1"=="" (
    echo Usage: %0 project_name
    GOTO :EOF
)

SET "PROJECT_NAME=%~1"

:: Create the directory structure
mkdir "%PROJECT_NAME%\cmd\%PROJECT_NAME%"
mkdir "%PROJECT_NAME%\pkg\api\v1"
mkdir "%PROJECT_NAME%\pkg\db"
mkdir "%PROJECT_NAME%\pkg\util"
mkdir "%PROJECT_NAME%\internal\auth"
mkdir "%PROJECT_NAME%\api"
mkdir "%PROJECT_NAME%\configs"
mkdir "%PROJECT_NAME%\scripts"
mkdir "%PROJECT_NAME%\test"

:: Initialize a new Go module in the project directory
cd "%PROJECT_NAME%"
go mod init "%PROJECT_NAME%"
echo. > go.sum

:: Create a simple main.go file
(
echo package main
echo import (
echo     "fmt"
echo     "log"
echo     "os"
echo     "%PROJECT_NAME%/configs"
echo )
echo.
echo func main() {
echo     if err := run(); err != nil {
echo         log.Fatal(err)
echo     }
echo.
echo     fmt.Println("Hello, %PROJECT_NAME%!")
echo.
echo     os.Exit(0)
echo }
echo.
echo func run() error {
echo     // read config from env
echo     _ = configs.Read()
echo.
echo     return nil
echo }
) > "cmd\%PROJECT_NAME%\main.go"

:: Create simple configs file
(
echo package configs
echo.
echo func Read() error {
echo    return nil
echo }
) > "configs\mainConfig.go"

:: Create simple .gitignore
(
echo # === Golang specific ===
echo # Compiled Object files, Static and Dynamic libs (Shared Objects)
echo *.o
echo *.a
echo *.so
echo *.exe
echo **/*.exe
echo *.exe~
echo *.dll
echo *.dylib
echo.
echo # Folders
echo _obj
echo _test
echo.
echo # Architecture specific extensions/prefixes
echo *.[568vq]
echo [568vq].out
echo *.cgo1.go
echo *.cgo2.c
echo _cgo_defun.c
echo _cgo_gotypes.go
echo _cgo_export.*
echo _testmain.go
echo *.prof
echo.
echo # Test binary, built with 'go test -c'
echo *.test
echo.
echo # Output of the go coverage tool, specifically when used with LiteIDE
echo *.out
echo.
echo # === Dependency directories (remove the comment below to include it) ===
echo # vendor/
echo.
echo # Go workspace file
echo go.work
echo.
echo # === VS Code specific ===
echo .vscode/*
echo !.vscode/settings.json
echo !.vscode/tasks.json
echo !.vscode/launch.json
echo !.vscode/extensions.json
echo *.code-workspace
echo.
echo # Local History for Visual Studio Code
echo .history/
echo.
echo # === IntelliJ Idea specific ===
echo .idea/
echo.
echo # Git merge
echo *.orig
echo.
echo # === Project specific ===
echo /tmp
echo.
echo # NAME_OF_APPLICATION (from Makefile) - for avoiding linux executing files
echo %PROJECT_NAME%
echo %PROJECT_NAME%.exe
echo.
echo # === Docker specific ===
echo **/db-data/*
) > ".gitignore"

:: Create simple Makefile
(
echo .PHONY: dc run test lint
echo.
echo dc:
echo 	docker-compose up --remove-orphans --build
echo.
echo run:
echo 	go build -o %PROJECT_NAME% ./cmd/%PROJECT_NAME% && HTTP_ADDR=:8080 ./%PROJECT_NAME%
echo.
echo test:
echo 	go test -race ./...
echo.
echo lint:
echo 	golangci-lint run
echo.
) > "Makefile"

:: Create simple Dockerfile
(
echo # Start from a small, secure base image
echo FROM golang:1.23-alpine AS builder
echo.
echo # Set the working directory inside the container
echo WORKDIR /app
echo.
echo # Copy the Go module files
echo COPY go.mod go.sum ./
echo.
echo # Download the Go module dependencies
echo RUN go mod download
echo.
echo # Copy the source code into the container
echo COPY . .
echo.
echo # Build the Go binary
echo RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app ./cmd/$PROJECT_NAME/main.go
echo.
echo # Create a minimal production image
echo FROM alpine:latest
echo.
echo # It's essential to regularly update the packages within the image to include security patches
echo RUN apk update && apk upgrade
echo.
echo # Reduce image size
echo RUN rm -rf /var/cache/apk/* && \
echo     rm -rf /tmp/*
echo.
echo # Avoid running code as a root user
echo RUN adduser -D appuser
echo USER appuser
echo.
echo # Set the working directory inside the container
echo WORKDIR /app
echo.
echo # Copy only the necessary files from the builder stage
echo COPY --from=builder /app/app .
echo.
echo # Set any environment variables required by the application
echo ENV HTTP_ADDR=:8080
echo.
echo # Expose the port that the application listens on
echo EXPOSE 8080
echo.
echo # Run the binary when the container starts
echo CMD ["./app"]
echo.
) > "Dockerfile"

:: Create simple docker-compose.yml
(
echo version: '3.8'
echo.
echo services:
echo   app:
echo     build:
echo       context: .
echo       dockerfile: Dockerfile
echo     ports:
echo       - 8080:8080
echo.
) > "docker-compose.yml"

:: Return to the initial directory
cd ..

echo Project structure for %PROJECT_NAME% has been successfully created.
ENDLOCAL
