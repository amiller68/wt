use anyhow::Result;
use serde::Serialize;

use crate::cli::ListArgs;
use crate::output::Table;

use super::get_worktree;

#[derive(Serialize)]
struct WorktreeJson {
    name: String,
    path: String,
    branch: String,
    dirty: bool,
}

pub fn run(args: ListArgs) -> Result<()> {
    let wt = get_worktree()?;

    if args.all {
        // Show all git worktrees
        let worktrees = wt.git().list_worktrees()?;

        if args.json {
            let json: Vec<_> = worktrees
                .iter()
                .map(|w| serde_json::json!({
                    "path": w.path.display().to_string(),
                    "branch": w.branch,
                    "head": w.head,
                    "bare": w.bare,
                }))
                .collect();
            println!("{}", serde_json::to_string_pretty(&json)?);
        } else {
            let mut table = Table::new(vec!["Path", "Branch"]);
            for entry in &worktrees {
                table.add_row(vec![
                    entry.path.display().to_string(),
                    entry.branch.clone(),
                ]);
            }

            if table.is_empty() {
                eprintln!("No worktrees found");
            } else {
                table.print();
            }
        }
    } else {
        // Show only worktrees in .worktrees/
        let worktrees = wt.list()?;

        if args.json {
            let json: Vec<_> = worktrees
                .iter()
                .map(|w| WorktreeJson {
                    name: w.name.clone(),
                    path: w.path.display().to_string(),
                    branch: w.branch.clone(),
                    dirty: w.is_dirty,
                })
                .collect();
            println!("{}", serde_json::to_string_pretty(&json)?);
        } else {
            let mut table = Table::new(vec!["Name", "Branch", "Status"]);
            for entry in &worktrees {
                let status = if entry.is_dirty { "dirty" } else { "clean" };
                table.add_row(vec![
                    entry.name.clone(),
                    entry.branch.clone(),
                    status.to_string(),
                ]);
            }

            if table.is_empty() {
                eprintln!("No worktrees found in .worktrees/");
                eprintln!("Use 'wt create <name>' to create one");
            } else {
                table.print();
            }
        }
    }

    Ok(())
}
