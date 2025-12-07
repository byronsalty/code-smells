pub mod dart;
pub mod elixir;
pub mod python;
pub mod rust_lang;
pub mod typescript;

use std::path::Path;

/// Supported language types
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LanguageType {
    Elixir,
    Dart,
    TypeScript,
    Python,
    Rust,
}

impl LanguageType {
    pub fn name(&self) -> &'static str {
        match self {
            LanguageType::Elixir => "elixir",
            LanguageType::Dart => "dart",
            LanguageType::TypeScript => "typescript",
            LanguageType::Python => "python",
            LanguageType::Rust => "rust",
        }
    }

    #[allow(dead_code)]
    pub fn display_name(&self) -> &'static str {
        match self {
            LanguageType::Elixir => "Elixir",
            LanguageType::Dart => "Dart",
            LanguageType::TypeScript => "TypeScript",
            LanguageType::Python => "Python",
            LanguageType::Rust => "Rust",
        }
    }

    pub fn extensions(&self) -> &'static [&'static str] {
        match self {
            LanguageType::Elixir => &["ex", "exs"],
            LanguageType::Dart => &["dart"],
            LanguageType::TypeScript => &["ts", "tsx"],
            LanguageType::Python => &["py"],
            LanguageType::Rust => &["rs"],
        }
    }
}

/// Information about a function/method extracted from source code
#[derive(Debug)]
pub struct FunctionInfo {
    pub name: String,
    pub start_line: usize,
    pub line_count: usize,
    pub max_nesting: usize,
}

/// Trait for language-specific parsers
pub trait LanguageParser: Send + Sync {
    /// Parse functions/methods from file content
    fn parse_functions(&self, content: &str) -> Vec<FunctionInfo>;

    /// Check if a path should be skipped for this language
    fn should_skip(&self, path: &Path) -> bool;
}

/// Get a parser for a language
pub fn get_parser(lang: LanguageType) -> Box<dyn LanguageParser> {
    match lang {
        LanguageType::Elixir => Box::new(elixir::ElixirParser),
        LanguageType::Dart => Box::new(dart::DartParser),
        LanguageType::TypeScript => Box::new(typescript::TypeScriptParser),
        LanguageType::Python => Box::new(python::PythonParser),
        LanguageType::Rust => Box::new(rust_lang::RustParser),
    }
}
