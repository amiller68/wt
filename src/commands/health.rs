use anyhow::Result;
use std::path::Path;
use std::process::Command;

use crate::output::table;

use super::get_worktree;

pub fn run() -> Result<()> {
    eprintln!("wt v{}", env!("CARGO_PKG_VERSION"));
    eprintln!();

    // System checks
    eprintln!("System");
    check_command("git", &["--version"])?;
    check_command("tmux", &["-V"])?;
    check_command("claude", &["--version"])?;

    eprintln!();

    // Repository checks
    match get_worktree() {
        Ok(wt) => {
            let repo_name = wt
                .repo_root()
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("unknown");

            eprintln!("Repository: {}", repo_name);
            check_file(wt.repo_root(), "wt.toml")?;
            eprintln!("  {} Base branch: {}", console::style("✓").green(), wt.config().base_branch());
            eprintln!(
                "  {} Agent: {}",
                console::style("✓").green(),
                wt.config().wt_toml.agent.agent_type
            );

            eprintln!();
            eprintln!("Claude Code Configuration");
            check_file(wt.repo_root(), "CLAUDE.md")?;
            check_file(wt.repo_root(), ".claude/settings.json")?;

            eprintln!();
            eprintln!("  Skills (.claude/skills/)");
            let skills = ["wt", "docs", "issues", "draft", "review"];
            for skill in &skills {
                let path = format!(".claude/skills/{}/SKILL.md", skill);
                check_file_indent(wt.repo_root(), &path, 4)?;
            }

            eprintln!();
            eprintln!("  Documentation");
            check_file_indent(wt.repo_root(), "docs/product.md", 4)?;
            check_file_indent(wt.repo_root(), "docs/contributing.md", 4)?;
            check_file_indent(wt.repo_root(), "issues/_template.md", 4)?;

            // Check for any missing files
            let missing: Vec<_> = [
                "wt.toml",
                "CLAUDE.md",
                ".claude/settings.json",
                ".claude/skills/wt/SKILL.md",
                ".claude/skills/docs/SKILL.md",
                ".claude/skills/issues/SKILL.md",
                ".claude/skills/draft/SKILL.md",
                ".claude/skills/review/SKILL.md",
            ]
            .iter()
            .filter(|p| !wt.repo_root().join(p).exists())
            .collect();

            if !missing.is_empty() {
                eprintln!();
                table::warn("Some files missing. Run: wt init --fix");
            }
        }
        Err(_) => {
            eprintln!("Repository: not in a git repository");
        }
    }

    Ok(())
}

fn check_command(name: &str, args: &[&str]) -> Result<()> {
    match Command::new(name).args(args).output() {
        Ok(output) if output.status.success() => {
            let version = String::from_utf8_lossy(&output.stdout)
                .lines()
                .next()
                .unwrap_or("")
                .trim()
                .to_string();
            // Extract just the version number if possible
            let version = version
                .split_whitespace()
                .find(|s| s.chars().next().map(|c| c.is_ascii_digit()).unwrap_or(false))
                .unwrap_or(&version);
            eprintln!("  {} {} {}", console::style("✓").green(), name, version);
        }
        _ => {
            eprintln!(
                "  {} {} (not found)",
                console::style("✗").red(),
                name
            );
        }
    }
    Ok(())
}

fn check_file(root: &Path, path: &str) -> Result<()> {
    check_file_indent(root, path, 2)
}

fn check_file_indent(root: &Path, path: &str, indent: usize) -> Result<()> {
    let full_path = root.join(path);
    let spaces = " ".repeat(indent);
    if full_path.exists() {
        eprintln!("{}{} {}", spaces, console::style("✓").green(), path);
    } else {
        eprintln!("{}{} {} (missing)", spaces, console::style("✗").red(), path);
    }
    Ok(())
}
