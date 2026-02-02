use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use crate::config;
use crate::error::{Result, WtError};
use crate::git;

const TMUX_SESSION: &str = "wt-spawned";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpawnedTask {
    pub name: String,
    pub branch: String,
    pub context: Option<String>,
    pub created: DateTime<Utc>,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct SpawnState {
    pub spawned: Vec<SpawnedTask>,
}

/// Get spawn state directory
pub fn get_spawn_dir() -> Result<PathBuf> {
    let config_dir = config::get_config_dir()?;
    Ok(config_dir.join("spawned"))
}

/// Get spawn state file for current repo
fn get_spawn_file() -> Result<PathBuf> {
    let repo = git::get_base_repo()?;
    let repo_str = repo.to_string_lossy();

    // Hash the repo path
    let mut hasher = Sha256::new();
    hasher.update(repo_str.as_bytes());
    let hash = format!("{:x}", hasher.finalize());
    let short_hash = &hash[..12];

    let spawn_dir = get_spawn_dir()?;
    Ok(spawn_dir.join(format!("{}.json", short_hash)))
}

/// Read spawn state
pub fn read_state() -> Result<SpawnState> {
    let file = get_spawn_file()?;

    if !file.exists() {
        return Ok(SpawnState::default());
    }

    let content = fs::read_to_string(&file)?;
    let state: SpawnState = serde_json::from_str(&content)?;
    Ok(state)
}

/// Write spawn state
fn write_state(state: &SpawnState) -> Result<()> {
    let file = get_spawn_file()?;
    fs::create_dir_all(file.parent().unwrap())?;

    let content = serde_json::to_string_pretty(state)?;
    fs::write(&file, content)?;
    Ok(())
}

/// Register a new spawned task
pub fn register(name: &str, branch: &str, context: Option<&str>) -> Result<()> {
    let mut state = read_state()?;

    // Check if already exists
    if state.spawned.iter().any(|t| t.name == name) {
        // Update existing
        if let Some(task) = state.spawned.iter_mut().find(|t| t.name == name) {
            task.context = context.map(|s| s.to_string());
        }
    } else {
        state.spawned.push(SpawnedTask {
            name: name.to_string(),
            branch: branch.to_string(),
            context: context.map(|s| s.to_string()),
            created: Utc::now(),
        });
    }

    write_state(&state)
}

/// Unregister a spawned task
pub fn unregister(name: &str) -> Result<()> {
    let mut state = read_state()?;
    state.spawned.retain(|t| t.name != name);
    write_state(&state)
}

/// Get a spawned task by name
pub fn get_task(name: &str) -> Result<Option<SpawnedTask>> {
    let state = read_state()?;
    Ok(state.spawned.into_iter().find(|t| t.name == name))
}

/// Task status for ps command
#[derive(Debug)]
pub enum TaskStatus {
    Running,
    Exited,
    NoSession,
    NoWindow,
}

impl TaskStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            TaskStatus::Running => "running",
            TaskStatus::Exited => "exited",
            TaskStatus::NoSession => "no_session",
            TaskStatus::NoWindow => "no_window",
        }
    }
}

