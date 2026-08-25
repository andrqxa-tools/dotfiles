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
| `Deno/` | Deno runtime installer (the JS runtime `yt-dlp` needs) |
| `Flutter/` | Android SDK + JDK17 + FVM/Flutter installer for the mabrook projects (SDK on `/data`) |
| `Gitignore/go/` | Reusable Go `.gitignore` |
| `IDE/IntelliJ-IDEA/` | `idea64.vmoptions` — JVM tuning (Go profile, 4 GB heap) |
| `A2/` | Active Oberon SDK (minia2) installers — Linux/Termux wrapper and a Windows one |
| `Shell/bashrc` | minimal fallback bash config — zsh is the daily driver |
| `Shell/zsh/` | zsh setup — oh-my-zsh + powerlevel10k, aliases, functions, key bindings; `install.sh` clones the third-party parts |
| `Termux/` | Termux app settings — `Ctrl-n` opens and focuses a new terminal session |
| `Tmux/` | `tmux.conf` — shared by tmux (Linux/macOS) and psmux (Windows) |
| `Radio/` | Console internet radio for mpv with a genre-based station catalog |
| `YouTube/` | Console YouTube for mpv + yt-dlp — search, audio, terminal video, bookmarks |

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
ln -sfn "$PWD/Editors/NeoVim/NvChad/after"        ~/.config/nvim/after
ln -sfn "$PWD/Editors/NeoVim/NvChad/ftdetect"     ~/.config/nvim/ftdetect
ln -sfn "$PWD/Editors/NeoVim/NvChad/syntax"       ~/.config/nvim/syntax

# Emacs
ln -sf "$PWD/Editors/Emacs/.emacs.d/init.el" ~/.emacs.d/init.el

# Helix
ln -sf "$PWD/Editors/helix/config.toml" ~/.config/helix/config.toml

# micro
ln -sf "$PWD/Editors/micro/settings.json" ~/.config/micro/settings.json

# tmux (Linux/macOS) — psmux on Windows reads the same file as ~/.tmux.conf
ln -sf "$PWD/Tmux/tmux.conf" ~/.config/tmux/tmux.conf

# Termux: Ctrl-n creates and focuses a new app session; the current Vim stays put
mkdir -p ~/.termux
ln -sf "$PWD/Termux/termux.properties" ~/.termux/termux.properties
termux-reload-settings

# IntelliJ IDEA VM options (OS-independent, version-independent)
export IDEA_VM_OPTIONS="$PWD/IDE/IntelliJ-IDEA/idea64.vmoptions"   # add to your shell rc

# Flutter/Android toolchain env (mabrook) — sourced by the profile.d loader
ln -sf "$PWD/Shell/profile.d/flutter.sh" ~/.config/profile.d/flutter.sh
# then run the installer for the SDK/JDK/FVM (see Flutter/README.md):
#   ./Flutter/setup-android-env.sh --emulator
```

```sh
# zsh (Linux/Termux) — clones oh-my-zsh, powerlevel10k and the plugins, links ~/.zshrc
./Shell/zsh/install.sh
chsh -s zsh            # Termux; elsewhere: chsh -s "$(command -v zsh)"

# Active Oberon SDK env (A2_OB / A2_SYMS). Install the SDK itself with:
#   curl -fsSL https://raw.githubusercontent.com/active-oberon/minia2/main/sdk/install.sh | sh
ln -sf "$PWD/Shell/profile.d/a2.sh" ~/.config/profile.d/a2.sh
```

Three levels, no per-platform copies of the config: shared shell setup lives in
`Shell/zsh/` (one file per concern, platform differences behind `$TERMUX_VERSION`
and `command -v` guards); per-topic env goes to `Shell/profile.d/*.sh`, symlinked
into `~/.config/profile.d/` only on the machines that need it and loaded by both
bash and zsh; whatever exists on a single box goes to `~/.config/shell/local.sh`,
sourced last and ignored by this repo.

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

### A2 (Active Oberon SDK)

```sh
./A2/install-unix.sh          # Linux and Termux; flags pass through to minia2 sdk/install.sh
```
```powershell
.\A2\install-windows.ps1     # Windows: ob.exe SDK, per-user PATH and A2_* variables
```

Unpacks the release tarball into `~/.local/share/a2sdk` (`--dir` overrides), links
`Shell/profile.d/a2.sh` so `A2_OB` and `A2_SYMS` are set in every new shell, and asks
for no privileges. `--uninstall` removes what it installed.

### Radio (mpv)

Install `mpv`, `fzf` and the console radio command on Linux:

```sh
./Radio/install-linux.sh
radio
```

The installer supports apt, dnf, pacman and zypper. It deploys only user files
under `~/.local/bin` and `~/.config/radio`; the global mpv config is untouched.

### YouTube (mpv + yt-dlp)

Install `mpv`, `fzf`, a fresh `yt-dlp` (via pipx) and the console `yt` command:

```sh
./YouTube/install-linux.sh
yt queen bohemian rhapsody     # search, pick in fzf, listen
yt v <query|URL>               # video inside the terminal (kitty/sixel/tct)
yt fav                         # play a bookmarked channel or playlist
```

While playing: `←`/`→` seek ±5 s, `Shift` ±30 s, `↑`/`↓` ±60 s, `0`…`9` jump to
0…90 % of the length, `t` types an exact position (`mm:ss`, `42%`, `+30`).

Deploys only user files under `~/.local/bin` and `~/.config/yt`. See
[`YouTube/README.md`](YouTube/README.md) for bookmarks, terminal-video backends
and troubleshooting. For the full YouTube format list, add the Deno runtime
below — `yt-dlp` needs a JS engine to decipher signatures.

### Deno

Only reason it is here: `yt-dlp` needs a JavaScript runtime, and `deno` is the
only one it enables by default. Without it YouTube exposes a truncated format
list and `yt-dlp` warns `No supported JavaScript runtime could be found`.

```sh
./Deno/deno-install.sh                     # latest, auto arch
./Deno/deno-install.sh 2.9.4 amd64         # or pin version + arch
./Deno/deno-install.sh --force             # re-download the same version
```
```powershell
powershell -ExecutionPolicy Bypass -File Deno\deno-install.ps1
```

- Linux: single static binary at `/opt/programming/deno/bin/deno`; env comes
  from `Shell/profile.d/deno.sh`, symlinked into `~/.config/profile.d/`.
- Windows: `C:\Programms\deno\bin\deno.exe` + persistent per-user env/PATH.

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
