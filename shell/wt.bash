# wt - git worktree manager
# https://github.com/amiller68/wt

# Ensure ~/.local/bin and ~/.cargo/bin are in PATH
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"
[[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]] && export PATH="$HOME/.cargo/bin:$PATH"

# Store the real binary name
_WT_BIN="${_WT_BIN:-wt}"

wt() {
    # Commands that might output cd commands for eval
    local cmd="$1"

    # Handle special cases that need eval
    case "$cmd" in
        open)
            # Don't eval for --all (tabs are opened directly)
            if [[ "$2" == "--all" ]]; then
                command "$_WT_BIN" "$@"
            else
                eval "$(command "$_WT_BIN" "$@")"
            fi
            ;;
        exit)
            eval "$(command "$_WT_BIN" "$@")"
            ;;
        create)
            # Check for -o/--open flag anywhere in args
            local has_open=0
            for arg in "$@"; do
                [[ "$arg" == "-o" || "$arg" == "--open" ]] && has_open=1
            done
            if [[ $has_open -eq 1 ]]; then
                eval "$(command "$_WT_BIN" "$@")"
            else
                command "$_WT_BIN" "$@"
            fi
            ;;
        *)
            command "$_WT_BIN" "$@"
            ;;
    esac
}

# Get worktree names for completion (handles nested paths like feature/auth/login)
_wt_get_worktrees() {
    local repo=$(git rev-parse --show-toplevel 2>/dev/null)
    local wt_dir="$repo/.worktrees"
    [[ -d "$wt_dir" ]] || return

    # Recursively find worktrees (dirs with .git file)
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
    local cmd=${COMP_WORDS[1]}

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "create open list remove exit config spawn ps status attach kill review merge init health update version which completions" -- "$cur"))
    elif [[ $COMP_CWORD -eq 2 ]]; then
        case $prev in
            open)
                local worktrees=$(_wt_get_worktrees)
                COMPREPLY=($(compgen -W "--all $worktrees" -- "$cur"))
                ;;
            remove|kill|attach|review|merge)
                local worktrees=$(_wt_get_worktrees)
                [[ -n "$worktrees" ]] && COMPREPLY=($(compgen -W "$worktrees" -- "$cur"))
                ;;
            list)
                COMPREPLY=($(compgen -W "--all --json" -- "$cur"))
                ;;
            config)
                COMPREPLY=($(compgen -W "show base on-create list" -- "$cur"))
                ;;
            init)
                COMPREPLY=($(compgen -W "--force --fix --backup --audit" -- "$cur"))
                ;;
            update)
                COMPREPLY=($(compgen -W "--force" -- "$cur"))
                ;;
            spawn)
                COMPREPLY=($(compgen -W "--context --issue --parent --auto" -- "$cur"))
                ;;
            create)
                COMPREPLY=($(compgen -W "--branch --open --no-hooks" -- "$cur"))
                ;;
            completions)
                COMPREPLY=($(compgen -W "bash zsh fish powershell elvish" -- "$cur"))
                ;;
        esac
    elif [[ $COMP_CWORD -ge 3 ]]; then
        case $cmd in
            config)
                case ${COMP_WORDS[2]} in
                    base)
                        COMPREPLY=($(compgen -W "--global" -- "$cur"))
                        ;;
                    on-create)
                        COMPREPLY=($(compgen -W "--unset" -- "$cur"))
                        ;;
                esac
                ;;
        esac
    fi
}
complete -F _wt_complete wt
