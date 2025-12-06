#!/bin/bash
# file-length.sh - Check for files exceeding line count thresholds
# Usage: check_file_length <dir> <extensions> <warn_threshold> <error_threshold>

# Source output utilities if not already loaded
if [[ -z "${OUTPUT_SH_LOADED:-}" ]]; then
    _FILE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$_FILE_SCRIPT_DIR/output.sh"
fi

# Check file lengths in a directory
# Args: dir, extensions (space-separated), warn_threshold, error_threshold
check_file_length() {
    local dir="$1"
    local extensions="$2"
    local warn_threshold="${3:-300}"
    local error_threshold="${4:-500}"

    # Build find expression for extensions
    local find_expr=()
    local first=true
    for ext in $extensions; do
        if [[ "$first" == "true" ]]; then
            find_expr+=("-name" "*.$ext")
            first=false
        else
            find_expr+=("-o" "-name" "*.$ext")
        fi
    done

    # Find and check files
    local file_count=0
    while IFS= read -r -d '' file; do
        # Skip common non-source directories
        case "$file" in
            */deps/*|*/_build/*|*/.dart_tool/*|*/node_modules/*|*/build/*|*/dist/*|*/.git/*) continue ;;
            # Skip generated files
            *.g.dart|*.freezed.dart|*.gen.dart|*.generated.*) continue ;;
        esac

        ((file_count++))
        local lines
        lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')

        if [[ -n "$lines" ]]; then
            # Get relative path for cleaner output
            local rel_path="${file#$dir/}"
            [[ "$rel_path" == "$file" ]] && rel_path="$file"

            if [[ "$lines" -gt "$error_threshold" ]]; then
                print_error "$rel_path" "($lines lines, limit: $error_threshold)" "file-length" "$lines" "$error_threshold"
            elif [[ "$lines" -gt "$warn_threshold" ]]; then
                print_warning "$rel_path" "($lines lines, limit: $warn_threshold)" "file-length" "$lines" "$warn_threshold"
            fi
        fi
    done < <(find "$dir" -type f \( "${find_expr[@]}" \) -print0 2>/dev/null)

    increment_files "$file_count"
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <directory> <extensions> [warn_threshold] [error_threshold]"
        echo "  extensions: space-separated list (e.g., 'ex exs' or 'ts tsx')"
        echo "  warn_threshold: lines before warning (default: 300)"
        echo "  error_threshold: lines before error (default: 500)"
        exit 1
    fi

    dir="$1"
    extensions="$2"
    warn="${3:-300}"
    error="${4:-500}"

    print_header "FILE LENGTH"
    check_file_length "$dir" "$extensions" "$warn" "$error"
    print_summary

    exit "$(get_exit_code)"
fi
