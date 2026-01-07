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
_wt_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD-1]}

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "create list remove open cleanup update version -o" -- "$cur"))
    elif [[ $COMP_CWORD -eq 2 ]]; then
        case $prev in
            open|remove)
                local repo=$(git rev-parse --show-toplevel 2>/dev/null)
                if [[ -d "$repo/.worktrees" ]]; then
                    COMPREPLY=($(compgen -W "$(ls "$repo/.worktrees" 2>/dev/null)" -- "$cur"))
                fi
                ;;
            update)
                COMPREPLY=($(compgen -W "--force" -- "$cur"))
                ;;
            -o)
                COMPREPLY=($(compgen -W "create" -- "$cur"))
                ;;
        esac
    fi
}
complete -F _wt_complete wt
