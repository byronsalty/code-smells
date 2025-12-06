#!/bin/bash
# python.sh - Python-specific code smell checks
# Checks for long functions and deep nesting in Python files

# Source output utilities if not already loaded
if [[ -z "${OUTPUT_SH_LOADED:-}" ]]; then
    _PYTHON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$_PYTHON_SCRIPT_DIR/output.sh"
fi

# Check Python function lengths
# Args: dir, warn_threshold, error_threshold
check_python_functions() {
    local dir="$1"
    local warn_threshold="${2:-30}"
    local error_threshold="${3:-50}"

    local file_count=0

    while IFS= read -r -d '' file; do
        # Skip non-source directories
        case "$file" in
            */__pycache__/*|*/.venv/*|*/venv/*|*/env/*|*/.git/*|*/site-packages/*) continue ;;
            *_test.py|*test_*.py) continue ;;  # Skip test files (optional)
        esac

        ((file_count++))

        # Get relative path
        local rel_path="${file#$dir/}"
        [[ "$rel_path" == "$file" ]] && rel_path="$file"

        # Use awk to parse Python functions (indentation-based)
        awk -v file="$rel_path" -v warn="$warn_threshold" -v error="$error_threshold" '
        BEGIN {
            in_func = 0
            func_indent = 0
            func_name = ""
            func_start = 0
        }

        # Match function/method definitions
        /^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(/ {
            # Report previous function if we were in one
            if (in_func && func_start > 0) {
                func_length = NR - func_start
                if (func_length > error) {
                    printf "ERROR|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, error
                } else if (func_length > warn) {
                    printf "WARN|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, warn
                }
            }

            # Calculate indentation (number of leading spaces)
            match($0, /^[[:space:]]*/)
            func_indent = RLENGTH

            # Extract function name
            s = $0
            gsub(/^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+/, "", s)
            gsub(/\(.*/, "", s)
            func_name = s

            func_start = NR
            in_func = 1
            next
        }

        in_func == 1 {
            # Check if this line ends the function
            # A function ends when we hit a line with <= indentation (and non-empty, non-comment)
            if (NF > 0 && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/) {
                match($0, /^[[:space:]]*/)
                current_indent = RLENGTH

                # If indentation is <= func_indent, function has ended
                if (current_indent <= func_indent && NR > func_start + 1) {
                    func_length = NR - func_start - 1
                    if (func_length > error) {
                        printf "ERROR|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, error
                    } else if (func_length > warn) {
                        printf "WARN|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, warn
                    }

                    # Check if this line starts a new function
                    if ($0 ~ /^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+/) {
                        func_indent = current_indent
                        s = $0
                        gsub(/^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+/, "", s)
                        gsub(/\(.*/, "", s)
                        func_name = s
                        func_start = NR
                    } else {
                        in_func = 0
                        func_name = ""
                        func_start = 0
                    }
                }
            }
        }

        END {
            # Report last function
            if (in_func && func_start > 0) {
                func_length = NR - func_start
                if (func_length > error) {
                    printf "ERROR|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, error
                } else if (func_length > warn) {
                    printf "WARN|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, warn
                }
            }
        }
        ' "$file" | while IFS='|' read -r severity location name length limit; do
            if [[ "$severity" == "ERROR" ]]; then
                print_error "$location" "$name ($length lines)" "function-length" "$length" "$limit"
            elif [[ "$severity" == "WARN" ]]; then
                print_warning "$location" "$name ($length lines)" "function-length" "$length" "$limit"
            fi
        done
    done < <(find "$dir" -type f -name "*.py" -print0 2>/dev/null)

    increment_files "$file_count"
}

