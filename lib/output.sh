#!/bin/bash
# output.sh - Shared output formatting for code-smells toolkit
# Provides colored terminal output and JSON formatting

# Guard against double-sourcing
OUTPUT_SH_LOADED=1

# Colors (only if terminal supports it)
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'  # No Color
else
    RED=''
    YELLOW=''
    GREEN=''
    BLUE=''
    BOLD=''
    NC=''
fi

# Global counters
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
TOTAL_FILES=0

# Output format (text or json)
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"

# Severity filter (all, errors, warnings)
SEVERITY_FILTER="${SEVERITY_FILTER:-all}"

# Temp files for buffered output (handles subshell issues)
_OUTPUT_TMPDIR="${TMPDIR:-/tmp}"
ERROR_BUFFER_FILE="$_OUTPUT_TMPDIR/csmells_errors_$$"
WARNING_BUFFER_FILE="$_OUTPUT_TMPDIR/csmells_warnings_$$"
JSON_BUFFER_FILE="$_OUTPUT_TMPDIR/csmells_json_$$"

# Initialize/clear temp files
: > "$ERROR_BUFFER_FILE"
: > "$WARNING_BUFFER_FILE"
: > "$JSON_BUFFER_FILE"

# Cleanup on exit
trap 'rm -f "$ERROR_BUFFER_FILE" "$WARNING_BUFFER_FILE" "$JSON_BUFFER_FILE"' EXIT

# Print section header
print_header() {
    local title="$1"
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo ""
        echo -e "${BOLD}--- $title ---${NC}"
    fi
}

# Print report header
print_report_header() {
    local project="$1"
    local languages="$2"
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "${BOLD}=== Code Smells Report ===${NC}"
        echo "Project: $project"
        echo "Languages: $languages"
    fi
}

# Buffer an error (file too long, function too long, etc.)
print_error() {
    local file="$1"
    local message="$2"
    local check_type="${3:-}"
    local value="${4:-}"
    local limit="${5:-}"

    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        # Buffer for grouped output (using file to handle subshells)
        echo "$file $message" >> "$ERROR_BUFFER_FILE"
    else
        local json_entry="{\"severity\":\"error\",\"file\":\"$file\",\"message\":\"$message\""
        [[ -n "$check_type" ]] && json_entry+=",\"type\":\"$check_type\""
        [[ -n "$value" ]] && json_entry+=",\"value\":$value"
        [[ -n "$limit" ]] && json_entry+=",\"limit\":$limit"
        json_entry+="}"
        echo "$json_entry" >> "$JSON_BUFFER_FILE"
    fi
}

# Buffer a warning
print_warning() {
    local file="$1"
    local message="$2"
    local check_type="${3:-}"
    local value="${4:-}"
    local limit="${5:-}"

    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        # Buffer for grouped output (using file to handle subshells)
        echo "$file $message" >> "$WARNING_BUFFER_FILE"
    else
        local json_entry="{\"severity\":\"warning\",\"file\":\"$file\",\"message\":\"$message\""
        [[ -n "$check_type" ]] && json_entry+=",\"type\":\"$check_type\""
        [[ -n "$value" ]] && json_entry+=",\"value\":$value"
        [[ -n "$limit" ]] && json_entry+=",\"limit\":$limit"
        json_entry+="}"
        echo "$json_entry" >> "$JSON_BUFFER_FILE"
    fi
}

