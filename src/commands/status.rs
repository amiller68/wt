use anyhow::Result;

use crate::core::state::State;
use crate::core::{Git, Tmux};
use crate::output::{table, Table};
use crate::protocol::WorkerStatus;

use super::get_worktree;

pub fn run() -> Result<()> {
    let wt = get_worktree()?;
    let state_mgr = State::new()?;
    let spawn_state = state_mgr.load_spawn_state(wt.repo_root())?;
    let base_branch = wt.config().base_branch().to_string();

    // Get all worktrees with .wt/status.json
    let worktrees = wt.list()?;

    if worktrees.is_empty() && spawn_state.tasks.is_empty() {
        eprintln!("No workers found");
        eprintln!("Use 'wt spawn <name>' to spawn a worker");
        return Ok(());
    }

    let tmux = Tmux::new();
    let active_windows = tmux.list_windows().unwrap_or_default();

    let mut output = Table::new(vec!["Worker", "Status", "Issue", "Changes", "Age"]);
    let mut blocked_messages = Vec::new();

    for entry in &worktrees {
        let status = WorkerStatus::load(&entry.path)?;
        let task = spawn_state.tasks.get(&entry.name);

        let status_val = status.as_ref().map(|s| s.status);
        let status_str = status_val
            .map(|s| s.to_string())
            .unwrap_or_else(|| {
                if active_windows.contains(&entry.name) {
                    "running".to_string()
                } else {
                    "unknown".to_string()
                }
            });

        let issue = task
            .and_then(|t| t.issue.as_ref())
            .map(|i| format!("#{}", i))
            .unwrap_or_else(|| "—".to_string());

        // Get diff stats
        let (additions, deletions) = Git::from_path(&entry.path)
            .ok()
            .and_then(|g| g.diff_stats(&entry.branch, &base_branch).ok())
            .unwrap_or((0, 0));
        let changes = table::diff_stat(additions, deletions);

        let age = task
            .map(|t| table::format_age(t.spawned_at))
            .unwrap_or_else(|| "—".to_string());

        output.add_status_row(
            vec![
                entry.name.clone(),
                status_str,
                issue,
                changes,
                age,
            ],
            1,
            status_val,
        );

        // Collect blocked messages
        if let Some(s) = &status {
            if s.status == crate::protocol::WorkerStatusValue::Blocked
                || s.status == crate::protocol::WorkerStatusValue::Question
            {
                if let Some(msg) = &s.message {
                    blocked_messages.push((entry.name.clone(), s.status, msg.clone()));
                }
            }
        }
    }

    output.print();

    // Print blocked messages
    for (name, status, msg) in blocked_messages {
        eprintln!();
        eprintln!(
            "{} {}: \"{}\"",
            console::style(name).bold(),
            status,
            msg
        );
    }

    Ok(())
}
