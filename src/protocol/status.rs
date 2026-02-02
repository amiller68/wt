use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

/// Worker status values
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum WorkerStatusValue {
    Working,
    Blocked,
    Question,
    Done,
}

impl std::fmt::Display for WorkerStatusValue {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Working => write!(f, "working"),
            Self::Blocked => write!(f, "blocked"),
            Self::Question => write!(f, "question"),
            Self::Done => write!(f, "done"),
        }
    }
}

/// Worker status file (.wt/status.json)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkerStatus {
    pub status: WorkerStatusValue,
    pub message: Option<String>,
    pub updated_at: DateTime<Utc>,
}

impl Default for WorkerStatus {
    fn default() -> Self {
        Self {
            status: WorkerStatusValue::Working,
            message: None,
            updated_at: Utc::now(),
        }
    }
}

impl WorkerStatus {
    /// Load status from a worktree directory
    pub fn load(worktree_path: &Path) -> Result<Option<Self>> {
        let path = worktree_path.join(".wt/status.json");
        if !path.exists() {
            return Ok(None);
        }

        let content = fs::read_to_string(&path).context("Failed to read status.json")?;
        let status: WorkerStatus =
            serde_json::from_str(&content).context("Failed to parse status.json")?;
        Ok(Some(status))
    }

    /// Save status to a worktree directory
    pub fn save(&self, worktree_path: &Path) -> Result<()> {
        let wt_dir = worktree_path.join(".wt");
        fs::create_dir_all(&wt_dir).context("Failed to create .wt directory")?;

        let path = wt_dir.join("status.json");
        let content =
            serde_json::to_string_pretty(self).context("Failed to serialize status.json")?;
        fs::write(&path, content).context("Failed to write status.json")?;
        Ok(())
    }

    /// Create initial status for a new worker
    pub fn new_working() -> Self {
        Self {
            status: WorkerStatusValue::Working,
            message: None,
            updated_at: Utc::now(),
        }
    }
}