# Print grouped issues and summary
print_summary() {
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        local error_count=0
        local warning_count=0

        # Count issues
        if [[ -s "$ERROR_BUFFER_FILE" ]]; then
            error_count=$(wc -l < "$ERROR_BUFFER_FILE" | tr -d ' ')
        fi
        if [[ -s "$WARNING_BUFFER_FILE" ]]; then
            warning_count=$(wc -l < "$WARNING_BUFFER_FILE" | tr -d ' ')
        fi

        # Print errors (if not filtering to warnings only)
        if [[ "$SEVERITY_FILTER" != "warnings" ]] && [[ $error_count -gt 0 ]]; then
            echo ""
            echo -e "${BOLD}--- ERRORS ($error_count) ---${NC}"
            while IFS= read -r entry; do
                echo -e "${RED}ERROR${NC}  $entry"
            done < "$ERROR_BUFFER_FILE"
        fi

        # Print warnings (if not filtering to errors only)
        if [[ "$SEVERITY_FILTER" != "errors" ]] && [[ $warning_count -gt 0 ]]; then
            echo ""
            echo -e "${BOLD}--- WARNINGS ($warning_count) ---${NC}"
            while IFS= read -r entry; do
                echo -e "${YELLOW}WARN${NC}   $entry"
            done < "$WARNING_BUFFER_FILE"
        fi

        # Print summary
        echo ""
        echo -e "${BOLD}--- SUMMARY ---${NC}"
        echo "Files scanned: $TOTAL_FILES"
        if [[ $error_count -gt 0 ]]; then
            echo -e "Errors: ${RED}$error_count${NC}"
        else
            echo -e "Errors: ${GREEN}0${NC}"
        fi
        if [[ $warning_count -gt 0 ]]; then
            echo -e "Warnings: ${YELLOW}$warning_count${NC}"
        else
            echo -e "Warnings: ${GREEN}0${NC}"
        fi
    fi
}

# Print full JSON output
print_json_output() {
    local project="$1"
    local languages="$2"

    local error_count=0
    local warning_count=0
    if [[ -s "$JSON_BUFFER_FILE" ]]; then
        error_count=$(grep -c '"severity":"error"' "$JSON_BUFFER_FILE" 2>/dev/null || echo 0)
        warning_count=$(grep -c '"severity":"warning"' "$JSON_BUFFER_FILE" 2>/dev/null || echo 0)
    fi

    echo "{"
    echo "  \"project\": \"$project\","
    echo "  \"languages\": [$(echo "$languages" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/' )],"
    echo "  \"issues\": ["

    local first=true
    if [[ -s "$JSON_BUFFER_FILE" ]]; then
        while IFS= read -r issue; do
            if [[ "$first" == "true" ]]; then
                echo "    $issue"
                first=false
            else
                echo "    ,$issue"
            fi
        done < "$JSON_BUFFER_FILE"
    fi

    echo "  ],"
    echo "  \"summary\": {"
    echo "    \"files\": $TOTAL_FILES,"
    echo "    \"errors\": $error_count,"
    echo "    \"warnings\": $warning_count"
    echo "  }"
    echo "}"
}

# Increment file counter
increment_files() {
    local count="${1:-1}"
    ((TOTAL_FILES += count))
}

# Reset counters (useful for testing)
reset_counters() {
    TOTAL_FILES=0
    : > "$ERROR_BUFFER_FILE"
    : > "$WARNING_BUFFER_FILE"
    : > "$JSON_BUFFER_FILE"
}

# Get exit code based on errors/warnings
get_exit_code() {
    local error_count=0
    local warning_count=0

    if [[ -s "$ERROR_BUFFER_FILE" ]]; then
        error_count=$(wc -l < "$ERROR_BUFFER_FILE" | tr -d ' ')
    elif [[ -s "$JSON_BUFFER_FILE" ]]; then
        error_count=$(grep -c '"severity":"error"' "$JSON_BUFFER_FILE" 2>/dev/null || echo 0)
    fi

    if [[ -s "$WARNING_BUFFER_FILE" ]]; then
        warning_count=$(wc -l < "$WARNING_BUFFER_FILE" | tr -d ' ')
    elif [[ -s "$JSON_BUFFER_FILE" ]]; then
        warning_count=$(grep -c '"severity":"warning"' "$JSON_BUFFER_FILE" 2>/dev/null || echo 0)
    fi

    if [[ $error_count -gt 0 ]]; then
        echo 2
    elif [[ $warning_count -gt 0 ]]; then
        echo 1
    else
        echo 0
    fi
}
