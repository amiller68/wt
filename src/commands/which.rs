use anyhow::Result;

pub fn run() -> Result<()> {
    if let Ok(exe) = std::env::current_exe() {
        println!("{}", exe.display());
    }
    Ok(())
}
