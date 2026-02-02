use colored::Colorize;

use crate::error::Result;
use crate::spawn;

pub fn run(name: &str) -> Result<()> {
    // Kill tmux window
    spawn::kill_window(name)?;

    // Unregister from spawn state
    spawn::unregister(name)?;

    eprintln!("{} Killed session '{}'", "✓".green(), name.cyan());

    Ok(())
}
