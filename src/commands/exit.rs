use anyhow::{anyhow, Result};

use crate::cli::ExitArgs;
use crate::output::table;

use super::get_worktree;

pub fn run(args: ExitArgs) -> Result<()> {
    let wt = get_worktree()?;

    // Check if we're in a worktree
    let current = wt.current().ok_or_else(|| {
        anyhow!("Not in a worktree. Use 'wt remove <name>' to remove a worktree.")
    })?;

    // Check for dirty state
    if !args.force && current.is_dirty {
        return Err(anyhow!(
            "Worktree '{}' has uncommitted changes. Use --force to exit anyway.",
            current.name
        ));
    }

    let repo_root = wt.repo_root().to_path_buf();

    // Remove the worktree
    table::info(&format!("Exiting worktree '{}'", current.name));
    wt.remove(&current.name, args.force)?;
    table::success("Worktree removed");

    // Output cd command to return to repo root
    println!("cd \"{}\"", repo_root.display());

    Ok(())
}
