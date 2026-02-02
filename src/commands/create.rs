use anyhow::Result;

use crate::cli::CreateArgs;
use crate::output::table;

use super::get_worktree;

pub fn run(args: CreateArgs) -> Result<()> {
    let wt = get_worktree()?;

    table::info(&format!("Creating worktree '{}'", args.name));

    let worktree_path = wt.create(&args.name, args.branch.as_deref())?;

    // Run on-create hook if configured and not skipped
    if !args.no_hooks {
        wt.run_on_create_hook(&worktree_path)?;
    }

    table::success(&format!("Created worktree at {}", worktree_path.display()));

    // If --open flag is set, output the cd command for shell wrapper to eval
    if args.open {
        // This goes to stdout so the shell wrapper can eval it
        println!("cd \"{}\"", worktree_path.display());
    }

    Ok(())
}