/// Check if tmux session exists
pub fn session_exists() -> bool {
    Command::new("tmux")
        .args(["has-session", "-t", TMUX_SESSION])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Check if tmux window exists
fn window_exists(name: &str) -> bool {
    if !session_exists() {
        return false;
    }

    let output = Command::new("tmux")
        .args([
            "list-windows",
            "-t",
            TMUX_SESSION,
            "-F",
            "#{window_name}",
        ])
        .output();

    match output {
        Ok(o) => {
            let windows = String::from_utf8_lossy(&o.stdout);
            windows.lines().any(|w| w == name)
        }
        Err(_) => false,
    }
}

/// Check if pane is still running a command
fn pane_running(name: &str) -> bool {
    if !window_exists(name) {
        return false;
    }

    let output = Command::new("tmux")
        .args([
            "list-panes",
            "-t",
            &format!("{}:{}", TMUX_SESSION, name),
            "-F",
            "#{pane_current_command}",
        ])
        .output();

    match output {
        Ok(o) => {
            let cmd = String::from_utf8_lossy(&o.stdout).trim().to_string();
            // If running bash/zsh, claude has exited
            !matches!(cmd.as_str(), "bash" | "zsh" | "fish" | "sh")
        }
        Err(_) => false,
    }
}

/// Get status of a task
pub fn get_task_status(name: &str) -> TaskStatus {
    if !session_exists() {
        TaskStatus::NoSession
    } else if !window_exists(name) {
        TaskStatus::NoWindow
    } else if pane_running(name) {
        TaskStatus::Running
    } else {
        TaskStatus::Exited
    }
}

/// Task info for ps command
#[derive(Debug)]
pub struct TaskInfo {
    pub name: String,
    pub status: TaskStatus,
    pub branch: String,
    pub commits_ahead: usize,
    pub is_dirty: bool,
}

/// Get info for all spawned tasks
pub fn list_tasks() -> Result<Vec<TaskInfo>> {
    let state = read_state()?;
    let worktrees_dir = git::get_worktrees_dir()?;
    let base_branch = config::get_base_branch()?;

    let mut tasks = Vec::new();

    for task in state.spawned {
        let path = worktrees_dir.join(&task.name);

        let commits_ahead = if path.exists() {
            git::get_commits_ahead(&path, &base_branch)
                .map(|c| c.len())
                .unwrap_or(0)
        } else {
            0
        };

        let is_dirty = if path.exists() {
            git::has_uncommitted_changes(&path).unwrap_or(false)
        } else {
            false
        };

        tasks.push(TaskInfo {
            name: task.name.clone(),
            status: get_task_status(&task.name),
            branch: task.branch,
            commits_ahead,
            is_dirty,
        });
    }

    Ok(tasks)
}

/// Create tmux session if needed and launch a window
pub fn launch_tmux_window(name: &str, dir: &Path, auto: bool, context: Option<&str>) -> Result<()> {
    // Ensure session exists
    if !session_exists() {
        Command::new("tmux")
            .args(["new-session", "-d", "-s", TMUX_SESSION])
            .output()?;
    }

    // Create window
    Command::new("tmux")
        .args([
            "new-window",
            "-t",
            TMUX_SESSION,
            "-n",
            name,
            "-c",
            &dir.to_string_lossy(),
        ])
        .output()?;

    // Write context file
    if let Some(ctx) = context {
        let task_file = dir.join(".claude-task");
        fs::write(&task_file, ctx)?;
    }

    // Launch claude
    let claude_cmd = if auto {
        // Build prompt
        let prompt = build_spawn_prompt(dir, context)?;
        let prompt_file = dir.join(".claude-spawn-prompt");
        fs::write(&prompt_file, &prompt)?;

        format!("claude --dangerously-skip-permissions -p \"$(cat .claude-spawn-prompt)\"")
    } else {
        "claude".to_string()
    };

    Command::new("tmux")
        .args([
            "send-keys",
            "-t",
            &format!("{}:{}", TMUX_SESSION, name),
            &claude_cmd,
            "Enter",
        ])
        .output()?;

    Ok(())
}

/// Build prompt for auto mode
fn build_spawn_prompt(dir: &Path, context: Option<&str>) -> Result<String> {
    let docs_index = dir.join("docs").join("index.md");

    let mut prompt = String::new();

    // Add docs/index.md content if exists
    if docs_index.exists() {
        let content = fs::read_to_string(&docs_index)?;
        prompt.push_str(&content);
        prompt.push_str("\n\n");
    }

    // Add task context
    if let Some(ctx) = context {
        prompt.push_str("## Task\n\n");
        prompt.push_str(ctx);
    }

    Ok(prompt)
}

/// Kill a tmux window
pub fn kill_window(name: &str) -> Result<()> {
    if !window_exists(name) {
        return Ok(());
    }

    Command::new("tmux")
        .args([
            "kill-window",
            "-t",
            &format!("{}:{}", TMUX_SESSION, name),
        ])
        .output()?;

    Ok(())
}

/// Attach to tmux session
pub fn attach(name: Option<&str>) -> Result<()> {
    if !session_exists() {
        return Err(WtError::Custom("No wt-spawned session".to_string()));
    }

    // Select window first if specified
    if let Some(n) = name {
        if !window_exists(n) {
            return Err(WtError::WorktreeNotFound(n.to_string()));
        }

        Command::new("tmux")
            .args([
                "select-window",
                "-t",
                &format!("{}:{}", TMUX_SESSION, n),
            ])
            .output()?;
    }

    // Attach to session - this replaces current process
    let err = exec::execvp("tmux", &["tmux", "attach", "-t", TMUX_SESSION]);
    Err(WtError::Custom(format!("Failed to attach: {:?}", err)))
}

// Simple exec for Unix
#[cfg(unix)]
mod exec {
    use std::ffi::CString;

    pub fn execvp(cmd: &str, args: &[&str]) -> std::io::Error {
        let cmd = CString::new(cmd).unwrap();
        let args: Vec<CString> = args
            .iter()
            .map(|a| CString::new(*a).unwrap())
            .collect();
        let args: Vec<&std::ffi::CStr> = args.iter().map(|a| a.as_c_str()).collect();

        nix::unistd::execvp(&cmd, &args).unwrap_err().into()
    }
}

#[cfg(not(unix))]
mod exec {
    pub fn execvp(_cmd: &str, _args: &[&str]) -> std::io::Error {
        std::io::Error::new(std::io::ErrorKind::Unsupported, "exec not supported")
    }
}
