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

# JSON output buffer
JSON_ISSUES=()

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

# Print an error (file too long, function too long, etc.)
print_error() {
    local file="$1"
    local message="$2"
    local check_type="${3:-}"
    local value="${4:-}"
    local limit="${5:-}"

    ((TOTAL_ERRORS++))

    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "${RED}ERROR${NC}  $file $message"
    else
        local json_entry="{\"severity\":\"error\",\"file\":\"$file\",\"message\":\"$message\""
        [[ -n "$check_type" ]] && json_entry+=",\"type\":\"$check_type\""
        [[ -n "$value" ]] && json_entry+=",\"value\":$value"
        [[ -n "$limit" ]] && json_entry+=",\"limit\":$limit"
        json_entry+="}"
        JSON_ISSUES+=("$json_entry")
    fi
}

# Print a warning
print_warning() {
    local file="$1"
    local message="$2"
    local check_type="${3:-}"
    local value="${4:-}"
    local limit="${5:-}"

    ((TOTAL_WARNINGS++))

    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "${YELLOW}WARN${NC}   $file $message"
    else
        local json_entry="{\"severity\":\"warning\",\"file\":\"$file\",\"message\":\"$message\""
        [[ -n "$check_type" ]] && json_entry+=",\"type\":\"$check_type\""
        [[ -n "$value" ]] && json_entry+=",\"value\":$value"
        [[ -n "$limit" ]] && json_entry+=",\"limit\":$limit"
        json_entry+="}"
        JSON_ISSUES+=("$json_entry")
    fi
}

# Print summary
print_summary() {
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo ""
        echo -e "${BOLD}--- SUMMARY ---${NC}"
        echo "Files scanned: $TOTAL_FILES"
        if [[ $TOTAL_ERRORS -gt 0 ]]; then
            echo -e "Errors: ${RED}$TOTAL_ERRORS${NC}"
        else
            echo -e "Errors: ${GREEN}0${NC}"
        fi
        if [[ $TOTAL_WARNINGS -gt 0 ]]; then
            echo -e "Warnings: ${YELLOW}$TOTAL_WARNINGS${NC}"
        else
            echo -e "Warnings: ${GREEN}0${NC}"
        fi
    fi
}

# Print full JSON output
print_json_output() {
    local project="$1"
    local languages="$2"

    echo "{"
    echo "  \"project\": \"$project\","
    echo "  \"languages\": [$(echo "$languages" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/' )],"
    echo "  \"issues\": ["

    local first=true
    for issue in "${JSON_ISSUES[@]}"; do
        if [[ "$first" == "true" ]]; then
            echo "    $issue"
            first=false
        else
            echo "    ,$issue"
        fi
    done

    echo "  ],"
    echo "  \"summary\": {"
    echo "    \"files\": $TOTAL_FILES,"
    echo "    \"errors\": $TOTAL_ERRORS,"
    echo "    \"warnings\": $TOTAL_WARNINGS"
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
    TOTAL_ERRORS=0
    TOTAL_WARNINGS=0
    TOTAL_FILES=0
    JSON_ISSUES=()
}

# Get exit code based on errors/warnings
get_exit_code() {
    if [[ $TOTAL_ERRORS -gt 0 ]]; then
        echo 2
    elif [[ $TOTAL_WARNINGS -gt 0 ]]; then
        echo 1
    else
        echo 0
    fi
}
