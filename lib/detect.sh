#!/bin/bash
# detect.sh - Language/framework auto-detection for code-smells toolkit
# Scans project root for marker files and returns detected languages with source directories

# Detect languages in a project directory
# Returns: space-separated list of "language:source_dir" pairs
detect_languages() {
    local project_dir="$1"
    local detected=()

    # Elixir/Phoenix - look for mix.exs
    if [[ -f "$project_dir/mix.exs" ]]; then
        detected+=("elixir:lib")
    fi

    # Dart/Flutter - look for pubspec.yaml
    if [[ -f "$project_dir/pubspec.yaml" ]]; then
        detected+=("dart:lib")
    fi

    # TypeScript - look for tsconfig.json or package.json with .ts files
    if [[ -f "$project_dir/tsconfig.json" ]] || \
       ([[ -f "$project_dir/package.json" ]] && find "$project_dir" -maxdepth 3 -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -1 | grep -q .); then
        # Prefer src/ if it exists, otherwise use current dir
        if [[ -d "$project_dir/src" ]]; then
            detected+=("typescript:src")
        else
            detected+=("typescript:.")
        fi
    fi

    # Python - look for setup.py, pyproject.toml, or requirements.txt
    if [[ -f "$project_dir/setup.py" ]] || [[ -f "$project_dir/pyproject.toml" ]] || [[ -f "$project_dir/requirements.txt" ]]; then
        if [[ -d "$project_dir/src" ]]; then
            detected+=("python:src")
        else
            detected+=("python:.")
        fi
    fi

    # Go - look for go.mod
    if [[ -f "$project_dir/go.mod" ]]; then
        detected+=("go:.")
    fi

    # Rust - look for Cargo.toml
    if [[ -f "$project_dir/Cargo.toml" ]]; then
        detected+=("rust:src")
    fi

    # Ruby - look for Gemfile
    if [[ -f "$project_dir/Gemfile" ]]; then
        if [[ -d "$project_dir/lib" ]]; then
            detected+=("ruby:lib")
        elif [[ -d "$project_dir/app" ]]; then
            detected+=("ruby:app")
        else
            detected+=("ruby:.")
        fi
    fi

    # JavaScript (without TypeScript) - package.json with .js files but no tsconfig
    if [[ -f "$project_dir/package.json" ]] && [[ ! -f "$project_dir/tsconfig.json" ]]; then
        if [[ -d "$project_dir/src" ]]; then
            detected+=("javascript:src")
        else
            detected+=("javascript:.")
        fi
    fi

    echo "${detected[@]+"${detected[@]}"}"
}

# Recursively scan for nested projects (e.g., monorepos)
# Returns: list of "path:language:source_dir" entries
detect_nested_projects() {
    local project_dir="$1"
    local max_depth="${2:-2}"
    local results=()

    # First check the root
    local root_langs
    root_langs=$(detect_languages "$project_dir")
    if [[ -n "$root_langs" ]]; then
        for lang_info in $root_langs; do
            results+=(".:$lang_info")
        done
    fi

    # Then check subdirectories (up to max_depth)
    while IFS= read -r -d '' subdir; do
        local rel_path="${subdir#$project_dir/}"

        # Skip common non-project directories
        case "$rel_path" in
            node_modules*|deps*|_build*|.dart_tool*|build*|dist*|vendor*|.git*) continue ;;
        esac

        local sub_langs
        sub_langs=$(detect_languages "$subdir")
        if [[ -n "$sub_langs" ]]; then
            for lang_info in $sub_langs; do
                results+=("$rel_path:$lang_info")
            done
        fi
    done < <(find "$project_dir" -mindepth 1 -maxdepth "$max_depth" -type d -print0 2>/dev/null)

    echo "${results[@]+"${results[@]}"}"
}

# Get just the language names (for display)
get_language_names() {
    local detected="$1"
    local names=()

    for entry in $detected; do
        local lang="${entry%%:*}"
        # Remove path prefix if present (from nested detection)
        lang="${lang##*:}"
        # Extract just the language part
        if [[ "$entry" == *":"*":"* ]]; then
            lang=$(echo "$entry" | cut -d: -f2)
        fi
        # Add to names if not already present
        local found=false
        for existing in "${names[@]+"${names[@]}"}"; do
            if [[ "$existing" == "$lang" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            names+=("$lang")
        fi
    done

    echo "${names[*]+"${names[*]}"}"
}

# Get file extensions for a language
get_extensions() {
    local lang="$1"
    case "$lang" in
        elixir) echo "ex exs" ;;
        dart) echo "dart" ;;
        typescript) echo "ts tsx" ;;
        javascript) echo "js jsx" ;;
        python) echo "py" ;;
        go) echo "go" ;;
        rust) echo "rs" ;;
        ruby) echo "rb" ;;
        *) echo "" ;;
    esac
}

# Check if a language is supported for function/nesting analysis
is_supported_for_analysis() {
    local lang="$1"
    case "$lang" in
        elixir|dart|typescript) return 0 ;;
        *) return 1 ;;
    esac
}
