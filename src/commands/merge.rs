use colored::Colorize;

use crate::error::{Result, WtError};
use crate::git;
use crate::spawn;

pub fn run(name: &str) -> Result<()> {
    let worktrees_dir = git::get_worktrees_dir()?;
    let worktree_path = worktrees_dir.join(name);

    if !worktree_path.exists() {
        return Err(WtError::WorktreeNotFound(name.to_string()));
    }

    // Check for uncommitted changes
    if git::has_uncommitted_changes(&worktree_path)? {
        return Err(WtError::UncommittedChanges);
    }

    // Get branch name
    let branch = git::get_worktree_branch(&worktree_path)?;

    // Merge the branch
    git::merge_branch(&branch)?;

    eprintln!(
        "{} Merged branch '{}' into current branch",
        "✓".green(),
        branch.cyan()
    );

    // Unregister from spawn state
    spawn::unregister(name)?;

    // Kill tmux window if running
    spawn::kill_window(name)?;

    eprintln!();
    eprintln!(
        "  {} Remove worktree with: {}",
        "→".dimmed(),
        format!("wt remove {}", name).cyan()
    );

    Ok(())
}
