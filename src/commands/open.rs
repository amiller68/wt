use anyhow::{anyhow, Result};
use std::process::Command;

use crate::cli::OpenArgs;
use crate::output::table;

use super::get_worktree;

pub fn run(args: OpenArgs) -> Result<()> {
    let wt = get_worktree()?;

    if args.all {
        return open_all_in_tabs(&wt);
    }

    let name = args
        .name
        .ok_or_else(|| anyhow!("Worktree name is required"))?;

    let entry = wt.get(&name)?;

    // Output cd command for shell wrapper to eval
    println!("cd \"{}\"", entry.path.display());

    Ok(())
}

/// Open all worktrees in terminal tabs
fn open_all_in_tabs(wt: &crate::core::Worktree) -> Result<()> {
    let worktrees = wt.list()?;

    if worktrees.is_empty() {
        table::info("No worktrees found");
        return Ok(());
    }

    let terminal = detect_terminal();
    table::info(&format!(
        "Opening {} worktrees in {} tabs",
        worktrees.len(),
        terminal
    ));

    for entry in &worktrees {
        open_in_tab(&terminal, &entry.path.to_string_lossy())?;
    }

    table::success(&format!("Opened {} tabs", worktrees.len()));
    Ok(())
}

/// Detect the current terminal emulator
fn detect_terminal() -> String {
    // Check TERM_PROGRAM first
    if let Ok(term) = std::env::var("TERM_PROGRAM") {
        match term.as_str() {
            "iTerm.app" => return "iterm".to_string(),
            "Apple_Terminal" => return "terminal".to_string(),
            "Ghostty" => return "ghostty".to_string(),
            "WezTerm" => return "wezterm".to_string(),
            _ => {}
        }
    }

    // Check for Kitty
    if std::env::var("KITTY_WINDOW_ID").is_ok() {
        return "kitty".to_string();
    }

    // Check for WezTerm
    if std::env::var("WEZTERM_UNIX_SOCKET").is_ok() {
        return "wezterm".to_string();
    }

    // Check for Alacritty
    if std::env::var("ALACRITTY_WINDOW_ID").is_ok() {
        return "alacritty".to_string();
    }

    "unknown".to_string()
}

/// Open a path in a new terminal tab
fn open_in_tab(terminal: &str, path: &str) -> Result<()> {
    match terminal {
        "iterm" => {
            Command::new("osascript")
                .args([
                    "-e",
                    &format!(
                        r#"tell application "iTerm2"
                            tell current window
                                create tab with default profile
                                tell current session
                                    write text "cd '{}'"
                                end tell
                            end tell
                        end tell"#,
                        path
                    ),
                ])
                .output()?;
        }
        "terminal" => {
            Command::new("osascript")
                .args([
                    "-e",
                    &format!(
                        r#"tell application "Terminal"
                            activate
                            do script "cd '{}'"
                        end tell"#,
                        path
                    ),
                ])
                .output()?;
        }
        "ghostty" => {
            Command::new("ghostty")
                .args(["--new-tab", "--working-directory", path])
                .spawn()?;
        }
        "kitty" => {
            Command::new("kitty")
                .args(["@", "launch", "--type=tab", "--cwd", path])
                .output()?;
        }
        "wezterm" => {
            Command::new("wezterm")
                .args(["cli", "spawn", "--cwd", path])
                .output()?;
        }
        _ => {
            table::warn(&format!(
                "Unknown terminal '{}', cannot open tabs automatically",
                terminal
            ));
        }
    }

    Ok(())
}
