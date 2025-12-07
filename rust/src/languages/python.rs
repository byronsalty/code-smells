use super::{FunctionInfo, LanguageParser};
use once_cell::sync::Lazy;
use regex::Regex;
use std::path::Path;

pub struct PythonParser;

// Compiled regex pattern for Python function definitions
static DEF_PATTERN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"^(\s*)(async\s+)?def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(").unwrap()
});

impl LanguageParser for PythonParser {
    fn parse_functions(&self, content: &str) -> Vec<FunctionInfo> {
        let mut functions = Vec::new();
        let mut in_func = false;
        let mut func_indent = 0usize;
        let mut func_name = String::new();
        let mut func_start = 0usize;
        let mut max_nesting = 0usize;
        let mut base_indent = 0usize;

        for (line_num, line) in content.lines().enumerate() {
            let line_num = line_num + 1;

            // Check for function start
            if let Some(caps) = DEF_PATTERN.captures(line) {
                // If we were in a function, finish it
                if in_func && func_start > 0 {
                    functions.push(FunctionInfo {
                        name: std::mem::take(&mut func_name),
                        start_line: func_start,
                        line_count: line_num - func_start,
                        max_nesting,
                    });
                }

                let indent = caps.get(1).map(|m| m.as_str().len()).unwrap_or(0);
                func_name = caps.get(3).map(|m| m.as_str().to_string()).unwrap_or_default();
                func_start = line_num;
                func_indent = indent;
                base_indent = indent;
                in_func = true;
                max_nesting = 0;
                continue;
            }

            if in_func {
                // Skip empty lines and comments for determining function end
                let trimmed = line.trim();
                if trimmed.is_empty() || trimmed.starts_with('#') {
                    continue;
                }

                let current_indent = measure_indent(line);

                // Function ends when we see a non-empty, non-comment line
                // with indentation <= function's indentation
                if current_indent <= func_indent && line_num > func_start {
                    functions.push(FunctionInfo {
                        name: std::mem::take(&mut func_name),
                        start_line: func_start,
                        line_count: line_num - func_start,
                        max_nesting,
                    });
                    in_func = false;
                    func_start = 0;
                    max_nesting = 0;

                    // Check if this line starts a new function
                    if let Some(caps) = DEF_PATTERN.captures(line) {
                        let indent = caps.get(1).map(|m| m.as_str().len()).unwrap_or(0);
                        func_name = caps.get(3).map(|m| m.as_str().to_string()).unwrap_or_default();
                        func_start = line_num;
                        func_indent = indent;
                        base_indent = indent;
                        in_func = true;
                        max_nesting = 0;
                    }
                    continue;
                }

                // Track nesting depth based on indentation
                if current_indent > base_indent {
                    // Calculate depth: assume 4 spaces per level
                    let depth = (current_indent - base_indent) / 4;
                    if depth > max_nesting {
                        max_nesting = depth;
                    }
                }
            }
        }

        // Handle function at end of file
        if in_func && func_start > 0 {
            let total_lines = content.lines().count();
            functions.push(FunctionInfo {
                name: func_name,
                start_line: func_start,
                line_count: total_lines - func_start + 1,
                max_nesting,
            });
        }

        functions
    }

    fn should_skip(&self, path: &Path) -> bool {
        let path_str = path.to_string_lossy();

        // Skip common non-source directories
        path_str.contains("/__pycache__/")
            || path_str.contains("/.venv/")
            || path_str.contains("/venv/")
            || path_str.contains("/env/")
            || path_str.contains("/.git/")
            || path_str.contains("/site-packages/")
    }
}

fn measure_indent(line: &str) -> usize {
    line.chars().take_while(|c| c.is_whitespace()).count()
}
