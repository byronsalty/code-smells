use crate::cli::Cli;
use crate::languages::LanguageType;

#[derive(Clone, Debug)]
pub struct Thresholds {
    pub file_warn: usize,
    pub file_error: usize,
    pub func_warn: usize,
    pub func_error: usize,
    pub nest_warn: usize,
    pub nest_error: usize,
}

impl Thresholds {
    /// Get default thresholds for a language
    pub fn for_language(lang: LanguageType) -> Self {
        match lang {
            LanguageType::Elixir => Thresholds {
                file_warn: 300,
                file_error: 500,
                func_warn: 30,
                func_error: 50,
                nest_warn: 4,
                nest_error: 6,
            },
            LanguageType::Dart => Thresholds {
                file_warn: 400,
                file_error: 600,
                func_warn: 40,
                func_error: 70,
                nest_warn: 4,
                nest_error: 6,
            },
            LanguageType::TypeScript => Thresholds {
                file_warn: 250,
                file_error: 400,
                func_warn: 50,
                func_error: 80,
                nest_warn: 4,
                nest_error: 6,
            },
            LanguageType::Python => Thresholds {
                file_warn: 300,
                file_error: 500,
                func_warn: 30,
                func_error: 50,
                nest_warn: 4,
                nest_error: 6,
            },
            LanguageType::Rust => Thresholds {
                file_warn: 400,
                file_error: 600,
                func_warn: 40,
                func_error: 60,
                nest_warn: 4,
                nest_error: 6,
            },
        }
    }

    /// Apply CLI overrides to thresholds
    pub fn with_overrides(mut self, cli: &Cli) -> Self {
        if let Some(v) = cli.file_warn {
            self.file_warn = v;
        }
        if let Some(v) = cli.file_error {
            self.file_error = v;
        }
        if let Some(v) = cli.func_warn {
            self.func_warn = v;
        }
        if let Some(v) = cli.func_error {
            self.func_error = v;
        }
        if let Some(v) = cli.nest_warn {
            self.nest_warn = v;
        }
        if let Some(v) = cli.nest_error {
            self.nest_error = v;
        }
        self
    }
}
