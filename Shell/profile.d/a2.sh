# Active Oberon SDK (minia2). Install, on Linux or Termux alike:
#   curl -fsSL https://raw.githubusercontent.com/active-oberon/minia2/main/sdk/install.sh | sh
# Editors and the language server read A2_OB, A2_SYMS and A2_STDLIB_SRC — see
# minia2 docs/IDE.md.

for _a2 in "$A2_HOME" "$HOME/.local/share/a2sdk" "$HOME/Projects/a2-a64" /data/Projects/A2/minia2/target/bundle; do
    if [ -n "$_a2" ] && [ -x "$_a2/ob" ]; then A2_HOME="$_a2"; break; fi
done
unset _a2

if [ -n "$A2_HOME" ] && [ -x "$A2_HOME/ob" ]; then
    export A2_HOME
    export A2_OB="$A2_HOME/ob"
    export A2_SYMS="$A2_HOME/lib"

    # A source checkout may itself be the SDK home. Release SDKs do not ship the full source
    # tree, so on developer machines find the checkout beside them. Keep an explicit, existing
    # A2_STDLIB_SRC untouched.
    if [ -z "${A2_STDLIB_SRC:-}" ] || [ ! -d "$A2_STDLIB_SRC" ]; then
        for _a2_source in \
            "$A2_HOME/source" \
            "$HOME/projects/A2/minia2/source" \
            "$HOME/Projects/A2/minia2/source" \
            "$HOME/projects/A2/a2oberon/source" \
            "$HOME/Projects/A2/a2oberon/source" \
            /data/Projects/A2/minia2/source
        do
            if [ -d "$_a2_source" ]; then
                A2_STDLIB_SRC="$_a2_source"
                export A2_STDLIB_SRC
                break
            fi
        done
        unset _a2_source
    fi

    case ":$PATH:" in
    *":$A2_HOME:"*) ;;
    *) PATH="$A2_HOME:$PATH"; export PATH ;;
    esac
fi
