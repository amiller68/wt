use anyhow::{anyhow, Result};

use crate::cli::KillArgs;
use crate::core::state::State;
use crate::core::Tmux;
use crate::output::table;

use super::get_worktree;

pub fn run(args: KillArgs) -> Result<()> {
    let tmux = Tmux::new();

    if !tmux.session_exists() {
        return Err(anyhow!("No wt session running"));
    }

    if !tmux.window_exists(&args.name) {
        return Err(anyhow!("No window '{}' found in wt session", args.name));
    }

    tmux.kill_window(&args.name)?;

    // Remove from spawn state
    let wt = get_worktree()?;
    let state_mgr = State::new()?;
    let mut spawn_state = state_mgr.load_spawn_state(wt.repo_root())?;
    spawn_state.tasks.remove(&args.name);
    state_mgr.save_spawn_state(wt.repo_root(), &spawn_state)?;

    table::success(&format!("Killed worker '{}'", args.name));

    Ok(())
}
