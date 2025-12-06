#!/bin/bash
# typescript.sh - TypeScript-specific code smell checks
# Checks for long functions and deep nesting in TypeScript/TSX files

# Source output utilities if not already loaded
if [[ -z "${OUTPUT_SH_LOADED:-}" ]]; then
    _TS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$_TS_SCRIPT_DIR/output.sh"
fi

# Check TypeScript function lengths
# Args: dir, warn_threshold, error_threshold
check_typescript_functions() {
    local dir="$1"
    local warn_threshold="${2:-50}"
    local error_threshold="${3:-80}"

    local file_count=0

    while IFS= read -r -d '' file; do
        # Skip non-source directories
        case "$file" in
            */node_modules/*|*/dist/*|*/build/*|*/.git/*) continue ;;
            *.d.ts) continue ;;  # Skip type definition files
        esac

        ((file_count++))

        # Get relative path
        local rel_path="${file#$dir/}"
        [[ "$rel_path" == "$file" ]] && rel_path="$file"

        # Use awk to parse TypeScript functions (POSIX-compatible)
        awk -v file="$rel_path" -v warn="$warn_threshold" -v error="$error_threshold" '
        BEGIN {
            in_func = 0
            brace_depth = 0
            func_name = ""
            func_start = 0
        }

        # Match function declarations and arrow functions
        /^[[:space:]]*(export[[:space:]]+)?(async[[:space:]]+)?function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ ||
        /^[[:space:]]*(export[[:space:]]+)?(const|let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[:=].*=>/ {
            # Skip type definitions
            if ($0 ~ /^[[:space:]]*(type|interface)[[:space:]]/) next
            # Skip single-line arrow functions without braces
            if ($0 ~ /=>[[:space:]]*[^{]/ && $0 !~ /{/) next

            # If already in a function, report it first
            if (in_func && func_start > 0 && brace_depth <= 0) {
                func_length = NR - func_start
                if (func_length > error) {
                    printf "ERROR|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, error
                } else if (func_length > warn) {
                    printf "WARN|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, warn
                }
            }

            # Extract function name
            if ($0 ~ /function[[:space:]]+/) {
                s = $0
                gsub(/.*function[[:space:]]+/, "", s)
                gsub(/[^A-Za-z0-9_].*/, "", s)
                func_name = s
            } else {
                s = $0
                gsub(/.*(const|let|var)[[:space:]]+/, "", s)
                gsub(/[^A-Za-z0-9_].*/, "", s)
                func_name = s
            }

            if (func_name == "") func_name = "anonymous"

            func_start = NR
            in_func = 1
            brace_depth = 0

            # Check for opening brace on same line
            temp = $0
            open_count = gsub(/{/, "{", temp)
            temp = $0
            close_count = gsub(/}/, "}", temp)
            brace_depth = open_count - close_count
            next
        }

        in_func == 1 {
            # Count braces
            temp = $0
            open_count = gsub(/{/, "{", temp)
            temp = $0
            close_count = gsub(/}/, "}", temp)
            brace_depth = brace_depth + open_count - close_count

            # Function ends when brace depth returns to 0
            if (brace_depth <= 0 && NR > func_start) {
                func_length = NR - func_start + 1

                if (func_length > error) {
                    printf "ERROR|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, error
                } else if (func_length > warn) {
                    printf "WARN|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, warn
                }

                in_func = 0
                func_name = ""
                func_start = 0
            }
        }

        END {
            if (in_func && func_start > 0) {
                func_length = NR - func_start + 1
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
    done < <(find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" \) -print0 2>/dev/null)

    increment_files "$file_count"
}

# Check TypeScript nesting depth
# Args: dir, warn_threshold, error_threshold
check_typescript_nesting() {
    local dir="$1"
    local warn_threshold="${2:-4}"
    local error_threshold="${3:-6}"

    local file_count=0

    while IFS= read -r -d '' file; do
        # Skip non-source directories
        case "$file" in
            */node_modules/*|*/dist/*|*/build/*|*/.git/*) continue ;;
            *.d.ts) continue ;;
        esac

        ((file_count++))

        # Get relative path
        local rel_path="${file#$dir/}"
        [[ "$rel_path" == "$file" ]] && rel_path="$file"

        # Use awk to track nesting depth (POSIX-compatible)
        awk -v file="$rel_path" -v warn="$warn_threshold" -v error="$error_threshold" '
        BEGIN {
            brace_depth = 0
            max_depth = 0
            in_func = 0
            func_name = ""
            func_start = 0
            base_depth = 0
        }

        # Track function boundaries
        /^[[:space:]]*(export[[:space:]]+)?(async[[:space:]]+)?function[[:space:]]+[A-Za-z_]/ ||
        /^[[:space:]]*(export[[:space:]]+)?(const|let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[:=].*=>/ {
            if ($0 ~ /^[[:space:]]*(type|interface)[[:space:]]/) next

            # Report previous function if it had deep nesting
            if (in_func && max_depth > warn) {
                severity = (max_depth > error) ? "ERROR" : "WARN"
                limit = (max_depth > error) ? error : warn
                printf "%s|%s:%d|%s|%d|%d\n", severity, file, func_start, func_name, max_depth, limit
            }

            # Extract function name
            if ($0 ~ /function[[:space:]]+/) {
                s = $0
                gsub(/.*function[[:space:]]+/, "", s)
                gsub(/[^A-Za-z0-9_].*/, "", s)
                func_name = s
            } else {
                s = $0
                gsub(/.*(const|let|var)[[:space:]]+/, "", s)
                gsub(/[^A-Za-z0-9_].*/, "", s)
                func_name = s
            }

            func_start = NR
            in_func = 1
            base_depth = brace_depth
            max_depth = 0
        }

        {
            # Track brace depth
            temp = $0
            open_count = gsub(/{/, "{", temp)
            temp = $0
            close_count = gsub(/}/, "}", temp)

            for (i = 1; i <= open_count; i++) {
                brace_depth++
                if (in_func) {
                    relative_depth = brace_depth - base_depth
                    if (relative_depth > max_depth) {
                        max_depth = relative_depth
                    }
                }
            }

            for (i = 1; i <= close_count; i++) {
                brace_depth--
                if (in_func && brace_depth <= base_depth) {
                    if (max_depth > warn) {
                        severity = (max_depth > error) ? "ERROR" : "WARN"
                        limit = (max_depth > error) ? error : warn
                        printf "%s|%s:%d|%s|%d|%d\n", severity, file, func_start, func_name, max_depth, limit
                    }
                    in_func = 0
                    func_name = ""
                    max_depth = 0
                }
            }
        }
        ' "$file" | while IFS='|' read -r severity location name depth limit; do
            if [[ "$severity" == "ERROR" ]]; then
                print_error "$location" "$name (depth: $depth)" "nesting-depth" "$depth" "$limit"
            elif [[ "$severity" == "WARN" ]]; then
                print_warning "$location" "$name (depth: $depth)" "nesting-depth" "$depth" "$limit"
            fi
        done
    done < <(find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" \) -print0 2>/dev/null)
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
            print_header "TYPESCRIPT FUNCTION LENGTH"
            check_typescript_functions "$dir" "${warn:-50}" "${error:-80}"
            ;;
        nesting)
            print_header "TYPESCRIPT NESTING DEPTH"
            check_typescript_nesting "$dir" "${warn:-4}" "${error:-6}"
            ;;
        all|*)
            print_header "TYPESCRIPT FUNCTION LENGTH"
            check_typescript_functions "$dir" "${warn:-50}" "${error:-80}"
            print_header "TYPESCRIPT NESTING DEPTH"
            check_typescript_nesting "$dir" "${warn:-4}" "${error:-6}"
            ;;
    esac

    print_summary
    exit "$(get_exit_code)"
fi
