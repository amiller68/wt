use anyhow::Result;

use crate::core::state::State;
use crate::core::Tmux;
use crate::output::{table, Table};

use super::get_worktree;

pub fn run() -> Result<()> {
    let wt = get_worktree()?;
    let state_mgr = State::new()?;
    let spawn_state = state_mgr.load_spawn_state(wt.repo_root())?;

    if spawn_state.tasks.is_empty() {
        eprintln!("No spawned workers");
        eprintln!("Use 'wt spawn <name>' to spawn a worker");
        return Ok(());
    }

    let tmux = Tmux::new();
    let active_windows = tmux.list_windows().unwrap_or_default();

    let mut output = Table::new(vec!["Worker", "Branch", "Status", "Age"]);

    for (name, task) in &spawn_state.tasks {
        let is_running = active_windows.contains(name);
        let status = if is_running { "running" } else { "stopped" };
        let age = table::format_age(task.spawned_at);

        output.add_row(vec![
            name.clone(),
            task.branch.clone(),
            status.to_string(),
            age,
        ]);
    }

    output.print();

    Ok(())
}
