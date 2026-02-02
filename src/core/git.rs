use anyhow::{anyhow, Context, Result};
use std::path::{Path, PathBuf};
use std::process::Command;

/// Git operations helper
pub struct Git {
    /// The repository root (base repo, not worktree)
    pub repo_root: PathBuf,
    /// The current working directory (may be in a worktree)
    pub cwd: PathBuf,
}

impl Git {
    /// Create a new Git instance, detecting repo from current directory
    pub fn new() -> Result<Self> {
        let cwd = std::env::current_dir().context("Failed to get current directory")?;
        Self::from_path(&cwd)
    }

    /// Create a Git instance from a specific path
    pub fn from_path(path: &Path) -> Result<Self> {
        // Get the git common dir (handles worktrees correctly)
        let output = Command::new("git")
            .args(["rev-parse", "--git-common-dir"])
            .current_dir(path)
            .output()
            .context("Failed to run git rev-parse")?;

        if !output.status.success() {
            return Err(anyhow!("Not a git repository"));
        }

        let git_common_dir = String::from_utf8_lossy(&output.stdout).trim().to_string();
        let git_common_path = if git_common_dir == ".git" {
            path.join(".git")
        } else {
            PathBuf::from(&git_common_dir)
        };

        // Repo root is parent of .git directory
        let repo_root = git_common_path
            .parent()
            .ok_or_else(|| anyhow!("Invalid git directory structure"))?
            .to_path_buf();

        Ok(Self {
            repo_root,
            cwd: path.to_path_buf(),
        })
    }

    /// Get the base worktrees directory (.worktrees/)
    pub fn worktrees_dir(&self) -> PathBuf {
        self.repo_root.join(".worktrees")
    }

    /// Get current branch name
    pub fn current_branch(&self) -> Result<String> {
        let output = Command::new("git")
            .args(["branch", "--show-current"])
            .current_dir(&self.cwd)
            .output()
            .context("Failed to get current branch")?;

        if !output.status.success() {
            return Err(anyhow!("Failed to get current branch"));
        }

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }

    /// Check if a branch exists (local or remote)
    pub fn branch_exists(&self, branch: &str) -> Result<bool> {
        // Check local branches
        let local = Command::new("git")
            .args(["show-ref", "--verify", "--quiet", &format!("refs/heads/{}", branch)])
            .current_dir(&self.repo_root)
            .output()
            .context("Failed to check local branch")?;

        if local.status.success() {
            return Ok(true);
        }

        // Check remote branches
        let remote = Command::new("git")
            .args([
                "show-ref",
                "--verify",
                "--quiet",
                &format!("refs/remotes/origin/{}", branch),
            ])
            .current_dir(&self.repo_root)
            .output()
            .context("Failed to check remote branch")?;

        Ok(remote.status.success())
    }

