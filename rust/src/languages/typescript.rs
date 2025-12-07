use super::{FunctionInfo, LanguageParser};
use once_cell::sync::Lazy;
use regex::Regex;
use std::path::Path;

pub struct TypeScriptParser;

// Compiled regex patterns
static FUNC_PATTERN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"^\s*(export\s+)?(async\s+)?function\s+([a-zA-Z_][a-zA-Z0-9_]*)").unwrap()
});

static ARROW_PATTERN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"^\s*(export\s+)?(const|let|var)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*[=:].*=>").unwrap()
});

impl LanguageParser for TypeScriptParser {
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
            let name = extract_function_name(line);
            if let Some(name) = name {
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
        if path_str.contains("/node_modules/")
            || path_str.contains("/dist/")
            || path_str.contains("/build/")
            || path_str.contains("/.git/")
        {
            return true;
        }

        // Skip type definition files
        if path_str.ends_with(".d.ts") {
            return true;
        }

        false
    }
}

fn extract_function_name(line: &str) -> Option<String> {
    // Skip type definitions and interfaces
    let trimmed = line.trim();
    if trimmed.starts_with("type ") || trimmed.starts_with("interface ") {
        return None;
    }

    // Skip single-line arrow functions (no braces)
    if line.contains("=>") && !line.contains('{') {
        return None;
    }

    // Try function declaration pattern
    if let Some(caps) = FUNC_PATTERN.captures(line) {
        return caps.get(3).map(|m| m.as_str().to_string());
    }

    // Try arrow function pattern
    if let Some(caps) = ARROW_PATTERN.captures(line) {
        return caps.get(3).map(|m| m.as_str().to_string());
    }

    None
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

        // Handle escape in strings
        if (in_string || in_char) && c == '\\' {
            escape_next = true;
            i += 1;
            continue;
        }

        // Check for line comment
        if !in_string && !in_char && c == '/' && chars.get(i + 1) == Some(&'/') {
            break; // Rest of line is comment
        }

        // Handle strings
        if c == '"' && !in_char {
            in_string = !in_string;
        } else if c == '\'' && !in_string {
            in_char = !in_char;
        } else if c == '`' && !in_char && !in_string {
            // Template literals - simplified handling
            in_string = !in_string;
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_simple_function() {
        let parser = TypeScriptParser;
        let code = r#"
function hello() {
    console.log("hi");
}
"#;
        let functions = parser.parse_functions(code);
        assert_eq!(functions.len(), 1);
        assert_eq!(functions[0].name, "hello");
        assert_eq!(functions[0].line_count, 3);
    }

    #[test]
    fn test_arrow_function() {
        let parser = TypeScriptParser;
        let code = r#"
const greet = () => {
    return "hello";
}
"#;
        let functions = parser.parse_functions(code);
        assert_eq!(functions.len(), 1);
        assert_eq!(functions[0].name, "greet");
    }

    #[test]
    fn test_count_braces() {
        assert_eq!(count_braces("function foo() {"), (1, 0));
        assert_eq!(count_braces("}"), (0, 1));
        assert_eq!(count_braces("let x = \"{}\";"), (0, 0)); // braces in string
    }
}
