use anyhow::{anyhow, Result};
use std::io::{self, Write};

use crate::cli::RemoveArgs;
use crate::core::state::WorktreeState;
use crate::output::table;

use super::get_worktree;

pub fn run(args: RemoveArgs) -> Result<()> {
    let wt = get_worktree()?;

    // Find matching worktrees
    let matches = if args.pattern.contains('*') || args.pattern.contains('?') {
        wt.match_pattern(&args.pattern)?
    } else {
        match wt.find(&args.pattern)? {
            Some(entry) => vec![entry],
            None => return Err(anyhow!("No worktree matching '{}' found", args.pattern)),
        }
    };

    if matches.is_empty() {
        return Err(anyhow!("No worktrees matching '{}' found", args.pattern));
    }

    // Handle recursive removal
    let mut all_to_remove = Vec::new();
    if args.recursive {
        let state = WorktreeState::load(wt.repo_root())?;
        for entry in &matches {
            all_to_remove.push(entry.clone());
            // Add all children
            for child_name in state.get_all_children(&entry.name) {
                if let Ok(Some(child)) = wt.find(&child_name) {
                    all_to_remove.push(child);
                }
            }
        }
    } else {
        all_to_remove = matches;
    }

    // Confirm if not forced
    if !args.force && all_to_remove.len() > 1 {
        eprintln!("Will remove {} worktrees:", all_to_remove.len());
        for entry in &all_to_remove {
            eprintln!("  - {}", entry.name);
        }
        eprint!("Continue? [y/N] ");
        io::stderr().flush()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        if !input.trim().eq_ignore_ascii_case("y") {
            eprintln!("Aborted");
            return Ok(());
        }
    }

    // Check for dirty worktrees
    let dirty: Vec<_> = all_to_remove.iter().filter(|e| e.is_dirty).collect();
    if !dirty.is_empty() && !args.force {
        eprintln!("The following worktrees have uncommitted changes:");
        for entry in &dirty {
            eprintln!("  - {}", entry.name);
        }
        return Err(anyhow!(
            "Use --force to remove dirty worktrees"
        ));
    }

    // Remove worktrees
    let mut state = WorktreeState::load(wt.repo_root())?;
    for entry in &all_to_remove {
        table::info(&format!("Removing worktree '{}'", entry.name));
        wt.remove(&entry.name, args.force)?;
        state.remove(&entry.name);
    }
    state.save(wt.repo_root())?;

    table::success(&format!(
        "Removed {} worktree{}",
        all_to_remove.len(),
        if all_to_remove.len() == 1 { "" } else { "s" }
    ));

    Ok(())
}
