use crate::languages::LanguageType;
use std::path::Path;

/// Detected language with its source directory
#[derive(Debug)]
pub struct DetectedLanguage {
    pub language: LanguageType,
    pub source_dir: String,
}

/// Detect languages in a project directory by looking for marker files
pub fn detect_languages(project_dir: &Path) -> Vec<DetectedLanguage> {
    let mut detected = Vec::new();

    // Elixir - look for mix.exs
    if project_dir.join("mix.exs").exists() {
        detected.push(DetectedLanguage {
            language: LanguageType::Elixir,
            source_dir: "lib".to_string(),
        });
    }

    // Dart - look for pubspec.yaml
    if project_dir.join("pubspec.yaml").exists() {
        detected.push(DetectedLanguage {
            language: LanguageType::Dart,
            source_dir: "lib".to_string(),
        });
    }

    // TypeScript - look for tsconfig.json or package.json with .ts files
    if project_dir.join("tsconfig.json").exists() || has_typescript_files(project_dir) {
        let source_dir = if project_dir.join("src").is_dir() {
            "src"
        } else {
            "."
        };
        detected.push(DetectedLanguage {
            language: LanguageType::TypeScript,
            source_dir: source_dir.to_string(),
        });
    }

    // Python - look for setup.py, pyproject.toml, or requirements.txt
    if project_dir.join("setup.py").exists()
        || project_dir.join("pyproject.toml").exists()
        || project_dir.join("requirements.txt").exists()
    {
        let source_dir = if project_dir.join("src").is_dir() {
            "src"
        } else {
            "."
        };
        detected.push(DetectedLanguage {
            language: LanguageType::Python,
            source_dir: source_dir.to_string(),
        });
    }

    // Rust - look for Cargo.toml
    if project_dir.join("Cargo.toml").exists() {
        detected.push(DetectedLanguage {
            language: LanguageType::Rust,
            source_dir: "src".to_string(),
        });
    }

    detected
}

/// Check if a project has TypeScript files (when package.json exists but no tsconfig.json)
fn has_typescript_files(project_dir: &Path) -> bool {
    if !project_dir.join("package.json").exists() {
        return false;
    }

    // Quick check for .ts files in common locations
    let check_dirs = ["src", "lib", "."];
    for dir in check_dirs {
        let dir_path = project_dir.join(dir);
        if dir_path.is_dir() {
            if let Ok(entries) = std::fs::read_dir(&dir_path) {
                for entry in entries.filter_map(|e| e.ok()) {
                    let path = entry.path();
                    if let Some(ext) = path.extension() {
                        if ext == "ts" || ext == "tsx" {
                            return true;
                        }
                    }
                }
            }
        }
    }
    false
}

/// Parse a comma-separated language list from CLI
pub fn parse_language_list(input: &str) -> Vec<DetectedLanguage> {
    input
        .split(',')
        .filter_map(|s| {
            let name = s.trim().to_lowercase();
            let (lang, source_dir) = match name.as_str() {
                "elixir" => (LanguageType::Elixir, "lib"),
                "dart" => (LanguageType::Dart, "lib"),
                "typescript" => (LanguageType::TypeScript, "src"),
                "python" => (LanguageType::Python, "."),
                "rust" => (LanguageType::Rust, "src"),
                _ => return None,
            };
            Some(DetectedLanguage {
                language: lang,
                source_dir: source_dir.to_string(),
            })
        })
        .collect()
}
