# wt - git worktree manager
# https://github.com/amiller68/worktree

# Ensure ~/.local/bin is in PATH
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

wt() {
    if [[ "$1" == "open" || "$1" == "-o" ]]; then
        eval "$(_wt "$@")"
    else
        _wt "$@"
    fi
}
