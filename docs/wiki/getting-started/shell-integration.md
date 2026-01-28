# Shell Integration

Shell integration makes `wt` more convenient to use.

## Setup

Add to your shell config:

```bash
# ~/.bashrc
source ~/.wt/shell/wt.bash

# ~/.zshrc
source ~/.wt/shell/wt.zsh
```

## Features

### Directory Switching

Without shell integration, `wt open` prints the path. With it, you `cd` directly:

```bash
wt open my-feature  # cd's into the worktree
```

### Tab Completion

Complete worktree names:

```bash
wt open my-<TAB>
# my-feature  my-bugfix  my-experiment
```

### wt which

Print the current worktree name (useful in prompts):

```bash
wt which
# my-feature
```

## Shell Prompt

Add worktree name to your prompt:

```bash
# Bash
PS1='$(wt which 2>/dev/null && echo " ")$PS1'
```
