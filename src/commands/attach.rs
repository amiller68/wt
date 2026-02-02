use crate::error::Result;
use crate::spawn;

pub fn run(name: Option<&str>) -> Result<()> {
    spawn::attach(name)
}
