# Deno runtime. Managed by dotfiles/Deno/deno-install.sh (symlinked into
# ~/.config/profile.d/). Primary reason it is installed here: yt-dlp needs a
# JavaScript runtime to decipher YouTube signatures (see dotfiles/YouTube),
# and deno is the only one yt-dlp enables by default.
#
# The runtime is a single static binary under the /opt/programming layout
# (shared with Go and Flutter); DENO_INSTALL_ROOT holds scripts installed later
# with `deno install -g`, and DENO_DIR is the module/npm cache.
export DENO_INSTALL_ROOT="$HOME/.deno"
export DENO_DIR="$HOME/.cache/deno"

# Prepend each dir once — idempotent across login/non-login/GUI/tmux sourcing.
for _d in \
  "$DENO_INSTALL_ROOT/bin" \
  "/opt/programming/deno/bin"
do
  case ":$PATH:" in
    *":$_d:"*) ;;
    *) PATH="$_d:$PATH" ;;
  esac
done
export PATH
unset _d
