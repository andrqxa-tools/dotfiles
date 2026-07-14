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
| `Editors/NeoVim/NvChad/custom/` | NvChad `custom/` overrides (LSP, DAP, gopher, none-ls) |
| `Editors/Emacs/.emacs.d/` | `init.el` with `ide`/`lean` profiles + `lisp/go-config.el` |
| `Editors/helix/` | `config.toml` |
| `Editors/micro/` | `settings.json`, `bindings.json`, `colorschemes/` |
| `Editors/Geany/` | GTK2 rc |
| `Fonts/` | JetBrainsMono Nerd Font installers (linux / termux / windows) |
| `Go/` | Go toolchain installer + project scaffolding scripts |
| `Gitignore/go/` | Reusable Go `.gitignore` |
| `IDE/Netbeans/` | NetBeans `.conf` |

## Usage

Symlink or copy the configs to their real locations. Common targets:

```sh
# VS Code (Linux)
ln -sf "$PWD/Editors/VSCode/settings.json" ~/.config/Code/User/settings.json

# NvChad custom overrides
ln -sf "$PWD/Editors/NeoVim/NvChad/custom" ~/.config/nvim/lua/custom

# Emacs
ln -sf "$PWD/Editors/Emacs/.emacs.d/init.el" ~/.emacs.d/init.el

# Helix
ln -sf "$PWD/Editors/helix/config.toml" ~/.config/helix/config.toml

# micro
ln -sf "$PWD/Editors/micro/settings.json" ~/.config/micro/settings.json
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

### Go

```sh
./Go/go-install.sh 1.23.0                 # install Go, prompts for arch, wires GOROOT/GOPATH
./Go/create_go_project.sh myapp 8080      # scaffold a Go project (name + port)
```
On Windows: `Go\create-go-project.bat myapp`.

The scaffold reads the listen address from `HTTP_ADDR` (defaults to the port
passed at generation), so `make run` and the container start without arguments.
