mod checks;
mod cli;
mod config;
mod detect;
mod languages;
mod output;

use clap::Parser;
use cli::{CheckType, Cli};
use config::Thresholds;
use detect::{detect_languages, parse_language_list, DetectedLanguage};
use languages::LanguageType;
use output::Report;
use std::process;

fn main() {
    let cli = Cli::parse();

    // Resolve directory to absolute path
    let project_dir = match cli.directory.canonicalize() {
        Ok(p) => p,
        Err(e) => {
            eprintln!("Error: Cannot access directory '{}': {}", cli.directory.display(), e);
            process::exit(1);
        }
    };

    // Detect or parse languages
    let detected: Vec<DetectedLanguage> = match &cli.languages {
        Some(langs) => parse_language_list(langs),
        None => detect_languages(&project_dir),
    };

    if detected.is_empty() {
        eprintln!("No supported languages detected in {}", project_dir.display());
        eprintln!("Supported: elixir, dart, typescript, python, rust");
        process::exit(1);
    }

    // Collect unique language types for display
    let lang_types: Vec<LanguageType> = detected.iter().map(|d| d.language).collect();

    // Build report
    let mut report = Report::default();

    for det in &detected {
        let source_path = project_dir.join(&det.source_dir);
        if !source_path.is_dir() {
            continue;
        }

        let thresholds = Thresholds::for_language(det.language).with_overrides(&cli);

        // Run checks based on check type
        match cli.check_type {
            CheckType::All => {
                checks::check_file_length(&source_path, det.language, &thresholds, &mut report);
                checks::check_function_length(&source_path, det.language, &thresholds, &mut report);
                checks::check_nesting_depth(&source_path, det.language, &thresholds, &mut report);
            }
            CheckType::FileLength => {
                checks::check_file_length(&source_path, det.language, &thresholds, &mut report);
            }
            CheckType::Functions => {
                checks::check_function_length(&source_path, det.language, &thresholds, &mut report);
            }
            CheckType::Nesting => {
                checks::check_nesting_depth(&source_path, det.language, &thresholds, &mut report);
            }
        }
    }

    // Output results
    output::print_report(
        &report,
        &project_dir,
        &lang_types,
        cli.format,
        cli.severity_filter(),
    );

    process::exit(report.exit_code());
}
