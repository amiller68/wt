use std::path::{Path, PathBuf};
use std::process::Command;

use crate::error::{Result, WtError};

/// Get the root directory of the git repository
pub fn get_repo_root() -> Result<PathBuf> {
    let output = Command::new("git")
        .args(["rev-parse", "--show-toplevel"])
        .output()?;

    if !output.status.success() {
        return Err(WtError::NotInGitRepo);
    }

    let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
    Ok(PathBuf::from(path))
}

/// Get the common git directory (handles worktrees correctly)
pub fn get_git_common_dir() -> Result<PathBuf> {
    let output = Command::new("git")
        .args(["rev-parse", "--git-common-dir"])
        .output()?;

    if !output.status.success() {
        return Err(WtError::NotInGitRepo);
    }

    let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let path = PathBuf::from(path);

    // Resolve to absolute path
    if path.is_absolute() {
        Ok(path)
    } else {
        Ok(std::env::current_dir()?.join(path).canonicalize()?)
    }
}

/// Get the base repository directory (even when in a worktree)
pub fn get_base_repo() -> Result<PathBuf> {
    let git_common = get_git_common_dir()?;
    // The common dir is .git in the base repo
    Ok(git_common.parent().unwrap_or(&git_common).to_path_buf())
}

/// Check if we're inside a worktree (not the main repo)
pub fn is_in_worktree() -> Result<bool> {
    let cwd = std::env::current_dir()?;
    let base = get_base_repo()?;
    let worktrees_dir = base.join(".worktrees");

    Ok(cwd.starts_with(&worktrees_dir))
}

/// Get current worktree name (if in one)
pub fn get_current_worktree_name() -> Result<Option<String>> {
    if !is_in_worktree()? {
        return Ok(None);
    }

    let cwd = std::env::current_dir()?;
    let base = get_base_repo()?;
    let worktrees_dir = base.join(".worktrees");

    // Find the worktree root (directory containing .git file)
    let mut current = cwd.as_path();
    while current.starts_with(&worktrees_dir) && current != worktrees_dir {
        if current.join(".git").is_file() {
            // Found the worktree root
            let name = current
                .strip_prefix(&worktrees_dir)
                .map_err(|_| WtError::InvalidPath(current.to_path_buf()))?
                .to_string_lossy()
                .to_string();
            return Ok(Some(name));
        }
        current = current.parent().unwrap_or(current);
    }

    Ok(None)
}

/// Get the worktrees directory path
pub fn get_worktrees_dir() -> Result<PathBuf> {
    let base = get_base_repo()?;
    Ok(base.join(".worktrees"))
}

/// List all worktrees in .worktrees/
pub fn list_worktrees() -> Result<Vec<String>> {
    let worktrees_dir = get_worktrees_dir()?;

    if !worktrees_dir.exists() {
        return Ok(Vec::new());
    }

    let mut worktrees = Vec::new();
    find_worktrees_recursive(&worktrees_dir, &worktrees_dir, &mut worktrees)?;

    worktrees.sort();
    Ok(worktrees)
}

fn find_worktrees_recursive(
    base: &Path,
    current: &Path,
    worktrees: &mut Vec<String>,
) -> Result<()> {
    if !current.is_dir() {
        return Ok(());
    }

    for entry in std::fs::read_dir(current)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_dir() {
            // Check if this is a worktree (has .git file)
            if path.join(".git").is_file() {
                let name = path
                    .strip_prefix(base)
                    .map_err(|_| WtError::InvalidPath(path.clone()))?
                    .to_string_lossy()
                    .to_string();
                worktrees.push(name);
            } else {
                // Recurse into subdirectories
                find_worktrees_recursive(base, &path, worktrees)?;
            }
        }
    }

    Ok(())
}

