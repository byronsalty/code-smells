use super::{FunctionInfo, LanguageParser};
use once_cell::sync::Lazy;
use regex::Regex;
use std::path::Path;

pub struct RustParser;

// Compiled regex pattern for Rust functions
static FN_PATTERN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"^\s*(pub(\([^)]*\))?\s+)?(async\s+)?(unsafe\s+)?fn\s+([a-zA-Z_][a-zA-Z0-9_]*)").unwrap()
});

impl LanguageParser for RustParser {
    fn parse_functions(&self, content: &str) -> Vec<FunctionInfo> {
        let mut functions = Vec::new();
        let mut in_func = false;
        let mut brace_depth = 0i32;
        let mut func_name = String::new();
        let mut func_start = 0usize;
        let mut base_depth = 0i32;
        let mut max_nesting = 0usize;

        for (line_num, line) in content.lines().enumerate() {
            let line_num = line_num + 1;

            // Check for function start
            if let Some(caps) = FN_PATTERN.captures(line) {
                // If we were in a function, finish it
                if in_func && func_start > 0 {
                    functions.push(FunctionInfo {
                        name: std::mem::take(&mut func_name),
                        start_line: func_start,
                        line_count: line_num - func_start,
                        max_nesting,
                    });
                }

                func_name = caps.get(5).map(|m| m.as_str().to_string()).unwrap_or_default();
                func_start = line_num;
                in_func = true;
                base_depth = brace_depth;
                max_nesting = 0;

                // Count braces on this line
                let (opens, closes) = count_braces(line);
                brace_depth += opens - closes;
                continue;
            }

            // Track braces
            let (opens, closes) = count_braces(line);
            brace_depth += opens - closes;

            if in_func {
                let relative_depth = (brace_depth - base_depth).max(0) as usize;
                if relative_depth > max_nesting {
                    max_nesting = relative_depth;
                }

                // Function ends when brace depth returns to base
                if brace_depth <= base_depth && line_num > func_start {
                    functions.push(FunctionInfo {
                        name: std::mem::take(&mut func_name),
                        start_line: func_start,
                        line_count: line_num - func_start + 1,
                        max_nesting,
                    });
                    in_func = false;
                    func_start = 0;
                    max_nesting = 0;
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
        path_str.contains("/target/") || path_str.contains("/.git/")
    }
}

fn count_braces(line: &str) -> (i32, i32) {
    let mut opens = 0i32;
    let mut closes = 0i32;
    let mut in_string = false;
    let mut in_char = false;
    let mut escape_next = false;

    let chars: Vec<char> = line.chars().collect();
    let mut i = 0;

    while i < chars.len() {
        if escape_next {
            escape_next = false;
            i += 1;
            continue;
        }

        let c = chars[i];

        // Handle escape
        if (in_string || in_char) && c == '\\' {
            escape_next = true;
            i += 1;
            continue;
        }

        // Check for line comment
        if !in_string && !in_char && c == '/' && chars.get(i + 1) == Some(&'/') {
            break;
        }

        // Handle strings and chars
        if c == '"' && !in_char {
            in_string = !in_string;
        } else if c == '\'' && !in_string {
            in_char = !in_char;
        }

        // Count braces
        if !in_string && !in_char {
            match c {
                '{' => opens += 1,
                '}' => closes += 1,
                _ => {}
            }
        }

        i += 1;
    }

    (opens, closes)
}
