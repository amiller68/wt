use anyhow::Result;

use crate::cli::{BaseArgs, ConfigArgs, ConfigCommands, OnCreateArgs};
use crate::core::config::GlobalConfig;
use crate::output::table;

use super::get_worktree;

pub fn run(args: ConfigArgs) -> Result<()> {
    match args.command {
        Some(ConfigCommands::Show) | None => show_config(),
        Some(ConfigCommands::Base(base_args)) => set_base(base_args),
        Some(ConfigCommands::OnCreate(hook_args)) => set_on_create(hook_args),
        Some(ConfigCommands::List) => list_config(),
    }
}

fn show_config() -> Result<()> {
    let wt = get_worktree()?;
    let config = wt.config();

    eprintln!("Repository: {}", wt.repo_root().display());
    eprintln!("Base branch: {}", config.base_branch());
    eprintln!("Worktree dir: {}", config.worktree_dir().display());

    if let Some(hook) = config.on_create_hook() {
        eprintln!("On-create hook: {}", hook);
    }

    if let Some(adapter) = config.wt_toml.adapter() {
        eprintln!("\nAgent adapter: {}", config.wt_toml.agent.agent_type);
        eprintln!("  Command: {}", adapter.command);
        eprintln!("  Skills dir: {}", adapter.skills_dir);
    }

    Ok(())
}

fn set_base(args: BaseArgs) -> Result<()> {
    let mut global = GlobalConfig::load()?;

    if let Some(branch) = args.branch {
        if args.global {
            global.set_default_base(&branch);
            global.save()?;
            table::success(&format!("Set global default base branch to '{}'", branch));
        } else {
            let wt = get_worktree()?;
            global.set_repo_base(wt.repo_root(), &branch);
            global.save()?;
            table::success(&format!(
                "Set base branch for {} to '{}'",
                wt.repo_root().display(),
                branch
            ));
        }
    } else {
        // Show current base
        if args.global {
            if let Some(branch) = global.default_base() {
                eprintln!("Global default base: {}", branch);
            } else {
                eprintln!("No global default base set (using 'main')");
            }
        } else {
            let wt = get_worktree()?;
            eprintln!("Base branch: {}", wt.config().base_branch());
        }
    }

    Ok(())
}

fn set_on_create(args: OnCreateArgs) -> Result<()> {
    let wt = get_worktree()?;
    let mut global = GlobalConfig::load()?;

    if args.unset {
        global.remove_on_create_hook(wt.repo_root());
        global.save()?;
        table::success("Removed on-create hook");
    } else if let Some(command) = args.command {
        global.set_on_create_hook(wt.repo_root(), &command);
        global.save()?;
        table::success(&format!("Set on-create hook to: {}", command));
    } else {
        // Show current hook
        if let Some(hook) = wt.config().on_create_hook() {
            eprintln!("On-create hook: {}", hook);
        } else {
            eprintln!("No on-create hook configured");
        }
    }

    Ok(())
}

fn list_config() -> Result<()> {
    let global = GlobalConfig::load()?;

    if global.all().is_empty() {
        eprintln!("No configuration set");
    } else {
        for (key, value) in global.all() {
            println!("{}={}", key, value);
        }
    }

    Ok(())
}
