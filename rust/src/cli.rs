use clap::{Parser, ValueEnum};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "code-smells")]
#[command(about = "Detect code smells across multiple programming languages")]
pub struct Cli {
    /// Directory to analyze (default: current directory)
    #[arg(default_value = ".")]
    pub directory: PathBuf,

    /// Check type: all, file-length, functions, nesting
    #[arg(short = 'c', long = "check", default_value = "all")]
    pub check_type: CheckType,

    /// Comma-separated languages (default: auto-detect)
    #[arg(short = 'l', long = "lang")]
    pub languages: Option<String>,

    /// Output format: text, json
    #[arg(short = 'f', long = "format", default_value = "text")]
    pub format: OutputFormat,

    /// Show only errors (no warnings)
    #[arg(short = 'e', long = "errors", conflicts_with = "warnings_only")]
    pub errors_only: bool,

    /// Show only warnings (no errors)
    #[arg(short = 'w', long = "warnings")]
    pub warnings_only: bool,

    /// File length warning threshold
    #[arg(long = "file-warn")]
    pub file_warn: Option<usize>,

    /// File length error threshold
    #[arg(long = "file-error")]
    pub file_error: Option<usize>,

    /// Function length warning threshold
    #[arg(long = "func-warn")]
    pub func_warn: Option<usize>,

    /// Function length error threshold
    #[arg(long = "func-error")]
    pub func_error: Option<usize>,

    /// Nesting depth warning threshold
    #[arg(long = "nest-warn")]
    pub nest_warn: Option<usize>,

    /// Nesting depth error threshold
    #[arg(long = "nest-error")]
    pub nest_error: Option<usize>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, ValueEnum)]
pub enum CheckType {
    All,
    #[value(name = "file-length")]
    FileLength,
    Functions,
    Nesting,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, ValueEnum)]
pub enum OutputFormat {
    Text,
    Json,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SeverityFilter {
    All,
    ErrorsOnly,
    WarningsOnly,
}

impl Cli {
    pub fn severity_filter(&self) -> SeverityFilter {
        if self.errors_only {
            SeverityFilter::ErrorsOnly
        } else if self.warnings_only {
            SeverityFilter::WarningsOnly
        } else {
            SeverityFilter::All
        }
    }
}
