#!/bin/bash
# dart.sh - Dart-specific code smell checks
# Checks for long methods and deep nesting in Dart files

# Source output utilities if not already loaded
if [[ -z "${OUTPUT_SH_LOADED:-}" ]]; then
    _DART_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$_DART_SCRIPT_DIR/output.sh"
fi

# Check Dart method lengths
# Args: dir, warn_threshold, error_threshold
check_dart_methods() {
    local dir="$1"
    local warn_threshold="${2:-40}"
    local error_threshold="${3:-70}"

    local file_count=0

    while IFS= read -r -d '' file; do
        # Skip non-source directories and generated files
        case "$file" in
            */.dart_tool/*|*/build/*|*/.git/*) continue ;;
            *.g.dart|*.freezed.dart|*.gen.dart) continue ;;
            */firebase_options.dart) continue ;;
        esac

        ((file_count++))

        # Get relative path
        local rel_path="${file#$dir/}"
        [[ "$rel_path" == "$file" ]] && rel_path="$file"

        # Use awk to parse Dart methods (POSIX-compatible)
        awk -v file="$rel_path" -v warn="$warn_threshold" -v error="$error_threshold" '
        BEGIN {
            in_method = 0
            brace_depth = 0
            method_name = ""
            method_start = 0
        }

        # Match method signatures
        /^[[:space:]]*(static[[:space:]]+)?(void|bool|int|double|String|Future|Widget|State|List|Map|Set|dynamic|[A-Z][a-zA-Z0-9_<>,? ]*)[[:space:]]+[a-z_][a-zA-Z0-9_]*[[:space:]]*\(/ {
            # Skip arrow functions (single line)
            if ($0 ~ /=>[[:space:]]*[^{]/) next
            # Skip abstract methods
            if ($0 ~ /;[[:space:]]*$/) next
            # Skip getters defined with get keyword
            if ($0 ~ /get[[:space:]]+[a-z]/) next

            # If already in a method, report it first
            if (in_method && method_start > 0) {
                method_length = NR - method_start
                if (method_length > error) {
                    printf "ERROR|%s:%d|%s|%d|%d\n", file, method_start, method_name, method_length, error
                } else if (method_length > warn) {
                    printf "WARN|%s:%d|%s|%d|%d\n", file, method_start, method_name, method_length, warn
                }
            }

            # Extract method name - find word before (
            s = $0
            gsub(/\(.*/, "", s)
            n = split(s, words, " ")
            method_name = words[n]
            gsub(/[^a-zA-Z0-9_]/, "", method_name)

            method_start = NR
            in_method = 1
            brace_depth = 0

            # Check for opening brace on same line
            temp = $0
            open_count = gsub(/{/, "{", temp)
            temp = $0
            close_count = gsub(/}/, "}", temp)
            brace_depth = open_count - close_count
            next
        }

        in_method == 1 {
            # Count braces
            temp = $0
            open_count = gsub(/{/, "{", temp)
            temp = $0
            close_count = gsub(/}/, "}", temp)
            brace_depth = brace_depth + open_count - close_count

            # Method ends when brace depth returns to 0
            if (brace_depth <= 0 && NR > method_start) {
                method_length = NR - method_start + 1

                if (method_length > error) {
                    printf "ERROR|%s:%d|%s|%d|%d\n", file, method_start, method_name, method_length, error
                } else if (method_length > warn) {
                    printf "WARN|%s:%d|%s|%d|%d\n", file, method_start, method_name, method_length, warn
                }

                in_method = 0
                method_name = ""
                method_start = 0
            }
        }

        END {
            if (in_method && method_start > 0) {
                method_length = NR - method_start + 1
                if (method_length > error) {
                    printf "ERROR|%s:%d|%s|%d|%d\n", file, method_start, method_name, method_length, error
                } else if (method_length > warn) {
                    printf "WARN|%s:%d|%s|%d|%d\n", file, method_start, method_name, method_length, warn
                }
            }
        }
        ' "$file" | while IFS='|' read -r severity location name length limit; do
            if [[ "$severity" == "ERROR" ]]; then
                print_error "$location" "$name ($length lines)" "method-length" "$length" "$limit"
            elif [[ "$severity" == "WARN" ]]; then
                print_warning "$location" "$name ($length lines)" "method-length" "$length" "$limit"
            fi
        done
    done < <(find "$dir" -type f -name "*.dart" -print0 2>/dev/null)

    increment_files "$file_count"
}

# Check Dart nesting depth
# Args: dir, warn_threshold, error_threshold
check_dart_nesting() {
    local dir="$1"
    local warn_threshold="${2:-4}"
    local error_threshold="${3:-6}"

    local file_count=0

    while IFS= read -r -d '' file; do
        # Skip non-source directories and generated files
        case "$file" in
            */.dart_tool/*|*/build/*|*/.git/*) continue ;;
            *.g.dart|*.freezed.dart|*.gen.dart) continue ;;
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
            in_method = 0
            method_name = ""
            method_start = 0
            base_depth = 0
        }

        # Track method boundaries
        /^[[:space:]]*(void|Widget|Future|[A-Z][a-zA-Z0-9_<>,? ]*)[[:space:]]+[a-z_][a-zA-Z0-9_]*[[:space:]]*\(/ {
            if ($0 ~ /=>/) next
            if ($0 ~ /;[[:space:]]*$/) next

            # Report previous method if it had deep nesting
            if (in_method && max_depth > warn) {
                severity = (max_depth > error) ? "ERROR" : "WARN"
                limit = (max_depth > error) ? error : warn
                printf "%s|%s:%d|%s|%d|%d\n", severity, file, method_start, method_name, max_depth, limit
            }

            # Extract method name
            s = $0
            gsub(/\(.*/, "", s)
            n = split(s, words, " ")
            method_name = words[n]

            method_start = NR
            in_method = 1
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
                if (in_method) {
                    relative_depth = brace_depth - base_depth
                    if (relative_depth > max_depth) {
                        max_depth = relative_depth
                    }
                }
            }

            for (i = 1; i <= close_count; i++) {
                brace_depth--
                if (in_method && brace_depth <= base_depth) {
                    if (max_depth > warn) {
                        severity = (max_depth > error) ? "ERROR" : "WARN"
                        limit = (max_depth > error) ? error : warn
                        printf "%s|%s:%d|%s|%d|%d\n", severity, file, method_start, method_name, max_depth, limit
                    }
                    in_method = 0
                    method_name = ""
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
    done < <(find "$dir" -type f -name "*.dart" -print0 2>/dev/null)
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <directory> [check_type] [warn] [error]"
        echo "  check_type: methods, nesting, or all (default: all)"
        exit 1
    fi

    dir="$1"
    check_type="${2:-all}"
    warn="${3:-}"
    error="${4:-}"

    case "$check_type" in
        methods)
            print_header "DART METHOD LENGTH"
            check_dart_methods "$dir" "${warn:-40}" "${error:-70}"
            ;;
        nesting)
            print_header "DART NESTING DEPTH"
            check_dart_nesting "$dir" "${warn:-4}" "${error:-6}"
            ;;
        all|*)
            print_header "DART METHOD LENGTH"
            check_dart_methods "$dir" "${warn:-40}" "${error:-70}"
            print_header "DART NESTING DEPTH"
            check_dart_nesting "$dir" "${warn:-4}" "${error:-6}"
            ;;
    esac

    print_summary
    exit "$(get_exit_code)"
fi
