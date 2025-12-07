use crate::config::Thresholds;
use crate::languages::{FunctionInfo, LanguageType};
use crate::output::{Issue, Report, Severity};
use std::fs;
use std::path::Path;
use walkdir::WalkDir;

/// Check file lengths in a directory for a given language
pub fn check_file_length(
    source_dir: &Path,
    lang: LanguageType,
    thresholds: &Thresholds,
    report: &mut Report,
) {
    let parser = crate::languages::get_parser(lang);
    let extensions = lang.extensions();

    for entry in WalkDir::new(source_dir)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
    {
        let path = entry.path();

        // Check extension
        let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
        if !extensions.contains(&ext) {
            continue;
        }

        // Check if should skip
        if parser.should_skip(path) {
            continue;
        }

        report.files_scanned += 1;

        // Count lines
        let content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(_) => continue,
        };

        let line_count = content.lines().count();
        let rel_path = path.strip_prefix(source_dir).unwrap_or(path);

        if line_count > thresholds.file_error {
            report.add_issue(Issue {
                severity: Severity::Error,
                file: rel_path.to_path_buf(),
                line: None,
                name: None,
                check_type: "file-length",
                value: line_count,
                limit: thresholds.file_error,
                message: format!(
                    "{} ({} lines, limit: {})",
                    rel_path.display(),
                    line_count,
                    thresholds.file_error
                ),
            });
        } else if line_count > thresholds.file_warn {
            report.add_issue(Issue {
                severity: Severity::Warning,
                file: rel_path.to_path_buf(),
                line: None,
                name: None,
                check_type: "file-length",
                value: line_count,
                limit: thresholds.file_warn,
                message: format!(
                    "{} ({} lines, limit: {})",
                    rel_path.display(),
                    line_count,
                    thresholds.file_warn
                ),
            });
        }
    }
}

/// Check function lengths in a directory for a given language
pub fn check_function_length(
    source_dir: &Path,
    lang: LanguageType,
    thresholds: &Thresholds,
    report: &mut Report,
) {
    let parser = crate::languages::get_parser(lang);
    let extensions = lang.extensions();

    for entry in WalkDir::new(source_dir)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
    {
        let path = entry.path();

        // Check extension
        let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
        if !extensions.contains(&ext) {
            continue;
        }

        // Check if should skip
        if parser.should_skip(path) {
            continue;
        }

        // Parse functions
        let content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(_) => continue,
        };

        let functions = parser.parse_functions(&content);
        let rel_path = path.strip_prefix(source_dir).unwrap_or(path);

        for func in functions {
            check_function(&func, rel_path, thresholds, report);
        }
    }
}

fn check_function(func: &FunctionInfo, rel_path: &Path, thresholds: &Thresholds, report: &mut Report) {
    if func.line_count > thresholds.func_error {
        report.add_issue(Issue {
            severity: Severity::Error,
            file: rel_path.to_path_buf(),
            line: Some(func.start_line),
            name: Some(func.name.clone()),
            check_type: "function-length",
            value: func.line_count,
            limit: thresholds.func_error,
            message: format!(
                "{}:{} {} ({} lines)",
                rel_path.display(),
                func.start_line,
                func.name,
                func.line_count
            ),
        });
    } else if func.line_count > thresholds.func_warn {
        report.add_issue(Issue {
            severity: Severity::Warning,
            file: rel_path.to_path_buf(),
            line: Some(func.start_line),
            name: Some(func.name.clone()),
            check_type: "function-length",
            value: func.line_count,
            limit: thresholds.func_warn,
            message: format!(
                "{}:{} {} ({} lines)",
                rel_path.display(),
                func.start_line,
                func.name,
                func.line_count
            ),
        });
    }
}

/// Check nesting depth in a directory for a given language
pub fn check_nesting_depth(
    source_dir: &Path,
    lang: LanguageType,
    thresholds: &Thresholds,
    report: &mut Report,
) {
    let parser = crate::languages::get_parser(lang);
    let extensions = lang.extensions();

    for entry in WalkDir::new(source_dir)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
    {
        let path = entry.path();

        // Check extension
        let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
        if !extensions.contains(&ext) {
            continue;
        }

        // Check if should skip
        if parser.should_skip(path) {
            continue;
        }

        // Parse functions
        let content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(_) => continue,
        };

        let functions = parser.parse_functions(&content);
        let rel_path = path.strip_prefix(source_dir).unwrap_or(path);

        for func in functions {
            if func.max_nesting > thresholds.nest_error {
                report.add_issue(Issue {
                    severity: Severity::Error,
                    file: rel_path.to_path_buf(),
                    line: Some(func.start_line),
                    name: Some(func.name.clone()),
                    check_type: "nesting-depth",
                    value: func.max_nesting,
                    limit: thresholds.nest_error,
                    message: format!(
                        "{}:{} {} (depth: {})",
                        rel_path.display(),
                        func.start_line,
                        func.name,
                        func.max_nesting
                    ),
                });
            } else if func.max_nesting > thresholds.nest_warn {
                report.add_issue(Issue {
                    severity: Severity::Warning,
                    file: rel_path.to_path_buf(),
                    line: Some(func.start_line),
                    name: Some(func.name.clone()),
                    check_type: "nesting-depth",
                    value: func.max_nesting,
                    limit: thresholds.nest_warn,
                    message: format!(
                        "{}:{} {} (depth: {})",
                        rel_path.display(),
                        func.start_line,
                        func.name,
                        func.max_nesting
                    ),
                });
            }
        }
    }
}
