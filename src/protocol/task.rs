use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

/// Task file (.wt/task.md)
pub struct TaskFile {
    pub issue: Option<String>,
    pub description: String,
    pub acceptance_criteria: Vec<String>,
    pub context: Option<String>,
    pub constraints: Vec<String>,
}

impl TaskFile {
    /// Create a new task file
    pub fn new(description: &str) -> Self {
        Self {
            issue: None,
            description: description.to_string(),
            acceptance_criteria: Vec::new(),
            context: None,
            constraints: vec![
                "Stay focused on this task".to_string(),
                "Update `.wt/status.json` when blocked or done".to_string(),
                "See `.claude/skills/wt/` for the worker protocol".to_string(),
            ],
        }
    }

    /// Set the issue reference
    pub fn with_issue(mut self, issue: &str) -> Self {
        self.issue = Some(issue.to_string());
        self
    }

    /// Set acceptance criteria
    pub fn with_criteria(mut self, criteria: Vec<String>) -> Self {
        self.acceptance_criteria = criteria;
        self
    }

    /// Set additional context
    pub fn with_context(mut self, context: &str) -> Self {
        self.context = Some(context.to_string());
        self
    }

    /// Render to markdown
    pub fn render(&self) -> String {
        let mut lines = vec!["# Task".to_string(), String::new()];

        if let Some(issue) = &self.issue {
            lines.push(format!("## Issue\n\n{}\n", issue));
        }

        lines.push(format!("## Description\n\n{}\n", self.description));

        if !self.acceptance_criteria.is_empty() {
            lines.push("## Acceptance Criteria\n".to_string());
            for criterion in &self.acceptance_criteria {
                lines.push(format!("- [ ] {}", criterion));
            }
            lines.push(String::new());
        }

        if let Some(context) = &self.context {
            lines.push(format!("## Context\n\n{}\n", context));
        }

        if !self.constraints.is_empty() {
            lines.push("## Constraints\n".to_string());
            for constraint in &self.constraints {
                lines.push(format!("- {}", constraint));
            }
            lines.push(String::new());
        }

        lines.join("\n")
    }

    /// Save to a worktree directory
    pub fn save(&self, worktree_path: &Path) -> Result<()> {
        let wt_dir = worktree_path.join(".wt");
        fs::create_dir_all(&wt_dir).context("Failed to create .wt directory")?;

        let path = wt_dir.join("task.md");
        fs::write(&path, self.render()).context("Failed to write task.md")?;
        Ok(())
    }

    /// Load from a worktree directory
    pub fn load(worktree_path: &Path) -> Result<Option<String>> {
        let path = worktree_path.join(".wt/task.md");
        if !path.exists() {
            return Ok(None);
        }
        let content = fs::read_to_string(&path).context("Failed to read task.md")?;
        Ok(Some(content))
    }
}
