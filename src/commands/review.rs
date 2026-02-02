use anyhow::Result;

use crate::cli::ReviewArgs;
use crate::output::table;

use super::get_worktree;

pub fn run(args: ReviewArgs) -> Result<()> {
    let wt = get_worktree()?;
    let entry = wt.get(&args.name)?;
    let base_branch = wt.config().base_branch();

    table::info(&format!(
        "Reviewing '{}' against '{}'",
        args.name, base_branch
    ));

    let diff = wt.git().diff(base_branch, &entry.branch, args.full)?;

    if diff.is_empty() {
        eprintln!("No changes between '{}' and '{}'", entry.branch, base_branch);
    } else {
        println!("{}", diff);
    }

    // Show commit count
    let commits = wt.git().commits_ahead(&entry.branch, base_branch)?;
    if commits > 0 {
        eprintln!();
        eprintln!(
            "{} commit{} ahead of {}",
            commits,
            if commits == 1 { "" } else { "s" },
            base_branch
        );
    }

    Ok(())
}
