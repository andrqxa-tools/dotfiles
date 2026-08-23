# Active Oberon SDK (minia2). Install, on Linux or Termux alike:
#   curl -fsSL https://raw.githubusercontent.com/active-oberon/minia2/main/sdk/install.sh | sh
# Editors and the language server read A2_OB and A2_SYMS — see minia2 docs/IDE.md.

for _a2 in "$A2_HOME" "$HOME/.local/share/a2sdk" "$HOME/Projects/a2-a64" /data/Projects/A2/minia2; do
    if [ -n "$_a2" ] && [ -x "$_a2/ob" ]; then A2_HOME="$_a2"; break; fi
done
unset _a2

if [ -n "$A2_HOME" ] && [ -x "$A2_HOME/ob" ]; then
    export A2_HOME
    export A2_OB="$A2_HOME/ob"
    export A2_SYMS="$A2_HOME/lib"
    case ":$PATH:" in
    *":$A2_HOME:"*) ;;
    *) PATH="$A2_HOME:$PATH"; export PATH ;;
    esac
fi
