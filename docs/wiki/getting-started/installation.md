# Installation

## Requirements

- Git 2.15+ (worktree support)
- Bash 4+
- tmux (optional, for spawn feature)

## Install

Clone and add to your PATH:

```bash
git clone https://github.com/amiller68/wt.git ~/.wt
echo 'export PATH="$HOME/.wt:$PATH"' >> ~/.bashrc
```

## Shell Integration

Add to your `.bashrc` or `.zshrc`:

```bash
# Bash
source ~/.wt/shell/wt.bash

# Zsh
source ~/.wt/shell/wt.zsh
```

This enables:
- Tab completion
- `wt` function wrapper (for `cd` into worktrees)

## Verify

```bash
wt --version
```
