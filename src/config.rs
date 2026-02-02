use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

use crate::error::{Result, WtError};
use crate::git;

const DEFAULT_BASE_BRANCH: &str = "origin/main";

/// Get the config directory path
pub fn get_config_dir() -> Result<PathBuf> {
    let config_dir = if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        PathBuf::from(xdg).join("wt")
    } else {
        dirs::home_dir()
            .ok_or_else(|| WtError::Custom("Could not find home directory".to_string()))?
            .join(".config")
            .join("wt")
    };

    Ok(config_dir)
}

/// Get the config file path
pub fn get_config_file() -> Result<PathBuf> {
    Ok(get_config_dir()?.join("config"))
}

/// Read all config entries
pub fn read_config() -> Result<HashMap<String, String>> {
    let config_file = get_config_file()?;
    let mut config = HashMap::new();

    if !config_file.exists() {
        return Ok(config);
    }

    let content = fs::read_to_string(&config_file)?;
    for line in content.lines() {
        if let Some((key, value)) = line.split_once('=') {
            config.insert(key.to_string(), value.to_string());
        }
    }

    Ok(config)
}

/// Write all config entries
pub fn write_config(config: &HashMap<String, String>) -> Result<()> {
    let config_file = get_config_file()?;

    fs::create_dir_all(config_file.parent().unwrap())?;

    let content: String = config
        .iter()
        .map(|(k, v)| format!("{}={}", k, v))
        .collect::<Vec<_>>()
        .join("\n");

    fs::write(&config_file, content + "\n")?;
    Ok(())
}

/// Get config key for repo base branch
fn get_repo_base_key() -> Result<String> {
    let repo = git::get_base_repo()?;
    Ok(repo.to_string_lossy().to_string())
}

/// Get config key for repo on-create hook
fn get_repo_on_create_key() -> Result<String> {
    let repo = git::get_base_repo()?;
    Ok(format!("{}:on_create", repo.to_string_lossy()))
}

/// Get the effective base branch
pub fn get_base_branch() -> Result<String> {
    let config = read_config()?;

    // Try repo-specific first
    if let Ok(key) = get_repo_base_key() {
        if let Some(branch) = config.get(&key) {
            return Ok(branch.clone());
        }
    }

    // Try global default
    if let Some(branch) = config.get("_default") {
        return Ok(branch.clone());
    }

    // Hardcoded fallback
    Ok(DEFAULT_BASE_BRANCH.to_string())
}

/// Set repo-specific base branch
pub fn set_repo_base_branch(branch: &str) -> Result<()> {
    let key = get_repo_base_key()?;
    let mut config = read_config()?;
    config.insert(key, branch.to_string());
    write_config(&config)
}

/// Unset repo-specific base branch
pub fn unset_repo_base_branch() -> Result<()> {
    let key = get_repo_base_key()?;
    let mut config = read_config()?;
    config.remove(&key);
    write_config(&config)
}

/// Get repo-specific base branch (if set)
pub fn get_repo_base_branch() -> Result<Option<String>> {
    let key = get_repo_base_key()?;
    let config = read_config()?;
    Ok(config.get(&key).cloned())
}

/// Set global default base branch
pub fn set_global_base_branch(branch: &str) -> Result<()> {
    let mut config = read_config()?;
    config.insert("_default".to_string(), branch.to_string());
    write_config(&config)
}

/// Unset global default base branch
pub fn unset_global_base_branch() -> Result<()> {
    let mut config = read_config()?;
    config.remove("_default");
    write_config(&config)
}

/// Get global default base branch (if set)
pub fn get_global_base_branch() -> Result<Option<String>> {
    let config = read_config()?;
    Ok(config.get("_default").cloned())
}

/// Get on-create hook for repo
pub fn get_on_create_hook() -> Result<Option<String>> {
    let key = get_repo_on_create_key()?;
    let config = read_config()?;
    Ok(config.get(&key).cloned())
}

/// Set on-create hook for repo
pub fn set_on_create_hook(command: &str) -> Result<()> {
    let key = get_repo_on_create_key()?;
    let mut config = read_config()?;
    config.insert(key, command.to_string());
    write_config(&config)
}

/// Unset on-create hook for repo
pub fn unset_on_create_hook() -> Result<()> {
    let key = get_repo_on_create_key()?;
    let mut config = read_config()?;
    config.remove(&key);
    write_config(&config)
}

/// Run on-create hook in a directory
pub fn run_on_create_hook(dir: &Path) -> Result<bool> {
    let hook = match get_on_create_hook()? {
        Some(h) => h,
        None => return Ok(true), // No hook configured, success
    };

    eprintln!("Running on-create hook: {}", hook);

    let output = std::process::Command::new("sh")
        .args(["-c", &hook])
        .current_dir(dir)
        .output()?;

    if !output.status.success() {
        eprintln!(
            "Warning: on-create hook failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
        return Ok(false);
    }

    Ok(true)
}

/// WtToml configuration from wt.toml
#[derive(Debug, Default, serde::Deserialize)]
pub struct WtToml {
    #[serde(default)]
    pub spawn: SpawnConfig,
}

#[derive(Debug, Default, serde::Deserialize)]
pub struct SpawnConfig {
    #[serde(default)]
    pub auto: bool,
}

/// Read wt.toml from repo
pub fn read_wt_toml() -> Result<Option<WtToml>> {
    let repo = git::get_base_repo()?;
    let toml_path = repo.join("wt.toml");

    if !toml_path.exists() {
        return Ok(None);
    }

    let content = fs::read_to_string(&toml_path)?;
    let config: WtToml = toml::from_str(&content)?;
    Ok(Some(config))
}

/// Check if wt.toml exists
pub fn has_wt_toml() -> Result<bool> {
    let repo = git::get_base_repo()?;
    Ok(repo.join("wt.toml").exists())
}

/// Get a specific config value from wt.toml
pub fn get_wt_config(key: &str) -> Result<Option<String>> {
    let config = match read_wt_toml()? {
        Some(c) => c,
        None => return Ok(None),
    };

    match key {
        "spawn.auto" => Ok(Some(config.spawn.auto.to_string())),
        _ => Ok(None),
    }
}

/// Configuration display for `wt config` command
pub struct ConfigDisplay {
    pub effective_base: String,
    pub repo_base: Option<String>,
    pub global_base: Option<String>,
    pub on_create_hook: Option<String>,
}

impl ConfigDisplay {
    pub fn load() -> Result<Self> {
        Ok(Self {
            effective_base: get_base_branch()?,
            repo_base: get_repo_base_branch()?,
            global_base: get_global_base_branch()?,
            on_create_hook: get_on_create_hook()?,
        })
    }
}

/// Get all config entries for --list
pub fn list_all_config() -> Result<Vec<(String, String, String)>> {
    let config = read_config()?;
    let mut entries = Vec::new();

    for (key, value) in config {
        let category = if key == "_default" {
            "[global]".to_string()
        } else if key.contains(":on_create") {
            let path = key.strip_suffix(":on_create").unwrap_or(&key);
            format!("[{}] on-create", path)
        } else {
            format!("[{}]", key)
        };

        let display_key = if key == "_default" {
            "base".to_string()
        } else if key.contains(":on_create") {
            "on-create".to_string()
        } else {
            "base".to_string()
        };

        entries.push((category, display_key, value));
    }

    Ok(entries)
}
