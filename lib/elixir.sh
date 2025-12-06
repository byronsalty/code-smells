#!/bin/bash
# elixir.sh - Elixir-specific code smell checks
# Checks for long functions and deep nesting in Elixir files

# Source output utilities if not already loaded
if [[ -z "${OUTPUT_SH_LOADED:-}" ]]; then
    _ELIXIR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$_ELIXIR_SCRIPT_DIR/output.sh"
fi

# Check Elixir function lengths
# Args: dir, warn_threshold, error_threshold
check_elixir_functions() {
    local dir="$1"
    local warn_threshold="${2:-30}"
    local error_threshold="${3:-50}"

    local file_count=0

    while IFS= read -r -d '' file; do
        # Skip non-source directories
        case "$file" in
            */deps/*|*/_build/*|*/.git/*) continue ;;
        esac

        ((file_count++))

        # Get relative path
        local rel_path="${file#$dir/}"
        [[ "$rel_path" == "$file" ]] && rel_path="$file"

        # Use awk to parse Elixir functions (POSIX-compatible)
        awk -v file="$rel_path" -v warn="$warn_threshold" -v error="$error_threshold" '
        BEGIN {
            in_func = 0
            depth = 0
            func_name = ""
            func_start = 0
        }

        # Match function definitions (def, defp, defmacro, defmacrop)
        /^[[:space:]]*(def|defp|defmacro|defmacrop)[[:space:]]+[a-z_][a-zA-Z0-9_?!]*/ {
            # Skip single-line functions with ", do:"
            if ($0 ~ /,[[:space:]]*do:/) next

            # Extract function name using gsub (POSIX-compatible)
            s = $0
            gsub(/^[[:space:]]*(def|defp|defmacro|defmacrop)[[:space:]]+/, "", s)
            gsub(/\(.*/, "", s)
            gsub(/[[:space:]].*/, "", s)
            gsub(/,.*/, "", s)
            new_func_name = s

            # If we were already in a function, check and report it
            if (in_func && depth <= 0 && func_start > 0) {
                func_length = NR - func_start
                if (func_length > error) {
                    printf "ERROR|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, error
                } else if (func_length > warn) {
                    printf "WARN|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, warn
                }
            }

            func_name = new_func_name
            func_start = NR
            in_func = 1
            depth = 0

            # Check for "do" on same line
            if ($0 ~ /do[[:space:]]*$/) {
                depth = 1
            }
            next
        }

        in_func == 1 {
            # Count do/end keywords for nesting
            line = $0

            # Count "do" keywords
            temp = line
            gsub(/do/, "\n", temp)
            do_count = gsub(/\n/, "\n", temp)

            # Count "end" keywords
            temp = line
            gsub(/end/, "\n", temp)
            end_count = gsub(/\n/, "\n", temp)

            depth = depth + do_count - end_count

            # Function ends when depth goes to 0 or negative
            if (depth <= 0 && NR > func_start) {
                func_length = NR - func_start + 1

                if (func_length > error) {
                    printf "ERROR|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, error
                } else if (func_length > warn) {
                    printf "WARN|%s:%d|%s|%d|%d\n", file, func_start, func_name, func_length, warn
                }

                in_func = 0
                func_name = ""
                func_start = 0
                depth = 0
            }
        }

        END {
            # Report last function if still in one
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
    done < <(find "$dir" -type f -name "*.ex" -print0 2>/dev/null)

    increment_files "$file_count"
}

# Check Elixir nesting depth
# Args: dir, warn_threshold, error_threshold
check_elixir_nesting() {
    local dir="$1"
    local warn_threshold="${2:-4}"
    local error_threshold="${3:-6}"

    local file_count=0

    while IFS= read -r -d '' file; do
        # Skip non-source directories
        case "$file" in
            */deps/*|*/_build/*|*/.git/*) continue ;;
        esac

        ((file_count++))

        # Get relative path
        local rel_path="${file#$dir/}"
        [[ "$rel_path" == "$file" ]] && rel_path="$file"

        # Use awk to track nesting depth (POSIX-compatible)
        awk -v file="$rel_path" -v warn="$warn_threshold" -v error="$error_threshold" '
        BEGIN {
            depth = 0
            max_depth = 0
            max_depth_line = 0
            in_func = 0
            func_name = ""
            func_start = 0
        }

        # Track function boundaries
        /^[[:space:]]*(def|defp)[[:space:]]+[a-z_]/ {
            # Report previous function if it had deep nesting
            if (in_func && max_depth > warn) {
                severity = (max_depth > error) ? "ERROR" : "WARN"
                limit = (max_depth > error) ? error : warn
                printf "%s|%s:%d|%s|%d|%d\n", severity, file, func_start, func_name, max_depth, limit
            }

            # Start new function - extract name
            s = $0
            gsub(/^[[:space:]]*(def|defp)[[:space:]]+/, "", s)
            gsub(/\(.*/, "", s)
            gsub(/[[:space:]].*/, "", s)
            func_name = s

            func_start = NR
            in_func = 1
            depth = 0
            max_depth = 0
            max_depth_line = NR
        }

        in_func == 1 {
            # Track nesting - these keywords add depth when followed by do
            if ($0 ~ /(case|cond|if|unless|with|try|receive|for).*do/) {
                depth++
            } else if ($0 ~ /fn.*->/) {
                depth++
            } else if ($0 ~ /do[[:space:]]*$/) {
                depth++
            }

            # end decreases depth
            if ($0 ~ /end/) {
                temp = $0
                n = gsub(/end/, "&", temp)
                depth = depth - n
            }
            if (depth < 0) depth = 0

            if (depth > max_depth) {
                max_depth = depth
                max_depth_line = NR
            }
        }

        END {
            # Report last function
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
    done < <(find "$dir" -type f -name "*.ex" -print0 2>/dev/null)
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
            print_header "ELIXIR FUNCTION LENGTH"
            check_elixir_functions "$dir" "${warn:-30}" "${error:-50}"
            ;;
        nesting)
            print_header "ELIXIR NESTING DEPTH"
            check_elixir_nesting "$dir" "${warn:-4}" "${error:-6}"
            ;;
        all|*)
            print_header "ELIXIR FUNCTION LENGTH"
            check_elixir_functions "$dir" "${warn:-30}" "${error:-50}"
            print_header "ELIXIR NESTING DEPTH"
            check_elixir_nesting "$dir" "${warn:-4}" "${error:-6}"
            ;;
    esac

    print_summary
    exit "$(get_exit_code)"
fi
