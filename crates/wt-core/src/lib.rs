//! wt-core - Core library for wt
//!
//! This crate provides the core functionality for wt:
//! - Git worktree operations
//! - Configuration management
//! - Worker state management
//! - Tmux session handling
//! - Orchestrator state persistence

pub mod config;
pub mod error;
pub mod git;
pub mod session;
pub mod spawn;
pub mod state;
pub mod terminal;
pub mod worker;
pub mod worktree;

pub use config::{Config, RepoConfig, WtToml};
pub use error::{Error, Result};
pub use state::OrchestratorState;
pub use worker::{DiffStats, FileDiff, TaskContext, Worker, WorkerId, WorkerStatus};
pub use worktree::Worktree;
