use anyhow::{anyhow, Result};

use crate::cli::AttachArgs;
use crate::core::Tmux;

pub fn run(args: AttachArgs) -> Result<()> {
    let tmux = Tmux::new();

    if !tmux.session_exists() {
        return Err(anyhow!(
            "No wt session running. Use 'wt spawn' to spawn a worker first."
        ));
    }

    tmux.attach(args.name.as_deref())?;

    Ok(())
}
