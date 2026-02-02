pub mod attach;
pub mod completions;
pub mod config;
pub mod create;
pub mod exit;
pub mod health;
pub mod init;
pub mod kill;
pub mod list;
pub mod merge;
pub mod open;
pub mod ps;
pub mod remove;
pub mod review;
pub mod spawn;
pub mod status;
pub mod update;
pub mod version;
pub mod which;

use anyhow::Result;

use crate::core::{Config, Git, Worktree};

/// Helper to create a Worktree instance from current directory
pub fn get_worktree() -> Result<Worktree> {
    let git = Git::new()?;
    let config = Config::load(&git.repo_root)?;
    Ok(Worktree::new(git, config))
}
