use crate::error::Result;

pub fn run() -> Result<()> {
    let exe = std::env::current_exe()?;
    println!("{}", exe.display());
    Ok(())
}
