use anyhow::{anyhow, Context, Result};
use std::path::Path;
use std::process::Command;

/// Tmux session management
pub struct Tmux {
    session_name: String,
}

impl Tmux {
    /// Create a new Tmux manager with the default session name
    pub fn new() -> Self {
        Self {
            session_name: "wt-spawned".to_string(),
        }
    }

    /// Check if tmux is available
    pub fn is_available() -> bool {
        which::which("tmux").is_ok()
    }

    /// Check if the wt session exists
    pub fn session_exists(&self) -> bool {
        Command::new("tmux")
            .args(["has-session", "-t", &self.session_name])
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    /// Create the session if it doesn't exist
    pub fn ensure_session(&self) -> Result<()> {
        if !self.session_exists() {
            let output = Command::new("tmux")
                .args([
                    "new-session",
                    "-d",
                    "-s",
                    &self.session_name,
                    "-n",
                    "main",
                ])
                .output()
                .context("Failed to create tmux session")?;

            if !output.status.success() {
                let stderr = String::from_utf8_lossy(&output.stderr);
                return Err(anyhow!("Failed to create tmux session: {}", stderr));
            }
        }
        Ok(())
    }

    /// Create a new window in the session
    pub fn create_window(&self, name: &str, working_dir: &Path) -> Result<()> {
        self.ensure_session()?;

        let output = Command::new("tmux")
            .args([
                "new-window",
                "-t",
                &self.session_name,
                "-n",
                name,
                "-c",
                working_dir.to_str().unwrap(),
            ])
            .output()
            .context("Failed to create tmux window")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("Failed to create tmux window: {}", stderr));
        }

        Ok(())
    }

    /// Send keys to a window
    pub fn send_keys(&self, window: &str, keys: &str) -> Result<()> {
        let target = format!("{}:{}", self.session_name, window);

        let output = Command::new("tmux")
            .args(["send-keys", "-t", &target, keys, "Enter"])
            .output()
            .context("Failed to send keys to tmux")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("Failed to send keys: {}", stderr));
        }

        Ok(())
    }

    /// Kill a window
    pub fn kill_window(&self, name: &str) -> Result<()> {
        let target = format!("{}:{}", self.session_name, name);

        let output = Command::new("tmux")
            .args(["kill-window", "-t", &target])
            .output()
            .context("Failed to kill tmux window")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("Failed to kill window: {}", stderr));
        }

        Ok(())
    }

    /// Check if a window exists
    pub fn window_exists(&self, name: &str) -> bool {
        let target = format!("{}:{}", self.session_name, name);

        Command::new("tmux")
            .args(["select-window", "-t", &target])
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    /// List windows in the session
    pub fn list_windows(&self) -> Result<Vec<String>> {
        if !self.session_exists() {
            return Ok(Vec::new());
        }

        let output = Command::new("tmux")
            .args([
                "list-windows",
                "-t",
                &self.session_name,
                "-F",
                "#{window_name}",
            ])
            .output()
            .context("Failed to list tmux windows")?;

        if !output.status.success() {
            return Ok(Vec::new());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        Ok(stdout.lines().map(|s| s.to_string()).collect())
    }

    /// Attach to the session
    pub fn attach(&self, window: Option<&str>) -> Result<()> {
        let mut args = vec!["attach-session", "-t"];

        let target = if let Some(w) = window {
            format!("{}:{}", self.session_name, w)
        } else {
            self.session_name.clone()
        };

        args.push(&target);

        // Use exec to replace the current process
        let status = Command::new("tmux")
            .args(&args)
            .status()
            .context("Failed to attach to tmux session")?;

        if !status.success() {
            return Err(anyhow!("Failed to attach to tmux session"));
        }

        Ok(())
    }

    /// Get the session name
    pub fn session_name(&self) -> &str {
        &self.session_name
    }
}
