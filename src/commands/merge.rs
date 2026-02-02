use anyhow::{anyhow, Result};

use crate::cli::MergeArgs;
use crate::core::state::{State, WorktreeState};
use crate::output::table;

use super::get_worktree;

pub fn run(args: MergeArgs) -> Result<()> {
    let wt = get_worktree()?;
    let entry = wt.get(&args.name)?;

    // Check if in a worktree
    if wt.is_in_worktree() {
        // Merging into parent worktree
        let current = wt.current().ok_or_else(|| anyhow!("Not in a worktree"))?;
        table::info(&format!(
            "Merging '{}' into '{}'",
            entry.branch, current.branch
        ));
    } else {
        // Merging into base branch
        let base_branch = wt.config().base_branch();
        let current_branch = wt.git().current_branch()?;

        if current_branch != base_branch {
            return Err(anyhow!(
                "Not on base branch '{}'. Currently on '{}'.",
                base_branch,
                current_branch
            ));
        }

        table::info(&format!(
            "Merging '{}' into '{}'",
            entry.branch, base_branch
        ));
    }

    // Check if worktree is dirty
    if entry.is_dirty {
        return Err(anyhow!(
            "Worktree '{}' has uncommitted changes. Commit or stash them first.",
            args.name
        ));
    }

    // Perform the merge
    wt.git().merge(&entry.branch)?;
    table::success(&format!("Merged '{}'", entry.branch));

    // Delete worktree and branch if requested
    if args.delete {
        // Update worktree state
        let mut wt_state = WorktreeState::load(wt.repo_root())?;
        wt_state.remove(&args.name);
        wt_state.save(wt.repo_root())?;

        // Remove from spawn state
        let state_mgr = State::new()?;
        let mut spawn_state = state_mgr.load_spawn_state(wt.repo_root())?;
        spawn_state.tasks.remove(&args.name);
        state_mgr.save_spawn_state(wt.repo_root(), &spawn_state)?;

        // Remove worktree
        wt.remove(&args.name, false)?;

        // Delete branch
        wt.git().delete_branch(&entry.branch, false)?;

        table::success(&format!("Removed worktree and branch '{}'", args.name));
    }

    Ok(())
}
