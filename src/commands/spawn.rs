use anyhow::{anyhow, Result};
use chrono::Utc;
use std::fs;

use crate::cli::SpawnArgs;
use crate::core::state::{SpawnedTask, State, WorktreeState};
use crate::core::Tmux;
use crate::output::table;
use crate::protocol::{TaskFile, WorkerStatus};

use super::get_worktree;

pub fn run(args: SpawnArgs) -> Result<()> {
    // Check tmux availability
    if !Tmux::is_available() {
        return Err(anyhow!(
            "tmux is required for spawn. Install tmux and try again."
        ));
    }

    let wt = get_worktree()?;
    let config = wt.config();

    // Determine if auto mode should be used
    let auto = args.auto || config.wt_toml.hooks.on_create.is_some();

    table::info(&format!("Spawning worker '{}'", args.name));

    // Create the worktree
    let worktree_path = wt.create(&args.name, None)?;

    // Create .wt directory and files
    let wt_dir = worktree_path.join(".wt");
    fs::create_dir_all(&wt_dir)?;

    // Build task description
    let description = if let Some(issue) = &args.issue {
        format!("Work on issue {}", issue)
    } else if let Some(context) = &args.context {
        context.clone()
    } else {
        format!("Work on task: {}", args.name)
    };

    // Create task.md
    let mut task = TaskFile::new(&description);
    if let Some(issue) = &args.issue {
        task = task.with_issue(issue);
    }
    if let Some(context) = &args.context {
        task = task.with_context(context);
    }
    task.save(&worktree_path)?;

    // Create initial status.json
    WorkerStatus::new_working().save(&worktree_path)?;

    // Add .wt to .gitignore if not already there
    ensure_wt_ignored(&worktree_path)?;

    // Save to spawn state
    let state_mgr = State::new()?;
    let mut spawn_state = state_mgr.load_spawn_state(wt.repo_root())?;
    spawn_state.tasks.insert(
        args.name.clone(),
        SpawnedTask {
            name: args.name.clone(),
            branch: args.name.clone(),
            path: worktree_path.clone(),
            context: args.context.clone(),
            issue: args.issue.clone(),
            parent: args.parent.clone(),
            spawned_at: Utc::now(),
            auto,
        },
    );
    state_mgr.save_spawn_state(wt.repo_root(), &spawn_state)?;

    // Update worktree state for hierarchy
    let mut wt_state = WorktreeState::load(wt.repo_root())?;
    wt_state.add(&args.name, args.parent.as_deref(), args.issue.as_deref());
    wt_state.save(wt.repo_root())?;

    // Create tmux window and launch agent
    let tmux = Tmux::new();
    tmux.create_window(&args.name, &worktree_path)?;

    // Get the agent command from config
    let agent_command = if let Some(adapter) = config.wt_toml.adapter() {
        adapter.command.clone()
    } else {
        "claude".to_string()
    };

    // Build and send the command
    let cmd = if auto {
        // Auto mode: write prompt file and launch with dangerously-skip-permissions
        let prompt_path = worktree_path.join(".claude-spawn-prompt");
        fs::write(&prompt_path, "Read .wt/task.md and begin work on the task.")?;
        format!(
            "{} --dangerously-skip-permissions --prompt-file \"{}\"",
            agent_command,
            prompt_path.display()
        )
    } else {
        // Manual mode: just launch the agent
        agent_command
    };

    tmux.send_keys(&args.name, &cmd)?;

    table::success(&format!(
        "Spawned worker '{}' in tmux session '{}'",
        args.name,
        tmux.session_name()
    ));
    eprintln!("Use 'wt attach {}' to connect", args.name);

    Ok(())
}

/// Ensure .wt is in .gitignore
fn ensure_wt_ignored(worktree_path: &std::path::Path) -> Result<()> {
    let gitignore_path = worktree_path.join(".gitignore");

    let content = if gitignore_path.exists() {
        fs::read_to_string(&gitignore_path)?
    } else {
        String::new()
    };

    if !content.lines().any(|line| line.trim() == ".wt") {
        let new_content = if content.ends_with('\n') || content.is_empty() {
            format!("{}.wt\n", content)
        } else {
            format!("{}\n.wt\n", content)
        };
        fs::write(&gitignore_path, new_content)?;
    }

    Ok(())
}
