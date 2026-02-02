use comfy_table::{presets::UTF8_FULL_CONDENSED, Cell, Color, ContentArrangement};
use console::style;

use crate::protocol::WorkerStatusValue;

/// Table builder for pretty output
pub struct Table {
    inner: comfy_table::Table,
}

impl Table {
    /// Create a new table with the given headers
    pub fn new(headers: Vec<&str>) -> Self {
        let mut table = comfy_table::Table::new();
        table
            .load_preset(UTF8_FULL_CONDENSED)
            .set_content_arrangement(ContentArrangement::Dynamic);

        table.set_header(headers);

        Self { inner: table }
    }

    /// Add a row to the table
    pub fn add_row(&mut self, cells: Vec<String>) {
        self.inner.add_row(cells);
    }

    /// Add a row with colored status cell
    pub fn add_status_row(&mut self, cells: Vec<String>, status_idx: usize, status: Option<WorkerStatusValue>) {
        let mut row: Vec<Cell> = cells.into_iter().map(Cell::new).collect();

        if let Some(status_val) = status {
            if status_idx < row.len() {
                let color = match status_val {
                    WorkerStatusValue::Working => Color::Blue,
                    WorkerStatusValue::Done => Color::Green,
                    WorkerStatusValue::Blocked => Color::Red,
                    WorkerStatusValue::Question => Color::Yellow,
                };
                row[status_idx] = Cell::new(status_val.to_string()).fg(color);
            }
        }

        self.inner.add_row(row);
    }

    /// Print the table
    pub fn print(&self) {
        println!("{}", self.inner);
    }

    /// Check if the table has any rows
    pub fn is_empty(&self) -> bool {
        self.inner.row_iter().count() == 0
    }
}

/// Print a success message
pub fn success(msg: &str) {
    eprintln!("{} {}", style("✓").green().bold(), msg);
}

/// Print an info message
pub fn info(msg: &str) {
    eprintln!("{} {}", style("→").blue(), msg);
}

/// Print a warning message
pub fn warn(msg: &str) {
    eprintln!("{} {}", style("!").yellow().bold(), msg);
}

/// Print an error message
pub fn error(msg: &str) {
    eprintln!("{} {}", style("✗").red().bold(), msg);
}

/// Format a diff stat line
pub fn diff_stat(additions: usize, deletions: usize) -> String {
    if additions == 0 && deletions == 0 {
        "—".to_string()
    } else {
        format!(
            "{}{}{}",
            style(format!("+{}", additions)).green(),
            " ",
            style(format!("-{}", deletions)).red()
        )
    }
}

/// Format age from a timestamp
pub fn format_age(timestamp: chrono::DateTime<chrono::Utc>) -> String {
    let now = chrono::Utc::now();
    let duration = now.signed_duration_since(timestamp);

    if duration.num_days() > 0 {
        format!("{}d", duration.num_days())
    } else if duration.num_hours() > 0 {
        format!("{}h", duration.num_hours())
    } else if duration.num_minutes() > 0 {
        format!("{}m", duration.num_minutes())
    } else {
        "now".to_string()
    }
}
