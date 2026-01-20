# wt - git worktree manager
# https://github.com/amiller68/worktree

# Ensure ~/.local/bin is in PATH
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

wt() {
    # Eval output if command might cd (open, exit, or create with -o flag)
    # Don't eval when using --all flag (tabs are opened directly)
    if [[ "$1" == "open" && "$2" == "--all" ]]; then
        _wt "$@"
    elif [[ "$1" == "open" || "$1" == "exit" || "$1" == "-o" || "$2" == "-o" || "$*" == *"-o"* ]]; then
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
            local name=${entry%/}
            name=${name##*/}
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
_wt_completion() {
    local -a commands
    commands=(
        'create:Create a new worktree'
        'list:List worktrees'
        'remove:Remove a worktree'
        'open:cd to worktree directory (--all opens in tabs)'
        'exit:Exit current worktree (removes it)'
        'health:Show terminal detection and dependency status'
        'config:Configure base branch settings'
        'update:Update wt to latest version'
        'version:Show version info'
        'which:Show path to wt script'
    )

    if (( CURRENT == 2 )); then
        _describe -t commands 'wt commands' commands
        compadd -- '-o' '--no-hooks'
    elif (( CURRENT == 3 )); then
        case ${words[2]} in
            open)
                local -a worktrees
                worktrees=($(_wt_get_worktrees))
                compadd -- '--all'
                [[ ${#worktrees} -gt 0 ]] && _describe -t worktrees 'worktrees' worktrees
                ;;
            remove)
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
            config)
                compadd -- 'base' 'on-create' '--list'
                ;;
            -o|--no-hooks)
                compadd -- 'create'
                ;;
        esac
    elif (( CURRENT == 4 )); then
        case ${words[3]} in
            base)
                compadd -- '--global' '--unset'
                ;;
            on-create)
                compadd -- '--unset'
                ;;
        esac
    fi
}
compdef _wt_completion wt
