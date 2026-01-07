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

# Get worktree names (handles nested paths like feature/auth/login)
_wt_get_worktrees() {
    local repo=$(git rev-parse --show-toplevel 2>/dev/null)
    [[ -d "$repo/.worktrees" ]] || return
    find "$repo/.worktrees" -name ".git" -type f 2>/dev/null | while read -r gitfile; do
        dirname "$gitfile" | sed "s|^$repo/.worktrees/||"
    done
}

# Completion
_wt_completion() {
    local -a commands
    commands=(
        'create:Create a new worktree'
        'list:List worktrees'
        'remove:Remove a worktree'
        'open:cd to worktree directory'
        'cleanup:Remove all worktrees'
        'update:Update wt to latest version'
        'version:Show version info'
    )

    if (( CURRENT == 2 )); then
        _describe -t commands 'wt commands' commands
        compadd -- '-o'
    elif (( CURRENT == 3 )); then
        case ${words[2]} in
            open|remove)
                local -a worktrees
                worktrees=($(_wt_get_worktrees))
                [[ ${#worktrees} -gt 0 ]] && _describe -t worktrees 'worktrees' worktrees
                ;;
            list)
                compadd -- '--all'
                ;;
            update)
                compadd -- '--force'
                ;;
            -o)
                compadd -- 'create'
                ;;
        esac
    fi
}
compdef _wt_completion wt
