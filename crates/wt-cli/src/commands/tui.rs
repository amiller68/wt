//! Launch the terminal UI

use anyhow::Result;
use std::process::Command;

pub fn run() -> Result<()> {
    // Try to find and launch wt-tui
    let status = Command::new("wt-tui").status();

    match status {
        Ok(exit_status) => {
            if !exit_status.success() {
                std::process::exit(exit_status.code().unwrap_or(1));
            }
            Ok(())
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            eprintln!("wt-tui is not installed.");
            eprintln!();
            eprintln!("Install it with:");
            eprintln!("  cargo install wt-tui");
            std::process::exit(1);
        }
        Err(e) => Err(e.into()),
    }
}
