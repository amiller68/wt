use colored::Colorize;

use crate::error::Result;

pub fn run() -> Result<()> {
    eprintln!(
        "{} {}",
        "wt".bold(),
        env!("CARGO_PKG_VERSION").cyan()
    );
    Ok(())
}
