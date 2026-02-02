use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "wt")]
#[command(author, version, about = "Agent-agnostic git worktree orchestration")]
#[command(propagate_version = true)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Create a new worktree with a new branch
    Create(CreateArgs),

    /// Open (cd into) an existing worktree
    Open(OpenArgs),

    /// List worktrees
    List(ListArgs),

    /// Remove worktree(s), supports glob patterns
    Remove(RemoveArgs),

    /// Exit current worktree and remove it
    Exit(ExitArgs),

    /// Show or set configuration
    Config(ConfigArgs),

    /// Create worktree and launch agent in tmux
    Spawn(SpawnArgs),

    /// Show spawned sessions (alias for status)
    Ps,

    /// Show worker status across worktrees
    Status,

    /// Attach to tmux session
    Attach(AttachArgs),

    /// Kill tmux window for a worker
    Kill(KillArgs),

    /// Show diff for review
    Review(ReviewArgs),

    /// Merge worktree into current branch
    Merge(MergeArgs),

    /// Initialize repository with wt scaffolding
    Init(InitArgs),

    /// Check system health and dependencies
    Health,

    /// Self-update wt
    Update(UpdateArgs),

    /// Show version
    Version,

    /// Show path to wt binary
    Which,

    /// Generate shell completions
    Completions(CompletionsArgs),
}

#[derive(Parser)]
pub struct CreateArgs {
    /// Name for the worktree (creates branch with same name)
    pub name: String,

    /// Base branch to create from (defaults to configured base)
    #[arg(short, long)]
    pub branch: Option<String>,

    /// Open (cd into) the worktree after creation
    #[arg(short, long)]
    pub open: bool,

    /// Skip on-create hook execution
    #[arg(long)]
    pub no_hooks: bool,
}

#[derive(Parser)]
pub struct OpenArgs {
    /// Name of the worktree to open
    pub name: Option<String>,

    /// Open all worktrees in terminal tabs
    #[arg(long)]
    pub all: bool,
}

#[derive(Parser)]
pub struct ListArgs {
    /// Show all git worktrees (not just .worktrees/)
    #[arg(short, long)]
    pub all: bool,

    /// Output as JSON
    #[arg(long)]
    pub json: bool,
}

#[derive(Parser)]
pub struct RemoveArgs {
    /// Pattern to match worktree names (supports * and ? globs)
    pub pattern: String,

    /// Remove without confirmation
    #[arg(short, long)]
    pub force: bool,

    /// Remove worktree and all its children (for hierarchical worktrees)
    #[arg(short, long)]
    pub recursive: bool,
}

#[derive(Parser)]
pub struct ExitArgs {
    /// Force exit even with uncommitted changes
    #[arg(short, long)]
    pub force: bool,
}

#[derive(Parser)]
pub struct ConfigArgs {
    #[command(subcommand)]
    pub command: Option<ConfigCommands>,
}

#[derive(Subcommand)]
pub enum ConfigCommands {
    /// Show current configuration
    Show,

    /// Set or show the base branch
    Base(BaseArgs),

    /// Set or show the on-create hook
    OnCreate(OnCreateArgs),

    /// List all configuration
    List,
}

#[derive(Parser)]
pub struct BaseArgs {
    /// Branch name to set as base
    pub branch: Option<String>,

    /// Set globally instead of per-repo
    #[arg(short, long)]
    pub global: bool,
}

#[derive(Parser)]
pub struct OnCreateArgs {
    /// Command to run after worktree creation
    pub command: Option<String>,

    /// Remove the on-create hook
    #[arg(long)]
    pub unset: bool,
}

#[derive(Parser)]
pub struct SpawnArgs {
    /// Name for the worktree/worker
    pub name: String,

    /// Context/instructions for the worker
    #[arg(short, long)]
    pub context: Option<String>,

    /// Issue ID to work on
    #[arg(short, long)]
    pub issue: Option<String>,

    /// Parent worktree for hierarchical spawning
    #[arg(short, long)]
    pub parent: Option<String>,

    /// Enable auto mode (skip permissions)
    #[arg(short, long)]
    pub auto: bool,
}

#[derive(Parser)]
pub struct AttachArgs {
    /// Name of the worktree to attach to
    pub name: Option<String>,
}

#[derive(Parser)]
pub struct KillArgs {
    /// Name of the worktree to kill
    pub name: String,
}

#[derive(Parser)]
pub struct ReviewArgs {
    /// Name of the worktree to review
    pub name: String,

    /// Show full diff instead of summary
    #[arg(short, long)]
    pub full: bool,
}

#[derive(Parser)]
pub struct MergeArgs {
    /// Name of the worktree to merge
    pub name: String,

    /// Delete the worktree after merging
    #[arg(short, long)]
    pub delete: bool,
}

#[derive(Parser)]
pub struct InitArgs {
    /// Overwrite existing files
    #[arg(short, long)]
    pub force: bool,

    /// Only add missing pieces
    #[arg(long)]
    pub fix: bool,

    /// Backup existing files before overwriting
    #[arg(long)]
    pub backup: bool,

    /// Show what would be created without making changes
    #[arg(long)]
    pub audit: bool,
}

#[derive(Parser)]
pub struct UpdateArgs {
    /// Force update even if already at latest version
    #[arg(short, long)]
    pub force: bool,
}

#[derive(Parser)]
pub struct CompletionsArgs {
    /// Shell to generate completions for
    #[arg(value_enum)]
    pub shell: clap_complete::Shell,
}
