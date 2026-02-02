use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

use crate::cli::InitArgs;
use crate::output::table;

use super::get_worktree;

/// Templates embedded at compile time
mod templates {
    pub const WT_TOML: &str = include_str!("../../templates/wt.toml");
    pub const CLAUDE_MD: &str = include_str!("../../templates/CLAUDE.md");
    pub const CLAUDE_SETTINGS: &str = include_str!("../../templates/claude/settings.json");
    pub const SKILL_WT: &str = include_str!("../../templates/claude/skills/wt/SKILL.md");
    pub const SKILL_DOCS: &str = include_str!("../../templates/claude/skills/docs/SKILL.md");
    pub const SKILL_ISSUES: &str = include_str!("../../templates/claude/skills/issues/SKILL.md");
    pub const SKILL_DRAFT: &str = include_str!("../../templates/claude/skills/draft/SKILL.md");
    pub const SKILL_REVIEW: &str = include_str!("../../templates/claude/skills/review/SKILL.md");
    pub const DOCS_PRODUCT: &str = include_str!("../../templates/docs/product.md");
    pub const DOCS_CONTRIBUTING: &str = include_str!("../../templates/docs/contributing.md");
    pub const ISSUE_TEMPLATE: &str = include_str!("../../templates/issues/_template.md");
}

struct InitFile {
    path: &'static str,
    content: &'static str,
    description: &'static str,
}

const FILES: &[InitFile] = &[
    InitFile {
        path: "wt.toml",
        content: templates::WT_TOML,
        description: "wt configuration",
    },
    InitFile {
        path: "CLAUDE.md",
        content: templates::CLAUDE_MD,
        description: "Claude project context",
    },
    InitFile {
        path: ".claude/settings.json",
        content: templates::CLAUDE_SETTINGS,
        description: "Claude Code settings",
    },
    InitFile {
        path: ".claude/skills/wt/SKILL.md",
        content: templates::SKILL_WT,
        description: "wt worker skill",
    },
    InitFile {
        path: ".claude/skills/docs/SKILL.md",
        content: templates::SKILL_DOCS,
        description: "docs navigation skill",
    },
    InitFile {
        path: ".claude/skills/issues/SKILL.md",
        content: templates::SKILL_ISSUES,
        description: "issues management skill",
    },
    InitFile {
        path: ".claude/skills/draft/SKILL.md",
        content: templates::SKILL_DRAFT,
        description: "PR/commit drafting skill",
    },
    InitFile {
        path: ".claude/skills/review/SKILL.md",
        content: templates::SKILL_REVIEW,
        description: "code review skill",
    },
    InitFile {
        path: "docs/product.md",
        content: templates::DOCS_PRODUCT,
        description: "product documentation",
    },
    InitFile {
        path: "docs/contributing.md",
        content: templates::DOCS_CONTRIBUTING,
        description: "contributing guide",
    },
    InitFile {
        path: "issues/_template.md",
        content: templates::ISSUE_TEMPLATE,
        description: "issue template",
    },
];

pub fn run(args: InitArgs) -> Result<()> {
    let wt = get_worktree()?;
    let repo_root = wt.repo_root();

    // Get project name from directory
    let project_name = repo_root
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("project");

    if args.audit {
        return audit(repo_root);
    }

    table::info(&format!("Initializing wt in {}", repo_root.display()));

    let mut created = 0;
    let mut skipped = 0;
    let mut backed_up = 0;

    for file in FILES {
        let path = repo_root.join(file.path);

        if path.exists() {
            if args.force {
                if args.backup {
                    let backup_path = path.with_extension("bak");
                    fs::copy(&path, &backup_path).context("Failed to backup file")?;
                    backed_up += 1;
                    eprintln!(
                        "  {} {} (backed up)",
                        console::style("↻").yellow(),
                        file.path
                    );
                } else {
                    eprintln!(
                        "  {} {} (overwriting)",
                        console::style("↻").yellow(),
                        file.path
                    );
                }
            } else if args.fix {
                eprintln!(
                    "  {} {} (exists)",
                    console::style("✓").green(),
                    file.path
                );
                skipped += 1;
                continue;
            } else {
                eprintln!(
                    "  {} {} (exists, use --force to overwrite)",
                    console::style("·").dim(),
                    file.path
                );
                skipped += 1;
                continue;
            }
        }

        // Create parent directories
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).context("Failed to create directories")?;
        }

        // Substitute variables in content
        let content = file
            .content
            .replace("{project_name}", project_name)
            .replace("{PROJECT_NAME}", &project_name.to_uppercase());

        fs::write(&path, content).context("Failed to write file")?;
        eprintln!("  {} {} ({})", console::style("+").green(), file.path, file.description);
        created += 1;
    }

    eprintln!();
    if created > 0 {
        table::success(&format!("Created {} files", created));
    }
    if skipped > 0 {
        eprintln!("  Skipped {} existing files", skipped);
    }
    if backed_up > 0 {
        eprintln!("  Backed up {} files", backed_up);
    }

    if created > 0 {
        eprintln!();
        eprintln!("Next steps:");
        eprintln!("  1. Review and customize wt.toml");
        eprintln!("  2. Update CLAUDE.md with project-specific instructions");
        eprintln!("  3. Fill in docs/product.md with project context");
        eprintln!("  4. Run 'wt health' to verify setup");
    }

    Ok(())
}

fn audit(repo_root: &Path) -> Result<()> {
    table::info("Auditing wt configuration...");
    eprintln!();

    let mut missing = 0;
    let mut present = 0;

    for file in FILES {
        let path = repo_root.join(file.path);
        if path.exists() {
            eprintln!(
                "  {} {} ({})",
                console::style("✓").green(),
                file.path,
                file.description
            );
            present += 1;
        } else {
            eprintln!(
                "  {} {} ({})",
                console::style("✗").red(),
                file.path,
                file.description
            );
            missing += 1;
        }
    }

    eprintln!();
    if missing == 0 {
        table::success("All files present");
    } else {
        eprintln!(
            "{} file{} missing. Run 'wt init --fix' to add them.",
            missing,
            if missing == 1 { "" } else { "s" }
        );
    }

    Ok(())
}
