# wt - git worktree manager
# https://github.com/amiller68/worktree

# Ensure ~/.local/bin is in PATH
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

wt() {
    # Eval output if command might cd (open, cleanup, or create with -o flag)
    if [[ "$1" == "open" || "$1" == "cleanup" || "$1" == "-o" || "$2" == "-o" || "$*" == *"-o"* ]]; then
        eval "$(_wt "$@")"
    else
        _wt "$@"
    fi
}

# Get worktree names for completion (handles nested paths like feature/auth/login)
_wt_get_worktrees() {
    local repo=$(git rev-parse --show-toplevel 2>/dev/null)
    local wt_dir="$repo/.worktrees"
    [[ -d "$wt_dir" ]] || return

    # Recursively find worktrees (dirs with .git file) without entering their content
    _find_wt() {
        local dir="$1" prefix="$2"
        for entry in "$dir"/*/; do
            [[ -d "$entry" ]] || continue
            local name=$(basename "$entry")
            if [[ -f "$entry/.git" ]]; then
                echo "${prefix}${name}"
            else
                _find_wt "$entry" "${prefix}${name}/"
            fi
        done
    }
    _find_wt "$wt_dir" ""
}

# Completion
_wt_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD-1]}

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "create list remove open cleanup config update version which -o" -- "$cur"))
    elif [[ $COMP_CWORD -eq 2 ]]; then
        case $prev in
            open|remove)
                local worktrees=$(_wt_get_worktrees)
                [[ -n "$worktrees" ]] && COMPREPLY=($(compgen -W "$worktrees" -- "$cur"))
                ;;
            list)
                COMPREPLY=($(compgen -W "--all" -- "$cur"))
                ;;
            update)
                COMPREPLY=($(compgen -W "--force" -- "$cur"))
                ;;
            config)
                COMPREPLY=($(compgen -W "base --list" -- "$cur"))
                ;;
            -o)
                COMPREPLY=($(compgen -W "create" -- "$cur"))
                ;;
        esac
    elif [[ $COMP_CWORD -eq 3 ]]; then
        case ${COMP_WORDS[2]} in
            base)
                COMPREPLY=($(compgen -W "--global --unset" -- "$cur"))
                ;;
        esac
    fi
}
complete -F _wt_complete wt