/// List all git worktrees (including base repo)
pub fn list_all_worktrees() -> Result<Vec<(PathBuf, String)>> {
    let output = Command::new("git")
        .args(["worktree", "list", "--porcelain"])
        .output()?;

    if !output.status.success() {
        return Err(WtError::Git(
            String::from_utf8_lossy(&output.stderr).to_string(),
        ));
    }

    let text = String::from_utf8_lossy(&output.stdout);
    let mut worktrees = Vec::new();
    let mut current_path: Option<PathBuf> = None;
    let mut current_branch = String::new();

    for line in text.lines() {
        if let Some(path) = line.strip_prefix("worktree ") {
            current_path = Some(PathBuf::from(path));
        } else if let Some(branch) = line.strip_prefix("branch refs/heads/") {
            current_branch = branch.to_string();
        } else if line.is_empty() {
            if let Some(path) = current_path.take() {
                worktrees.push((path, std::mem::take(&mut current_branch)));
            }
        }
    }

    // Handle last entry
    if let Some(path) = current_path {
        worktrees.push((path, current_branch));
    }

    Ok(worktrees)
}

/// Check if a branch exists
pub fn branch_exists(branch: &str) -> Result<bool> {
    // Handle remote branches
    let branch = branch.strip_prefix("origin/").unwrap_or(branch);

    let output = Command::new("git")
        .args(["rev-parse", "--verify", &format!("refs/heads/{}", branch)])
        .output()?;

    if output.status.success() {
        return Ok(true);
    }

    // Check remote branches
    let output = Command::new("git")
        .args([
            "rev-parse",
            "--verify",
            &format!("refs/remotes/origin/{}", branch),
        ])
        .output()?;

    Ok(output.status.success())
}

