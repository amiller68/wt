use anyhow::Result;

pub fn run() -> Result<()> {
    println!("wt {}", env!("CARGO_PKG_VERSION"));
    Ok(())
}
