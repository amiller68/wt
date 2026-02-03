//! wt-tui - Terminal UI for managing Claude Code sessions
//!
//! This provides a visual dashboard for:
//! - Viewing all spawned workers and their status
//! - Attaching to worker sessions
//! - Reviewing diffs
//! - Approving and merging workers

use anyhow::Result;

mod app;
mod ui;

fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive(tracing::Level::WARN.into()),
        )
        .init();

    eprintln!("wt-tui is a placeholder. TUI implementation coming soon.");
    eprintln!();
    eprintln!("For now, use:");
    eprintln!("  wt ps       - show worker status");
    eprintln!("  wt attach   - attach to tmux session");
    eprintln!("  wt review   - review a worker's diff");
    eprintln!("  wt status   - show detailed worker info");

    Ok(())
}
