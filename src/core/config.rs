use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

/// wt.toml configuration (per-repo)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct WtToml {
    #[serde(default)]
    pub repo: RepoConfig,

    #[serde(default)]
    pub agent: AgentConfig,

    #[serde(default)]
    pub hooks: HooksConfig,

    #[serde(default)]
    pub adapters: HashMap<String, AdapterConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepoConfig {
    #[serde(default = "default_base_branch")]
    pub base_branch: String,

    #[serde(default = "default_worktree_dir")]
    pub worktree_dir: String,
}

impl Default for RepoConfig {
    fn default() -> Self {
        Self {
            base_branch: default_base_branch(),
            worktree_dir: default_worktree_dir(),
        }
    }
}

fn default_base_branch() -> String {
    "main".to_string()
}

fn default_worktree_dir() -> String {
    ".worktrees".to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentConfig {
    #[serde(default = "default_agent_type")]
    #[serde(rename = "type")]
    pub agent_type: String,
}

impl Default for AgentConfig {
    fn default() -> Self {
        Self {
            agent_type: default_agent_type(),
        }
    }
}

fn default_agent_type() -> String {
    "claude-code".to_string()
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct HooksConfig {
    #[serde(default)]
    pub on_create: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AdapterConfig {
    pub command: String,
    pub skills_dir: String,
    #[serde(default)]
    pub context_flag: Option<String>,
}

impl WtToml {
    /// Load wt.toml from the given directory
    pub fn load(repo_root: &Path) -> Result<Self> {
        let path = repo_root.join("wt.toml");
        if !path.exists() {
            return Ok(Self::default());
        }

        let content = fs::read_to_string(&path).context("Failed to read wt.toml")?;
        let config: WtToml = toml::from_str(&content).context("Failed to parse wt.toml")?;
        Ok(config)
    }

    /// Save wt.toml to the given directory
    pub fn save(&self, repo_root: &Path) -> Result<()> {
        let path = repo_root.join("wt.toml");
        let content = toml::to_string_pretty(self).context("Failed to serialize wt.toml")?;
        fs::write(&path, content).context("Failed to write wt.toml")?;
        Ok(())
    }

    /// Get adapter config for the current agent type
    pub fn adapter(&self) -> Option<&AdapterConfig> {
        self.adapters.get(&self.agent.agent_type)
    }
}

/// Global configuration (~/.config/wt/config)
#[derive(Debug, Clone, Default)]
pub struct GlobalConfig {
    values: HashMap<String, String>,
    path: PathBuf,
}

impl GlobalConfig {
    /// Load global configuration
    pub fn load() -> Result<Self> {
        let path = Self::config_path()?;

        let values = if path.exists() {
            let content = fs::read_to_string(&path).context("Failed to read global config")?;
            Self::parse(&content)
        } else {
            HashMap::new()
        };

        Ok(Self { values, path })
    }

    /// Get the config file path
    fn config_path() -> Result<PathBuf> {
        let dirs = directories::ProjectDirs::from("", "", "wt")
            .context("Failed to determine config directory")?;
        let config_dir = dirs.config_dir();
        fs::create_dir_all(config_dir).context("Failed to create config directory")?;
        Ok(config_dir.join("config"))
    }

    /// Parse key=value format
    fn parse(content: &str) -> HashMap<String, String> {
        content
            .lines()
            .filter_map(|line| {
                let line = line.trim();
                if line.is_empty() || line.starts_with('#') {
                    return None;
                }
                let (key, value) = line.split_once('=')?;
                Some((key.trim().to_string(), value.trim().to_string()))
            })
            .collect()
    }

    /// Save the configuration
    pub fn save(&self) -> Result<()> {
        let content = self
            .values
            .iter()
            .map(|(k, v)| format!("{}={}", k, v))
            .collect::<Vec<_>>()
            .join("\n");
        fs::write(&self.path, content).context("Failed to write global config")?;
        Ok(())
    }

    /// Get a value
    pub fn get(&self, key: &str) -> Option<&String> {
        self.values.get(key)
    }

    /// Set a value
    pub fn set(&mut self, key: &str, value: &str) {
        self.values.insert(key.to_string(), value.to_string());
    }

    /// Remove a value
    pub fn remove(&mut self, key: &str) {
        self.values.remove(key);
    }

    /// Get global default base branch
    pub fn default_base(&self) -> Option<&String> {
        self.get("_default")
    }

    /// Set global default base branch
    pub fn set_default_base(&mut self, branch: &str) {
        self.set("_default", branch);
    }

    /// Get per-repo base branch
    pub fn repo_base(&self, repo_path: &Path) -> Option<&String> {
        let key = repo_path.to_string_lossy().to_string();
        self.get(&key)
    }

    /// Set per-repo base branch
    pub fn set_repo_base(&mut self, repo_path: &Path, branch: &str) {
        let key = repo_path.to_string_lossy().to_string();
        self.set(&key, branch);
    }

    /// Get on-create hook for a repo
    pub fn on_create_hook(&self, repo_path: &Path) -> Option<&String> {
        let key = format!("{}:on_create", repo_path.display());
        self.get(&key)
    }

    /// Set on-create hook for a repo
    pub fn set_on_create_hook(&mut self, repo_path: &Path, command: &str) {
        let key = format!("{}:on_create", repo_path.display());
        self.set(&key, command);
    }

    /// Remove on-create hook for a repo
    pub fn remove_on_create_hook(&mut self, repo_path: &Path) {
        let key = format!("{}:on_create", repo_path.display());
        self.remove(&key);
    }

    /// Get all values for display
    pub fn all(&self) -> &HashMap<String, String> {
        &self.values
    }
}

/// Combined configuration (repo + global)
pub struct Config {
    pub wt_toml: WtToml,
    pub global: GlobalConfig,
    pub repo_root: PathBuf,
}

impl Config {
    /// Load configuration for a repository
    pub fn load(repo_root: &Path) -> Result<Self> {
        let wt_toml = WtToml::load(repo_root)?;
        let global = GlobalConfig::load()?;

        Ok(Self {
            wt_toml,
            global,
            repo_root: repo_root.to_path_buf(),
        })
    }

    /// Get the effective base branch
    pub fn base_branch(&self) -> &str {
        // Priority: repo config in global > wt.toml > global default > "main"
        if let Some(branch) = self.global.repo_base(&self.repo_root) {
            return branch;
        }
        if !self.wt_toml.repo.base_branch.is_empty() {
            return &self.wt_toml.repo.base_branch;
        }
        if let Some(branch) = self.global.default_base() {
            return branch;
        }
        "main"
    }

    /// Get the worktrees directory
    pub fn worktree_dir(&self) -> PathBuf {
        self.repo_root.join(&self.wt_toml.repo.worktree_dir)
    }

    /// Get the on-create hook command
    pub fn on_create_hook(&self) -> Option<&String> {
        // Priority: global config > wt.toml
        if let Some(hook) = self.global.on_create_hook(&self.repo_root) {
            return Some(hook);
        }
        self.wt_toml.hooks.on_create.as_ref()
    }

    /// Save global config changes
    pub fn save_global(&self) -> Result<()> {
        self.global.save()
    }
}
