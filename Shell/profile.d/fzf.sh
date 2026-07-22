# fzf shell integration: Ctrl-R history, Ctrl-T files, Alt-C cd-into-dir.
# Debian/Ubuntu fzf (0.44) predates `fzf --bash`, so keybindings are sourced
# from the packaged example file; tab-completion is auto-loaded by
# bash-completion from /usr/share/bash-completion/completions/fzf.
[ -r /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash

# Candidates via fd (Ubuntu ships the binary as fdfind): faster than find,
# respects .gitignore, shows hidden files except .git itself.
if command -v fdfind >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fdfind --type d --hidden --exclude .git'
fi
