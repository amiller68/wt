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

# Completion
_wt_completion() {
    local -a commands
    commands=(
        'create:Create a new worktree'
        'list:List all worktrees'
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
                local repo=$(git rev-parse --show-toplevel 2>/dev/null)
                if [[ -d "$repo/.worktrees" ]]; then
                    local -a worktrees
                    worktrees=($(ls "$repo/.worktrees" 2>/dev/null))
                    _describe -t worktrees 'worktrees' worktrees
                fi
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
