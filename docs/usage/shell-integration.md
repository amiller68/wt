# Shell Integration

How `wt` integrates with your shell — tab completion, directory changing, and troubleshooting.

## Tab Completion

Both bash and zsh get tab completion after install:

```bash
wt <TAB>           # Shows: create list open remove exit config update version
wt open <TAB>      # Shows available worktrees
wt remove <TAB>    # Shows available worktrees
wt config <TAB>    # Shows: base on-create --list
```

## How the `-o` Flag Works

The `wt` shell function wraps the underlying `_wt` script. When you use `open` or the `-o` flag, the script outputs a `cd` command that the shell function `eval`s:

```bash
# What happens internally:
_wt open my-feature  # outputs: cd "/path/to/.worktrees/my-feature"
eval "cd ..."        # shell function evals it
```

This is why `wt open` can change your current directory — it's a shell function, not an external script.

## Why `which wt` Doesn't Work

Since `wt` is a shell function (required for `cd` functionality), `which wt` shows the function definition instead of a path. Use this instead:

```bash
wt which    # Shows path to the underlying _wt script
```
