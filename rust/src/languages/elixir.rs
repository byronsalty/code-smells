use super::{FunctionInfo, LanguageParser};
use once_cell::sync::Lazy;
use regex::Regex;
use std::path::Path;

pub struct ElixirParser;

// Compiled regex pattern for Elixir function definitions
static DEF_PATTERN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"^\s*(def|defp|defmacro|defmacrop)\s+([a-z_][a-zA-Z0-9_?!]*)").unwrap()
});

impl LanguageParser for ElixirParser {
    fn parse_functions(&self, content: &str) -> Vec<FunctionInfo> {
        let mut functions = Vec::new();
        let mut in_func = false;
        let mut depth = 0i32; // do/end depth
        let mut func_name = String::new();
        let mut func_start = 0usize;
        let mut max_nesting = 0usize;

        for (line_num, line) in content.lines().enumerate() {
            let line_num = line_num + 1;

            // Check for function start
            if let Some(caps) = DEF_PATTERN.captures(line) {
                // Skip single-line functions with ", do:"
                if line.contains(", do:") {
                    continue;
                }

                // If we were in a function, finish it
                if in_func && func_start > 0 {
                    functions.push(FunctionInfo {
                        name: std::mem::take(&mut func_name),
                        start_line: func_start,
                        line_count: line_num - func_start,
                        max_nesting,
                    });
                }

                func_name = caps.get(2).map(|m| m.as_str().to_string()).unwrap_or_default();
                func_start = line_num;
                in_func = true;
                depth = 0;
                max_nesting = 0;

                // Count do/end on this line
                let (dos, ends) = count_do_end(line);
                depth += dos - ends;
                continue;
            }

            // Track do/end keywords
            let (dos, ends) = count_do_end(line);
            depth += dos - ends;

            if in_func {
                if depth > 0 {
                    let relative_depth = depth as usize;
                    if relative_depth > max_nesting {
                        max_nesting = relative_depth;
                    }
                }

                // Track nesting keywords for depth
                max_nesting = max_nesting.max(count_nesting_keywords(line));

                // Function ends when depth returns to 0
                if depth <= 0 && line_num > func_start {
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
        path_str.contains("/deps/")
            || path_str.contains("/_build/")
            || path_str.contains("/.git/")
    }
}

fn count_do_end(line: &str) -> (i32, i32) {
    let mut dos = 0i32;
    let mut ends = 0i32;

    // Skip comments
    let line = if let Some(idx) = line.find('#') {
        &line[..idx]
    } else {
        line
    };

    // Count "do" keywords (word boundary check)
    let words: Vec<&str> = line.split_whitespace().collect();
    for word in &words {
        if *word == "do" {
            dos += 1;
        } else if *word == "end" {
            ends += 1;
        }
    }

    // Also check for "do" at end of line after other tokens
    if line.trim().ends_with(" do") || line.trim() == "do" {
        // Already counted above
    }

    (dos, ends)
}

fn count_nesting_keywords(line: &str) -> usize {
    let mut depth = 0usize;

    // Skip comments
    let line = if let Some(idx) = line.find('#') {
        &line[..idx]
    } else {
        line
    };

    // Check for nesting keywords that indicate depth
    let keywords = ["case", "cond", "if", "unless", "with", "try", "receive", "for"];
    for keyword in keywords {
        if line.contains(keyword) && line.contains("do") {
            depth += 1;
        }
    }

    // Check for fn -> (anonymous functions)
    if line.contains("fn") && line.contains("->") {
        depth += 1;
    }

    depth
}
