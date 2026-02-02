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
        'open:cd to worktree directory (--all opens in tabs)'
        'list:List worktrees'
        'remove:Remove a worktree'
        'exit:Exit current worktree (removes it)'
        'config:Configure wt settings'
        'spawn:Create worktree and launch agent'
        'ps:Show spawned sessions'
        'status:Show worker status'
        'attach:Attach to tmux session'
        'kill:Kill tmux window'
        'review:Show diff for review'
        'merge:Merge worktree'
        'init:Initialize wt scaffolding'
        'health:Check system health'
        'update:Self-update wt'
        'version:Show version'
        'which:Show path to wt binary'
        'completions:Generate shell completions'
    )

    if (( CURRENT == 2 )); then
        _describe -t commands 'wt commands' commands
    elif (( CURRENT == 3 )); then
        case ${words[2]} in
            open)
                local -a worktrees
                worktrees=($(_wt_get_worktrees))
                compadd -- '--all'
                [[ ${#worktrees} -gt 0 ]] && _describe -t worktrees 'worktrees' worktrees
                ;;
            remove|kill|attach|review|merge)
                local -a worktrees
                worktrees=($(_wt_get_worktrees))
                [[ ${#worktrees} -gt 0 ]] && _describe -t worktrees 'worktrees' worktrees
                ;;
            list)
                compadd -- '--all' '--json'
                ;;
            config)
                compadd -- 'show' 'base' 'on-create' 'list'
                ;;
            init)
                compadd -- '--force' '--fix' '--backup' '--audit'
                ;;
            update)
                compadd -- '--force'
                ;;
            create)
                compadd -- '--branch' '--open' '--no-hooks'
                ;;
            spawn)
                compadd -- '--context' '--issue' '--parent' '--auto'
                ;;
            completions)
                compadd -- 'bash' 'zsh' 'fish' 'powershell' 'elvish'
                ;;
        esac
    elif (( CURRENT == 4 )); then
        case ${words[3]} in
            base)
                compadd -- '--global'
                ;;
            on-create)
                compadd -- '--unset'
                ;;
        esac
    fi
}
compdef _wt_completion wt