# Check Python nesting depth
# Args: dir, warn_threshold, error_threshold
check_python_nesting() {
    local dir="$1"
    local warn_threshold="${2:-4}"
    local error_threshold="${3:-6}"

    local file_count=0

    while IFS= read -r -d '' file; do
        # Skip non-source directories
        case "$file" in
            */__pycache__/*|*/.venv/*|*/venv/*|*/env/*|*/.git/*|*/site-packages/*) continue ;;
        esac

        ((file_count++))

        # Get relative path
        local rel_path="${file#$dir/}"
        [[ "$rel_path" == "$file" ]] && rel_path="$file"

        # Use awk to track nesting depth (indentation-based)
        awk -v file="$rel_path" -v warn="$warn_threshold" -v error="$error_threshold" '
        BEGIN {
            in_func = 0
            func_indent = 0
            func_name = ""
            func_start = 0
            max_depth = 0
            base_indent = 0
        }

        # Track function boundaries
        /^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+[a-zA-Z_]/ {
            # Report previous function if it had deep nesting
            if (in_func && max_depth > warn) {
                severity = (max_depth > error) ? "ERROR" : "WARN"
                limit = (max_depth > error) ? error : warn
                printf "%s|%s:%d|%s|%d|%d\n", severity, file, func_start, func_name, max_depth, limit
            }

            # Start new function
            match($0, /^[[:space:]]*/)
            func_indent = RLENGTH
            base_indent = func_indent

            s = $0
            gsub(/^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+/, "", s)
            gsub(/\(.*/, "", s)
            func_name = s

            func_start = NR
            in_func = 1
            max_depth = 0
            next
        }

        in_func == 1 && NF > 0 && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/ {
            match($0, /^[[:space:]]*/)
            current_indent = RLENGTH

            # Check if function ended
            if (current_indent <= func_indent && NR > func_start + 1) {
                if (max_depth > warn) {
                    severity = (max_depth > error) ? "ERROR" : "WARN"
                    limit = (max_depth > error) ? error : warn
                    printf "%s|%s:%d|%s|%d|%d\n", severity, file, func_start, func_name, max_depth, limit
                }

                # Check if new function starts
                if ($0 ~ /^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+/) {
                    func_indent = current_indent
                    base_indent = current_indent
                    s = $0
                    gsub(/^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+/, "", s)
                    gsub(/\(.*/, "", s)
                    func_name = s
                    func_start = NR
                    max_depth = 0
                } else {
                    in_func = 0
                }
            } else {
                # Calculate depth based on indentation (assuming 4 spaces per level)
                depth = int((current_indent - base_indent) / 4)
                if (depth > max_depth) {
                    max_depth = depth
                }
            }
        }

        END {
            if (in_func && max_depth > warn) {
                severity = (max_depth > error) ? "ERROR" : "WARN"
                limit = (max_depth > error) ? error : warn
                printf "%s|%s:%d|%s|%d|%d\n", severity, file, func_start, func_name, max_depth, limit
            }
        }
        ' "$file" | while IFS='|' read -r severity location name depth limit; do
            if [[ "$severity" == "ERROR" ]]; then
                print_error "$location" "$name (depth: $depth)" "nesting-depth" "$depth" "$limit"
            elif [[ "$severity" == "WARN" ]]; then
                print_warning "$location" "$name (depth: $depth)" "nesting-depth" "$depth" "$limit"
            fi
        done
    done < <(find "$dir" -type f -name "*.py" -print0 2>/dev/null)
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <directory> [check_type] [warn] [error]"
        echo "  check_type: functions, nesting, or all (default: all)"
        exit 1
    fi

    dir="$1"
    check_type="${2:-all}"
    warn="${3:-}"
    error="${4:-}"

    case "$check_type" in
        functions)
            print_header "PYTHON FUNCTION LENGTH"
            check_python_functions "$dir" "${warn:-30}" "${error:-50}"
            ;;
        nesting)
            print_header "PYTHON NESTING DEPTH"
            check_python_nesting "$dir" "${warn:-4}" "${error:-6}"
            ;;
        all|*)
            print_header "PYTHON FUNCTION LENGTH"
            check_python_functions "$dir" "${warn:-30}" "${error:-50}"
            print_header "PYTHON NESTING DEPTH"
            check_python_nesting "$dir" "${warn:-4}" "${error:-6}"
            ;;
    esac

    print_summary
    exit "$(get_exit_code)"
fi
