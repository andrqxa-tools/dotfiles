# dotfiles

Personal configuration files, install scripts and project scaffolding —
primarily for a Go-centric workflow across Linux, Termux and Windows.

## Getting started

```sh
git clone git@github.com:andrqxa-tools/dotfiles.git
cd dotfiles
```

Then symlink the pieces you need (see [Usage](#usage)).

## Layout

| Path | What's inside |
|------|---------------|
| `Editors/VSCode/` | `settings.json` (extensions are handled by VS Code Settings Sync) |
| `Editors/NeoVim/NvChad/` | NvChad 2.5 config — Go (gopls/conform/dap/gopher) + tmux/AI tweaks |
| `Editors/Emacs/.emacs.d/` | `init.el` with `ide`/`lean` profiles + `lisp/go-config.el` |
| `Editors/helix/` | `config.toml` |
| `Editors/micro/` | `settings.json`, `bindings.json`, `colorschemes/` |
| `Editors/Geany/` | GTK2 rc |
| `Fonts/` | JetBrainsMono Nerd Font installers (linux / termux / windows) |
| `Go/` | Go toolchain installer + project scaffolding scripts |
| `Gitignore/go/` | Reusable Go `.gitignore` |
| `IDE/IntelliJ-IDEA/` | `idea64.vmoptions` — JVM tuning (Go profile, 4 GB heap) |
| `Tmux/` | `tmux.conf` — shared by tmux (Linux/macOS) and psmux (Windows) |
| `Radio/` | Console internet radio for mpv with a genre-based station catalog |

## Usage

Symlink or copy the configs to their real locations. Common targets:

```sh
# VS Code (Linux)
ln -sf "$PWD/Editors/VSCode/settings.json" ~/.config/Code/User/settings.json

# NvChad 2.5: bootstrap the starter first, then point config at this repo
#   git clone https://github.com/NvChad/starter ~/.config/nvim && rm -rf ~/.config/nvim/.git
ln -sfn "$PWD/Editors/NeoVim/NvChad/lua"          ~/.config/nvim/lua
ln -sf  "$PWD/Editors/NeoVim/NvChad/init.lua"     ~/.config/nvim/init.lua
ln -sf  "$PWD/Editors/NeoVim/NvChad/.stylua.toml" ~/.config/nvim/.stylua.toml

# Emacs
ln -sf "$PWD/Editors/Emacs/.emacs.d/init.el" ~/.emacs.d/init.el

# Helix
ln -sf "$PWD/Editors/helix/config.toml" ~/.config/helix/config.toml

# micro
ln -sf "$PWD/Editors/micro/settings.json" ~/.config/micro/settings.json

# tmux (Linux/macOS) — psmux on Windows reads the same file as ~/.tmux.conf
ln -sf "$PWD/Tmux/tmux.conf" ~/.config/tmux/tmux.conf

# IntelliJ IDEA VM options (OS-independent, version-independent)
export IDEA_VM_OPTIONS="$PWD/IDE/IntelliJ-IDEA/idea64.vmoptions"   # add to your shell rc
```

VS Code extensions are managed by built-in Settings Sync, not tracked here.

## Scripts

### Fonts (JetBrainsMono Nerd Font)

```sh
./Fonts/install-linux.sh      # requires curl, jq, fontconfig
./Fonts/install-termux.sh     # Termux
```
```powershell
.\Fonts\install-windows.ps1   # Windows (per-user font dir)
```

### Radio (mpv)

Install `mpv`, `fzf` and the console radio command on Linux:

```sh
./Radio/install-linux.sh
radio
```

The installer supports apt, dnf, pacman and zypper. It deploys only user files
under `~/.local/bin` and `~/.config/radio`; the global mpv config is untouched.

### Go

Install / update the toolchain:

```sh
./Go/go-install.sh                         # Linux: install/update to latest (auto arch)
./Go/go-install.sh 1.26.2 amd64            # or pin version + arch
```
```powershell
# Windows: install/update to the latest release (auto-detects arch)
powershell -ExecutionPolicy Bypass -File Go\go-install.ps1
powershell -ExecutionPolicy Bypass -File Go\go-install.ps1 -Version 1.26.2   # pin a version
```

- Linux: GOROOT `/opt/programming/go`, GOPATH `$HOME/go`; env written to
  `~/.config/profile.d/go.sh` (+ fish `conf.d/go.fish`), wired for bash/zsh/fish.
- Windows: GOROOT `C:\Programms\go`, GOPATH `%USERPROFILE%\go`; persistent
  per-user env vars + PATH (visible to console and GUI). Re-run to upgrade.

Installing Go does **not** update the tools in `$GOPATH/bin` (gopls, dlv,
staticcheck, …). After a major Go upgrade, rebuild them at latest:

```sh
./Go/update-go-tools.sh                    # Linux
```
```powershell
powershell -ExecutionPolicy Bypass -File Go\update-go-tools.ps1   # Windows
```

The list is auto-discovered from each binary's module info; `golangci-lint`
is skipped (it runs from a pinned Docker image — bump that by hand).

Scaffold a new Go project:

```sh
./Go/create_go_project.sh myapp clean 8080   # name, type, port (type/port prompted if omitted)
```
```powershell
powershell -ExecutionPolicy Bypass -File Go\create_go_project.ps1 myapp clean 8080
```

- **Type** picks the layout: `web` (monolith), `microservice` (API/transport),
  `clean` (domain/usecase/adapter/infra), or `minimal`. Empty dirs get a
  `.gitkeep` so they survive git.
- Generates a working `net/http` server (`/healthz` + graceful shutdown),
  reading the address from `HTTP_ADDR`, so `task run` and the container start
  without arguments.
- **Task** (Taskfile.yml) replaces Make — `task run|build|test|lint|tidy|dc`;
  installed automatically via `go install` if missing.
- **`task lint`** runs a pinned `golangci-lint` Docker image, so every machine
  lints with the exact same version; shared config in `.golangci.yml`.
- Dockerfile (alpine, non-root) + Compose with a `/healthz` healthcheck.