    /// Create a new worktree with a new branch
    pub fn create_worktree(&self, path: &Path, branch: &str, base: &str) -> Result<()> {
        // Ensure parent directory exists
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).context("Failed to create worktree parent directory")?;
        }

        let output = Command::new("git")
            .args([
                "worktree",
                "add",
                "-b",
                branch,
                path.to_str().unwrap(),
                base,
            ])
            .current_dir(&self.repo_root)
            .output()
            .context("Failed to create worktree")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("Failed to create worktree: {}", stderr));
        }

        // Add .worktrees to git exclude if not already there
        self.ensure_worktrees_excluded()?;

        Ok(())
    }

    /// Create a worktree from an existing branch
    pub fn create_worktree_existing(&self, path: &Path, branch: &str) -> Result<()> {
        // Ensure parent directory exists
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).context("Failed to create worktree parent directory")?;
        }

        let output = Command::new("git")
            .args(["worktree", "add", path.to_str().unwrap(), branch])
            .current_dir(&self.repo_root)
            .output()
            .context("Failed to create worktree")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("Failed to create worktree: {}", stderr));
        }

        self.ensure_worktrees_excluded()?;

        Ok(())
    }

    /// Ensure .worktrees is in .git/info/exclude
    fn ensure_worktrees_excluded(&self) -> Result<()> {
        let exclude_path = self.repo_root.join(".git/info/exclude");

        let content = if exclude_path.exists() {
            std::fs::read_to_string(&exclude_path).unwrap_or_default()
        } else {
            String::new()
        };

        if !content.lines().any(|line| line.trim() == ".worktrees") {
            let new_content = if content.ends_with('\n') || content.is_empty() {
                format!("{}.worktrees\n", content)
            } else {
                format!("{}\n.worktrees\n", content)
            };
            std::fs::write(&exclude_path, new_content).context("Failed to update git exclude")?;
        }

        Ok(())
    }

    /// List all worktrees
    pub fn list_worktrees(&self) -> Result<Vec<WorktreeInfo>> {
        let output = Command::new("git")
            .args(["worktree", "list", "--porcelain"])
            .current_dir(&self.repo_root)
            .output()
            .context("Failed to list worktrees")?;

        if !output.status.success() {
            return Err(anyhow!("Failed to list worktrees"));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut worktrees = Vec::new();
        let mut current: Option<WorktreeInfo> = None;

        for line in stdout.lines() {
            if line.starts_with("worktree ") {
                if let Some(wt) = current.take() {
                    worktrees.push(wt);
                }
                current = Some(WorktreeInfo {
                    path: PathBuf::from(line.trim_start_matches("worktree ")),
                    branch: String::new(),
                    head: String::new(),
                    bare: false,
                });
            } else if line.starts_with("HEAD ") {
                if let Some(ref mut wt) = current {
                    wt.head = line.trim_start_matches("HEAD ").to_string();
                }
            } else if line.starts_with("branch ") {
                if let Some(ref mut wt) = current {
                    wt.branch = line
                        .trim_start_matches("branch refs/heads/")
                        .to_string();
                }
            } else if line == "bare" {
                if let Some(ref mut wt) = current {
                    wt.bare = true;
                }
            }
        }

        if let Some(wt) = current {
            worktrees.push(wt);
        }

        Ok(worktrees)
    }

    /// Remove a worktree
    pub fn remove_worktree(&self, path: &Path, force: bool) -> Result<()> {
        let mut args = vec!["worktree", "remove"];
        if force {
            args.push("--force");
        }
        args.push(path.to_str().unwrap());

        let output = Command::new("git")
            .args(&args)
            .current_dir(&self.repo_root)
            .output()
            .context("Failed to remove worktree")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("Failed to remove worktree: {}", stderr));
        }

        Ok(())
    }

    /// Check if working directory is dirty (has uncommitted changes)
    pub fn is_dirty(&self) -> Result<bool> {
        let output = Command::new("git")
            .args(["status", "--porcelain"])
            .current_dir(&self.cwd)
            .output()
            .context("Failed to check git status")?;

        if !output.status.success() {
            return Err(anyhow!("Failed to check git status"));
        }

        Ok(!output.stdout.is_empty())
    }

    /// Get the diff stats (additions, deletions) for a branch vs base
    pub fn diff_stats(&self, branch: &str, base: &str) -> Result<(usize, usize)> {
        let output = Command::new("git")
            .args(["diff", "--numstat", &format!("{}...{}", base, branch)])
            .current_dir(&self.repo_root)
            .output()
            .context("Failed to get diff stats")?;

        if !output.status.success() {
            return Ok((0, 0));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut additions = 0;
        let mut deletions = 0;

        for line in stdout.lines() {
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 2 {
                additions += parts[0].parse::<usize>().unwrap_or(0);
                deletions += parts[1].parse::<usize>().unwrap_or(0);
            }
        }

        Ok((additions, deletions))
    }

    /// Get commit count ahead of base branch
    pub fn commits_ahead(&self, branch: &str, base: &str) -> Result<usize> {
        let output = Command::new("git")
            .args([
                "rev-list",
                "--count",
                &format!("{}..{}", base, branch),
            ])
            .current_dir(&self.repo_root)
            .output()
            .context("Failed to count commits")?;

        if !output.status.success() {
            return Ok(0);
        }

        Ok(String::from_utf8_lossy(&output.stdout)
            .trim()
            .parse()
            .unwrap_or(0))
    }

    /// Merge a branch into current branch
    pub fn merge(&self, branch: &str) -> Result<()> {
        let output = Command::new("git")
            .args(["merge", branch])
            .current_dir(&self.cwd)
            .output()
            .context("Failed to merge branch")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("Merge failed: {}", stderr));
        }

        Ok(())
    }

    /// Delete a branch
    pub fn delete_branch(&self, branch: &str, force: bool) -> Result<()> {
        let flag = if force { "-D" } else { "-d" };
        let output = Command::new("git")
            .args(["branch", flag, branch])
            .current_dir(&self.repo_root)
            .output()
            .context("Failed to delete branch")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("Failed to delete branch: {}", stderr));
        }

        Ok(())
    }

    /// Get the diff between two branches
    pub fn diff(&self, base: &str, branch: &str, full: bool) -> Result<String> {
        let range = format!("{}...{}", base, branch);
        let mut args = vec!["diff"];
        if !full {
            args.push("--stat");
        }
        args.push(&range);

        let output = Command::new("git")
            .args(&args)
            .current_dir(&self.repo_root)
            .output()
            .context("Failed to get diff")?;

        if !output.status.success() {
            return Ok(String::new());
        }

        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }
}

/// Information about a worktree
#[derive(Debug, Clone)]
pub struct WorktreeInfo {
    pub path: PathBuf,
    pub branch: String,
    pub head: String,
    pub bare: bool,
}
