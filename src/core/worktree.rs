use anyhow::{anyhow, Context, Result};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use super::config::Config;
use super::git::Git;

/// High-level worktree operations
pub struct Worktree {
    git: Git,
    config: Config,
}

impl Worktree {
    /// Create a new Worktree manager
    pub fn new(git: Git, config: Config) -> Self {
        Self { git, config }
    }

    /// Get the Git instance
    pub fn git(&self) -> &Git {
        &self.git
    }

    /// Get the Config instance
    pub fn config(&self) -> &Config {
        &self.config
    }

    /// Get mutable Config instance
    pub fn config_mut(&mut self) -> &mut Config {
        &mut self.config
    }

    /// Get the repository root
    pub fn repo_root(&self) -> &Path {
        &self.git.repo_root
    }

    /// Get the worktrees directory
    pub fn worktrees_dir(&self) -> PathBuf {
        self.config.worktree_dir()
    }

    /// Create a new worktree
    pub fn create(&self, name: &str, base_branch: Option<&str>) -> Result<PathBuf> {
        let base = base_branch.unwrap_or_else(|| self.config.base_branch());
        let worktree_path = self.worktrees_dir().join(name);

        // Check if worktree already exists
        if worktree_path.exists() {
            return Err(anyhow!("Worktree '{}' already exists", name));
        }

        // Check if branch already exists
        if self.git.branch_exists(name)? {
            // Use existing branch
            self.git.create_worktree_existing(&worktree_path, name)?;
        } else {
            // Create new branch from base
            self.git.create_worktree(&worktree_path, name, base)?;
        }

        Ok(worktree_path)
    }

    /// Run on-create hook if configured
    pub fn run_on_create_hook(&self, worktree_path: &Path) -> Result<()> {
        if let Some(hook) = self.config.on_create_hook() {
            eprintln!(
                "{} Running on-create hook: {}",
                console::style("→").blue(),
                hook
            );

            let status = Command::new("sh")
                .args(["-c", hook])
                .current_dir(worktree_path)
                .status()
                .context("Failed to run on-create hook")?;

            if !status.success() {
                eprintln!(
                    "{} on-create hook failed (exit code: {:?})",
                    console::style("!").yellow(),
                    status.code()
                );
            }
        }
        Ok(())
    }

    /// List worktrees in .worktrees/ directory
    pub fn list(&self) -> Result<Vec<WorktreeListEntry>> {
        let worktrees_dir = self.worktrees_dir();
        if !worktrees_dir.exists() {
            return Ok(Vec::new());
        }

        let git_worktrees = self.git.list_worktrees()?;
        let mut entries = Vec::new();

        // Walk the worktrees directory to find all worktrees
        self.collect_worktrees(&worktrees_dir, &worktrees_dir, &git_worktrees, &mut entries)?;

        // Sort by name
        entries.sort_by(|a, b| a.name.cmp(&b.name));

        Ok(entries)
    }

    /// Recursively collect worktrees from a directory
    fn collect_worktrees(
        &self,
        base: &Path,
        dir: &Path,
        git_worktrees: &[super::git::WorktreeInfo],
        entries: &mut Vec<WorktreeListEntry>,
    ) -> Result<()> {
        if !dir.exists() {
            return Ok(());
        }

        for entry in fs::read_dir(dir).context("Failed to read worktrees directory")? {
            let entry = entry?;
            let path = entry.path();

            if !path.is_dir() {
                continue;
            }

            // Check if this is a worktree (has .git file)
            if path.join(".git").exists() {
                let name = path
                    .strip_prefix(base)
                    .unwrap_or(&path)
                    .to_string_lossy()
                    .to_string();

                // Find matching git worktree info
                let git_info = git_worktrees.iter().find(|wt| wt.path == path);

                let branch = git_info.map(|i| i.branch.clone()).unwrap_or_default();
                let is_dirty = Git::from_path(&path)
                    .ok()
                    .and_then(|g| g.is_dirty().ok())
                    .unwrap_or(false);

                entries.push(WorktreeListEntry {
                    name,
                    path: path.clone(),
                    branch,
                    is_dirty,
                });
            } else {
                // Check subdirectories (for nested worktrees like feature/auth/oauth)
                self.collect_worktrees(base, &path, git_worktrees, entries)?;
            }
        }

        Ok(())
    }

    /// Find a worktree by name (supports partial matching)
    pub fn find(&self, name: &str) -> Result<Option<WorktreeListEntry>> {
        let worktrees = self.list()?;

        // Exact match first
        if let Some(wt) = worktrees.iter().find(|w| w.name == name) {
            return Ok(Some(wt.clone()));
        }

        // Partial match (ends with name)
        let matches: Vec<_> = worktrees
            .iter()
            .filter(|w| w.name.ends_with(name) || w.name.ends_with(&format!("/{}", name)))
            .collect();

        match matches.len() {
            0 => Ok(None),
            1 => Ok(Some(matches[0].clone())),
            _ => Err(anyhow!(
                "Ambiguous worktree name '{}', matches: {}",
                name,
                matches
                    .iter()
                    .map(|w| w.name.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            )),
        }
    }

    /// Get worktree by name
    pub fn get(&self, name: &str) -> Result<WorktreeListEntry> {
        self.find(name)?
            .ok_or_else(|| anyhow!("Worktree '{}' not found", name))
    }

    /// Remove a worktree
    pub fn remove(&self, name: &str, force: bool) -> Result<()> {
        let wt = self.get(name)?;
        self.git.remove_worktree(&wt.path, force)?;

        // Clean up empty parent directories
        self.cleanup_empty_dirs(&wt.path)?;

        Ok(())
    }

    /// Remove empty parent directories up to the worktrees root
    fn cleanup_empty_dirs(&self, path: &Path) -> Result<()> {
        let worktrees_dir = self.worktrees_dir();
        let mut current = path.parent();

        while let Some(dir) = current {
            if dir == worktrees_dir || !dir.starts_with(&worktrees_dir) {
                break;
            }

            if dir.exists() && fs::read_dir(dir)?.next().is_none() {
                fs::remove_dir(dir).ok();
            }

            current = dir.parent();
        }

        Ok(())
    }

    /// Check if we're inside a worktree
    pub fn is_in_worktree(&self) -> bool {
        self.git.cwd.starts_with(&self.worktrees_dir())
    }

    /// Get the current worktree if we're in one
    pub fn current(&self) -> Option<WorktreeListEntry> {
        if !self.is_in_worktree() {
            return None;
        }

        let worktrees = self.list().ok()?;
        worktrees
            .into_iter()
            .find(|wt| self.git.cwd.starts_with(&wt.path))
    }

    /// Match worktrees by glob pattern
    pub fn match_pattern(&self, pattern: &str) -> Result<Vec<WorktreeListEntry>> {
        let worktrees = self.list()?;

        // Convert glob pattern to regex-like matching
        let pattern = pattern.replace("*", ".*").replace("?", ".");
        let re = regex_lite::Regex::new(&format!("^{}$", pattern))
            .context("Invalid pattern")?;

        Ok(worktrees
            .into_iter()
            .filter(|wt| re.is_match(&wt.name))
            .collect())
    }
}

/// Entry in the worktree list
#[derive(Debug, Clone)]
pub struct WorktreeListEntry {
    pub name: String,
    pub path: PathBuf,
    pub branch: String,
    pub is_dirty: bool,
}
