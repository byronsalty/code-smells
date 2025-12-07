use crate::cli::{OutputFormat, SeverityFilter};
use crate::languages::LanguageType;
use serde::Serialize;
use std::path::{Path, PathBuf};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Severity {
    Warning,
    Error,
}

#[derive(Debug, Serialize)]
pub struct Issue {
    pub severity: Severity,
    #[serde(serialize_with = "serialize_path")]
    pub file: PathBuf,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub line: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(rename = "type")]
    pub check_type: &'static str,
    pub value: usize,
    pub limit: usize,
    #[serde(skip)]
    pub message: String,
}

fn serialize_path<S>(path: &PathBuf, s: S) -> Result<S::Ok, S::Error>
where
    S: serde::Serializer,
{
    s.serialize_str(&path.display().to_string())
}

#[derive(Default)]
pub struct Report {
    pub issues: Vec<Issue>,
    pub files_scanned: usize,
}

impl Report {
    pub fn error_count(&self) -> usize {
        self.issues
            .iter()
            .filter(|i| i.severity == Severity::Error)
            .count()
    }

    pub fn warning_count(&self) -> usize {
        self.issues
            .iter()
            .filter(|i| i.severity == Severity::Warning)
            .count()
    }

    pub fn exit_code(&self) -> i32 {
        if self.error_count() > 0 {
            2
        } else if self.warning_count() > 0 {
            1
        } else {
            0
        }
    }

    pub fn add_issue(&mut self, issue: Issue) {
        self.issues.push(issue);
    }
}

// ANSI color codes
const RED: &str = "\x1b[0;31m";
const YELLOW: &str = "\x1b[1;33m";
const GREEN: &str = "\x1b[0;32m";
const BOLD: &str = "\x1b[1m";
const RESET: &str = "\x1b[0m";

fn is_terminal() -> bool {
    std::io::IsTerminal::is_terminal(&std::io::stdout())
}

pub fn print_report(
    report: &Report,
    project_dir: &Path,
    languages: &[LanguageType],
    format: OutputFormat,
    filter: SeverityFilter,
) {
    match format {
        OutputFormat::Text => print_text_report(report, project_dir, languages, filter),
        OutputFormat::Json => print_json_report(report, project_dir, languages),
    }
}

fn print_text_report(
    report: &Report,
    project_dir: &Path,
    languages: &[LanguageType],
    filter: SeverityFilter,
) {
    let use_color = is_terminal();
    let (bold, reset, red, yellow, green) = if use_color {
        (BOLD, RESET, RED, YELLOW, GREEN)
    } else {
        ("", "", "", "", "")
    };

    // Header
    println!("{}=== Code Smells Report ==={}", bold, reset);
    println!("Project: {}", project_dir.display());
    let lang_names: Vec<&str> = languages.iter().map(|l| l.name()).collect();
    println!("Languages: {}", lang_names.join(", "));

    // Collect errors and warnings
    let errors: Vec<&Issue> = report
        .issues
        .iter()
        .filter(|i| i.severity == Severity::Error)
        .collect();
    let warnings: Vec<&Issue> = report
        .issues
        .iter()
        .filter(|i| i.severity == Severity::Warning)
        .collect();

    // Print errors
    if !matches!(filter, SeverityFilter::WarningsOnly) && !errors.is_empty() {
        println!();
        println!("{}--- ERRORS ({}) ---{}", bold, errors.len(), reset);
        for issue in &errors {
            println!("{}ERROR{}  {}", red, reset, issue.message);
        }
    }

    // Print warnings
    if !matches!(filter, SeverityFilter::ErrorsOnly) && !warnings.is_empty() {
        println!();
        println!("{}--- WARNINGS ({}) ---{}", bold, warnings.len(), reset);
        for issue in &warnings {
            println!("{}WARN{}   {}", yellow, reset, issue.message);
        }
    }

    // Summary
    println!();
    println!("{}--- SUMMARY ---{}", bold, reset);
    println!("Files scanned: {}", report.files_scanned);
    if report.error_count() > 0 {
        println!("Errors: {}{}{}", red, report.error_count(), reset);
    } else {
        println!("Errors: {}0{}", green, reset);
    }
    if report.warning_count() > 0 {
        println!("Warnings: {}{}{}", yellow, report.warning_count(), reset);
    } else {
        println!("Warnings: {}0{}", green, reset);
    }
}

#[derive(Serialize)]
struct JsonReport<'a> {
    project: String,
    languages: Vec<&'a str>,
    issues: &'a [Issue],
    summary: JsonSummary,
}

#[derive(Serialize)]
struct JsonSummary {
    files: usize,
    errors: usize,
    warnings: usize,
}

fn print_json_report(report: &Report, project_dir: &Path, languages: &[LanguageType]) {
    let json_report = JsonReport {
        project: project_dir.display().to_string(),
        languages: languages.iter().map(|l| l.name()).collect(),
        issues: &report.issues,
        summary: JsonSummary {
            files: report.files_scanned,
            errors: report.error_count(),
            warnings: report.warning_count(),
        },
    };

    println!("{}", serde_json::to_string_pretty(&json_report).unwrap());
}
