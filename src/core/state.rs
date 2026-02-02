use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

/// State directory management
pub struct State {
    state_dir: PathBuf,
}

impl State {
    /// Create a new state manager
    pub fn new() -> Result<Self> {
        let dirs = directories::ProjectDirs::from("", "", "wt")
            .context("Failed to determine config directory")?;
        let state_dir = dirs.config_dir().join("spawned");
        fs::create_dir_all(&state_dir).context("Failed to create state directory")?;

        Ok(Self { state_dir })
    }

    /// Get the state file path for a repo
    fn state_file(&self, repo_root: &Path) -> PathBuf {
        let hash = format!("{:x}", md5::compute(repo_root.to_string_lossy().as_bytes()));
        self.state_dir.join(format!("{}.json", hash))
    }

    /// Load spawn state for a repo
    pub fn load_spawn_state(&self, repo_root: &Path) -> Result<SpawnState> {
        let path = self.state_file(repo_root);
        if !path.exists() {
            return Ok(SpawnState::default());
        }

        let content = fs::read_to_string(&path).context("Failed to read spawn state")?;
        let state: SpawnState =
            serde_json::from_str(&content).context("Failed to parse spawn state")?;
        Ok(state)
    }

    /// Save spawn state for a repo
    pub fn save_spawn_state(&self, repo_root: &Path, state: &SpawnState) -> Result<()> {
        let path = self.state_file(repo_root);
        let content = serde_json::to_string_pretty(state).context("Failed to serialize state")?;
        fs::write(&path, content).context("Failed to write spawn state")?;
        Ok(())
    }
}

/// Spawn state for a repository
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SpawnState {
    pub tasks: HashMap<String, SpawnedTask>,
}

/// A spawned task
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpawnedTask {
    pub name: String,
    pub branch: String,
    pub path: PathBuf,
    pub context: Option<String>,
    pub issue: Option<String>,
    pub parent: Option<String>,
    pub spawned_at: DateTime<Utc>,
    pub auto: bool,
}

/// Worktree state (stored in .wt/state.json at repo root)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct WorktreeState {
    pub worktrees: HashMap<String, WorktreeEntry>,
}

/// An entry in the worktree hierarchy
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorktreeEntry {
    pub parent: Option<String>,
    #[serde(default)]
    pub children: Vec<String>,
    pub issue: Option<String>,
    pub status: Option<String>,
}

impl WorktreeState {
    /// Load worktree state from repo root
    pub fn load(repo_root: &Path) -> Result<Self> {
        let path = repo_root.join(".wt/state.json");
        if !path.exists() {
            return Ok(Self::default());
        }

        let content = fs::read_to_string(&path).context("Failed to read worktree state")?;
        let state: WorktreeState =
            serde_json::from_str(&content).context("Failed to parse worktree state")?;
        Ok(state)
    }

    /// Save worktree state to repo root
    pub fn save(&self, repo_root: &Path) -> Result<()> {
        let wt_dir = repo_root.join(".wt");
        fs::create_dir_all(&wt_dir).context("Failed to create .wt directory")?;

        let path = wt_dir.join("state.json");
        let content =
            serde_json::to_string_pretty(self).context("Failed to serialize worktree state")?;
        fs::write(&path, content).context("Failed to write worktree state")?;
        Ok(())
    }

    /// Add a worktree entry
    pub fn add(
        &mut self,
        name: &str,
        parent: Option<&str>,
        issue: Option<&str>,
    ) {
        // Update parent's children list if there's a parent
        if let Some(parent_name) = parent {
            if let Some(parent_entry) = self.worktrees.get_mut(parent_name) {
                if !parent_entry.children.contains(&name.to_string()) {
                    parent_entry.children.push(name.to_string());
                }
            }
        }

        self.worktrees.insert(
            name.to_string(),
            WorktreeEntry {
                parent: parent.map(|s| s.to_string()),
                children: Vec::new(),
                issue: issue.map(|s| s.to_string()),
                status: Some("working".to_string()),
            },
        );
    }

    /// Remove a worktree entry
    pub fn remove(&mut self, name: &str) {
        // Get parent name first to avoid borrow issues
        let parent_name = self
            .worktrees
            .get(name)
            .and_then(|e| e.parent.clone());

        // Remove from parent's children list
        if let Some(parent_name) = parent_name {
            if let Some(parent) = self.worktrees.get_mut(&parent_name) {
                parent.children.retain(|c| c != name);
            }
        }

        self.worktrees.remove(name);
    }

    /// Get all children of a worktree (recursive)
    pub fn get_all_children(&self, name: &str) -> Vec<String> {
        let mut children = Vec::new();
        if let Some(entry) = self.worktrees.get(name) {
            for child in &entry.children {
                children.push(child.clone());
                children.extend(self.get_all_children(child));
            }
        }
        children
    }
}
