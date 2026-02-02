use colored::Colorize;

use crate::config;
use crate::error::{Result, WtError};
use crate::git;
use crate::spawn as spawn_state;

pub fn run(name: &str, context: Option<&str>, auto: bool) -> Result<()> {
    // Check for tmux
    if !crate::terminal::command_exists("tmux") {
        return Err(WtError::MissingDependency("tmux".to_string()));
    }

    // Check for claude
    if !crate::terminal::command_exists("claude") {
        return Err(WtError::MissingDependency("claude".to_string()));
    }

    let worktrees_dir = git::get_worktrees_dir()?;
    let worktree_path = worktrees_dir.join(name);

    // Check if worktree already exists
    let needs_create = !worktree_path.exists();

    if needs_create {
        // Create worktree from current branch
        let current_branch = git::get_current_branch()?;
        let base_branch = config::get_base_branch()?;

        git::ensure_worktrees_excluded()?;

        // Create parent directories for nested paths
        if let Some(parent) = worktree_path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        // Create new branch from current position
        git::create_worktree(&worktree_path, name, &base_branch)?;

        eprintln!(
            "{} Created worktree '{}' from '{}'",
            "✓".green(),
            name.cyan(),
            current_branch.cyan()
        );
    }

    // Determine if auto mode should be used
    let use_auto = if auto {
        true
    } else {
        // Check wt.toml for spawn.auto setting
        config::read_wt_toml()?
            .map(|c| c.spawn.auto)
            .unwrap_or(false)
    };

    // Register in spawn state
    let branch = git::get_worktree_branch(&worktree_path)?;
    spawn_state::register(name, &branch, context)?;

    // Launch in tmux
    spawn_state::launch_tmux_window(name, &worktree_path, use_auto, context)?;

    eprintln!(
        "{} Launched Claude in tmux window '{}'",
        "✓".green(),
        name.cyan()
    );

    if use_auto {
        eprintln!("  {} Auto mode enabled", "→".dimmed());
    }

    eprintln!();
    eprintln!("  Use '{}' to attach", format!("wt attach {}", name).cyan());
    eprintln!("  Use '{}' to check status", "wt ps".cyan());

    Ok(())
}
