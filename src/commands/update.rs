use anyhow::{anyhow, Context, Result};
use std::fs;
use std::process::Command;

use crate::cli::UpdateArgs;
use crate::output::table;

const RELEASES_URL: &str = "https://github.com/amiller68/wt/releases";

pub fn run(args: UpdateArgs) -> Result<()> {
    let current_version = env!("CARGO_PKG_VERSION");
    table::info(&format!("Current version: {}", current_version));

    // Get the latest release from GitHub
    table::info("Checking for updates...");

    let latest = get_latest_release()?;

    if !args.force && latest == current_version {
        table::success("Already at latest version");
        return Ok(());
    }

    if !args.force && compare_versions(current_version, &latest)? >= 0 {
        table::success(&format!(
            "Already at latest version (current: {}, latest: {})",
            current_version, latest
        ));
        return Ok(());
    }

    table::info(&format!("New version available: {}", latest));

    // Download and install
    let target = get_target()?;
    let download_url = format!(
        "{}/download/v{}/wt-{}-{}.tar.gz",
        RELEASES_URL, latest, latest, target
    );

    table::info(&format!("Downloading from {}", download_url));

    // Download to temp file
    let temp_dir = std::env::temp_dir().join("wt-update");
    fs::create_dir_all(&temp_dir)?;
    let archive_path = temp_dir.join("wt.tar.gz");

    download_file(&download_url, &archive_path)?;

    // Extract
    let output = Command::new("tar")
        .args(["xzf", archive_path.to_str().unwrap()])
        .current_dir(&temp_dir)
        .output()
        .context("Failed to extract archive")?;

    if !output.status.success() {
        return Err(anyhow!("Failed to extract archive"));
    }

    // Find the binary
    let binary_path = temp_dir.join("wt");
    if !binary_path.exists() {
        return Err(anyhow!("Binary not found in archive"));
    }

    // Replace current binary
    let current_exe = std::env::current_exe()?;
    let backup_path = current_exe.with_extension("old");

    // Backup current
    if current_exe.exists() {
        fs::rename(&current_exe, &backup_path).context("Failed to backup current binary")?;
    }

    // Copy new binary
    match fs::copy(&binary_path, &current_exe) {
        Ok(_) => {
            // Make executable
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut perms = fs::metadata(&current_exe)?.permissions();
                perms.set_mode(0o755);
                fs::set_permissions(&current_exe, perms)?;
            }

            // Remove backup
            fs::remove_file(&backup_path).ok();

            table::success(&format!("Updated to version {}", latest));
        }
        Err(e) => {
            // Restore backup
            if backup_path.exists() {
                fs::rename(&backup_path, &current_exe).ok();
            }
            return Err(e.into());
        }
    }

    // Cleanup
    fs::remove_dir_all(&temp_dir).ok();

    Ok(())
}

fn get_latest_release() -> Result<String> {
    // Use GitHub API to get latest release
    let output = Command::new("curl")
        .args([
            "-sL",
            "-H",
            "Accept: application/vnd.github.v3+json",
            "https://api.github.com/repos/amiller68/wt/releases/latest",
        ])
        .output()
        .context("Failed to check for updates")?;

    if !output.status.success() {
        return Err(anyhow!("Failed to check for updates"));
    }

    let response: serde_json::Value = serde_json::from_slice(&output.stdout)?;
    let tag = response["tag_name"]
        .as_str()
        .ok_or_else(|| anyhow!("Invalid release response"))?;

    // Remove 'v' prefix if present
    Ok(tag.trim_start_matches('v').to_string())
}

fn get_target() -> Result<String> {
    let arch = std::env::consts::ARCH;
    let os = std::env::consts::OS;

    let target = match (os, arch) {
        ("macos", "x86_64") => "x86_64-apple-darwin",
        ("macos", "aarch64") => "aarch64-apple-darwin",
        ("linux", "x86_64") => "x86_64-unknown-linux-gnu",
        ("linux", "aarch64") => "aarch64-unknown-linux-gnu",
        _ => return Err(anyhow!("Unsupported platform: {}-{}", os, arch)),
    };

    Ok(target.to_string())
}

fn download_file(url: &str, path: &std::path::Path) -> Result<()> {
    let output = Command::new("curl")
        .args(["-sL", "-o", path.to_str().unwrap(), url])
        .output()
        .context("Failed to download file")?;

    if !output.status.success() {
        return Err(anyhow!("Download failed"));
    }

    Ok(())
}

fn compare_versions(a: &str, b: &str) -> Result<i32> {
    let parse = |v: &str| -> Vec<u32> {
        v.split('.')
            .filter_map(|s| s.parse().ok())
            .collect()
    };

    let a_parts = parse(a);
    let b_parts = parse(b);

    for i in 0..3 {
        let a_val = a_parts.get(i).copied().unwrap_or(0);
        let b_val = b_parts.get(i).copied().unwrap_or(0);
        if a_val > b_val {
            return Ok(1);
        }
        if a_val < b_val {
            return Ok(-1);
        }
    }

    Ok(0)
}