/// Get the current branch name
pub fn get_current_branch() -> Result<String> {
    let output = Command::new("git")
        .args(["rev-parse", "--abbrev-ref", "HEAD"])
        .output()?;

    if !output.status.success() {
        return Err(WtError::Git("Failed to get current branch".to_string()));
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

/// Create a git worktree
pub fn create_worktree(path: &Path, branch: &str, base_branch: &str) -> Result<()> {
    // Check if branch exists
    let branch_exists_already = branch_exists(branch)?;

    let output = if branch_exists_already {
        Command::new("git")
            .args(["worktree", "add", &path.to_string_lossy(), branch])
            .output()?
    } else {
        // Create new branch from base
        // First try to find a valid start point
        let start_point = find_valid_start_point(base_branch)?;

        Command::new("git")
            .args([
                "worktree",
                "add",
                "-b",
                branch,
                &path.to_string_lossy(),
                &start_point,
            ])
            .output()?
    };

    if !output.status.success() {
        return Err(WtError::Git(
            String::from_utf8_lossy(&output.stderr).to_string(),
        ));
    }

    // Set up push tracking for new branches
    if !branch_exists_already {
        Command::new("git")
            .args(["-C", &path.to_string_lossy(), "config", "push.autoSetupRemote", "true"])
            .output()?;
    }

    Ok(())
}

/// Find a valid start point for creating a new branch
fn find_valid_start_point(base_branch: &str) -> Result<String> {
    // Try the base branch as-is first
    let output = Command::new("git")
        .args(["rev-parse", "--verify", base_branch])
        .output()?;

    if output.status.success() {
        return Ok(base_branch.to_string());
    }

    // Try with origin/ prefix
    if !base_branch.starts_with("origin/") {
        let with_origin = format!("origin/{}", base_branch);
        let output = Command::new("git")
            .args(["rev-parse", "--verify", &with_origin])
            .output()?;

        if output.status.success() {
            return Ok(with_origin);
        }
    }

    // Try refs/heads/ prefix
    let with_refs = format!("refs/heads/{}", base_branch);
    let output = Command::new("git")
        .args(["rev-parse", "--verify", &with_refs])
        .output()?;

    if output.status.success() {
        // Use the commit SHA directly
        let sha = String::from_utf8_lossy(&output.stdout).trim().to_string();
        return Ok(sha);
    }

    // Try refs/remotes/ prefix
    let with_remotes = if base_branch.starts_with("origin/") {
        format!("refs/remotes/{}", base_branch)
    } else {
        format!("refs/remotes/origin/{}", base_branch)
    };
    let output = Command::new("git")
        .args(["rev-parse", "--verify", &with_remotes])
        .output()?;

    if output.status.success() {
        let sha = String::from_utf8_lossy(&output.stdout).trim().to_string();
        return Ok(sha);
    }

    // Fall back to current HEAD commit
    let output = Command::new("git")
        .args(["rev-parse", "HEAD"])
        .output()?;

    if output.status.success() {
        let sha = String::from_utf8_lossy(&output.stdout).trim().to_string();
        return Ok(sha);
    }

    Err(WtError::BranchNotFound(base_branch.to_string()))
}

/// Remove a git worktree
pub fn remove_worktree(path: &Path, force: bool) -> Result<()> {
    let path_str = path.to_string_lossy();
    let mut args = vec!["worktree", "remove"];
    if force {
        args.push("--force");
    }
    args.push(&path_str);

    let output = Command::new("git").args(&args).output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        if stderr.contains("contains modified or untracked files") {
            return Err(WtError::UncommittedChanges);
        }
        return Err(WtError::Git(stderr));
    }

    Ok(())
}

/// Check if worktree has uncommitted changes
pub fn has_uncommitted_changes(path: &Path) -> Result<bool> {
    let output = Command::new("git")
        .args(["-C", &path.to_string_lossy(), "status", "--porcelain"])
        .output()?;

    if !output.status.success() {
        return Err(WtError::Git(
            String::from_utf8_lossy(&output.stderr).to_string(),
        ));
    }

    Ok(!output.stdout.is_empty())
}

/// Get commits ahead of base branch
pub fn get_commits_ahead(path: &Path, base_branch: &str) -> Result<Vec<String>> {
    let output = Command::new("git")
        .args([
            "-C",
            &path.to_string_lossy(),
            "log",
            &format!("{}..HEAD", base_branch),
            "--oneline",
        ])
        .output()?;

    if !output.status.success() {
        return Ok(Vec::new());
    }

    let text = String::from_utf8_lossy(&output.stdout);
    Ok(text.lines().map(|s| s.to_string()).collect())
}

/// Get diff stat for a worktree
pub fn get_diff_stat(path: &Path, base_branch: &str) -> Result<String> {
    let output = Command::new("git")
        .args([
            "-C",
            &path.to_string_lossy(),
            "diff",
            "--stat",
            base_branch,
        ])
        .output()?;

    if !output.status.success() {
        return Err(WtError::Git(
            String::from_utf8_lossy(&output.stderr).to_string(),
        ));
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Get full diff for a worktree
pub fn get_diff(path: &Path, base_branch: &str) -> Result<String> {
    let output = Command::new("git")
        .args(["-C", &path.to_string_lossy(), "diff", base_branch])
        .output()?;

    if !output.status.success() {
        return Err(WtError::Git(
            String::from_utf8_lossy(&output.stderr).to_string(),
        ));
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Merge a branch into the current branch
pub fn merge_branch(branch: &str) -> Result<()> {
    let output = Command::new("git")
        .args(["merge", branch, "--no-edit"])
        .output()?;

    if !output.status.success() {
        return Err(WtError::Git(
            String::from_utf8_lossy(&output.stderr).to_string(),
        ));
    }

    Ok(())
}

/// Get worktree branch
pub fn get_worktree_branch(path: &Path) -> Result<String> {
    let output = Command::new("git")
        .args(["-C", &path.to_string_lossy(), "rev-parse", "--abbrev-ref", "HEAD"])
        .output()?;

    if !output.status.success() {
        return Err(WtError::Git(
            String::from_utf8_lossy(&output.stderr).to_string(),
        ));
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

/// Ensure .worktrees is in git exclude
pub fn ensure_worktrees_excluded() -> Result<()> {
    let git_dir = get_git_common_dir()?;
    let exclude_file = git_dir.join("info").join("exclude");

    if !exclude_file.exists() {
        std::fs::create_dir_all(exclude_file.parent().unwrap())?;
        std::fs::write(&exclude_file, ".worktrees/\n")?;
        return Ok(());
    }

    let content = std::fs::read_to_string(&exclude_file)?;
    if !content.contains(".worktrees") {
        let mut file = std::fs::OpenOptions::new()
            .append(true)
            .open(&exclude_file)?;
        use std::io::Write;
        writeln!(file, ".worktrees/")?;
    }

    Ok(())
}
