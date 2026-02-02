mod cli;
mod commands;
mod core;
mod output;
mod protocol;

use anyhow::Result;
use clap::Parser;

use cli::{Cli, Commands};

fn main() -> Result<()> {
    let cli = Cli::parse();

    // Handle shell integration: some commands output cd commands for eval
    let result = match cli.command {
        Commands::Create(args) => commands::create::run(args),
        Commands::Open(args) => commands::open::run(args),
        Commands::List(args) => commands::list::run(args),
        Commands::Remove(args) => commands::remove::run(args),
        Commands::Exit(args) => commands::exit::run(args),
        Commands::Config(args) => commands::config::run(args),
        Commands::Spawn(args) => commands::spawn::run(args),
        Commands::Ps => commands::ps::run(),
        Commands::Status => commands::status::run(),
        Commands::Attach(args) => commands::attach::run(args),
        Commands::Kill(args) => commands::kill::run(args),
        Commands::Review(args) => commands::review::run(args),
        Commands::Merge(args) => commands::merge::run(args),
        Commands::Init(args) => commands::init::run(args),
        Commands::Health => commands::health::run(),
        Commands::Update(args) => commands::update::run(args),
        Commands::Version => commands::version::run(),
        Commands::Which => commands::which::run(),
        Commands::Completions(args) => commands::completions::run(args),
    };

    if let Err(e) = result {
        eprintln!("{}: {}", console::style("error").red().bold(), e);
        std::process::exit(1);
    }

    Ok(())
}
