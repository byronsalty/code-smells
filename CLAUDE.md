# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

code-smells is a portable bash-based CLI tool that detects code smells (file length, function length, nesting depth) across multiple programming languages. It has no external dependencies beyond bash and standard Unix tools.

## Running the Tool

```bash
# Run from current directory (auto-detects languages)
./code-smells

# Analyze a specific project
./code-smells /path/to/project

# Run specific checks
./code-smells --check file-length
./code-smells --check functions
./code-smells --check nesting

# Specify languages manually
./code-smells --lang elixir,typescript

# Output as JSON
./code-smells --format json
```

## Architecture

The tool is structured as a main entry point (`code-smells`) that sources modular bash libraries from `lib/`:

- **code-smells** - Main script: parses CLI args, orchestrates detection and checks
- **lib/detect.sh** - Auto-detects languages via marker files (mix.exs, pubspec.yaml, tsconfig.json, etc.)
- **lib/output.sh** - Shared output formatting (colored terminal output, JSON), global counters
- **lib/file-length.sh** - Generic file length checker (works for all languages)
- **lib/{language}.sh** - Language-specific analyzers (elixir.sh, dart.sh, typescript.sh, python.sh, rust.sh)

Each language module exports functions following the pattern:
- `check_{lang}_functions()` - Analyzes function/method lengths
- `check_{lang}_nesting()` - Analyzes nesting depth

## Adding a New Language

1. Create `lib/newlang.sh` with `check_newlang_functions()` and `check_newlang_nesting()`
2. Add detection logic to `lib/detect.sh` in `detect_languages()`
3. Add the language case to the main `code-smells` script's check loop
4. Define default thresholds (FILE_WARN, FILE_ERROR, FUNC_WARN, FUNC_ERROR, NEST_WARN, NEST_ERROR)

## Exit Codes

- `0` - No issues found
- `1` - Warnings found (but no errors)
- `2` - Errors found
