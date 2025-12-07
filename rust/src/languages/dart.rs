use super::{FunctionInfo, LanguageParser};
use once_cell::sync::Lazy;
use regex::Regex;
use std::path::Path;

pub struct DartParser;

// Compiled regex pattern for Dart methods
static METHOD_PATTERN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"^\s*(static\s+)?(void|bool|int|double|String|Future|Widget|State|List|Map|Set|dynamic|[A-Z][a-zA-Z0-9_<>,?\s]*)\s+([a-z_][a-zA-Z0-9_]*)\s*\("
    ).unwrap()
});

impl LanguageParser for DartParser {
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

            // Check for method start
            if let Some(name) = extract_method_name(line) {
                // Skip arrow functions (single line)
                if line.contains("=>") && !line.contains('{') {
                    continue;
                }
                // Skip abstract methods (ending with ;)
                if line.trim().ends_with(';') {
                    continue;
                }
                // Skip getters
                if line.contains(" get ") {
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

                func_name = name;
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
        if path_str.contains("/.dart_tool/")
            || path_str.contains("/build/")
            || path_str.contains("/.git/")
        {
            return true;
        }

        // Skip generated files
        if path_str.ends_with(".g.dart")
            || path_str.ends_with(".freezed.dart")
            || path_str.ends_with(".gen.dart")
            || path_str.contains("firebase_options.dart")
        {
            return true;
        }

        false
    }
}

fn extract_method_name(line: &str) -> Option<String> {
    METHOD_PATTERN.captures(line).and_then(|caps| {
        caps.get(3).map(|m| m.as_str().to_string())
    })
}

fn count_braces(line: &str) -> (i32, i32) {
    let mut opens = 0i32;
    let mut closes = 0i32;
    let mut in_string = false;
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

        if in_string && c == '\\' {
            escape_next = true;
            i += 1;
            continue;
        }

        // Check for line comment
        if !in_string && c == '/' && chars.get(i + 1) == Some(&'/') {
            break;
        }

        // Handle strings
        if c == '"' || c == '\'' {
            in_string = !in_string;
        }

        // Count braces
        if !in_string {
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
