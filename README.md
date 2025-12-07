# code-smells

A fast command-line tool to detect code smells across multiple programming languages. Available as a single binary (Rust) or portable shell scripts.

## Features

- **Multi-language support**: Elixir, Dart, TypeScript, Python, Rust
- **Auto-detection**: Automatically identifies languages in your project
- **Three types of checks**:
  - File length (too many lines per file)
  - Function/method length (functions that are too long)
  - Nesting depth (deeply nested code blocks)
- **Portable**: Works on macOS and Linux
- **Configurable**: Override thresholds via command-line arguments

## Installation

### Pre-built binary (recommended)

Downloads a single binary with no dependencies:

```bash
curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/rust/install.sh | bash
```

### Shell script version

If you prefer the bash/awk version (no compilation needed):

```bash
curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/install.sh | bash
```

### Build from source

Requires [Rust](https://rustup.rs/):

```bash
cargo install --git https://github.com/byronsalty/code-smells --path rust
```

### Uninstall

```bash
# For binary version:
curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/rust/install.sh | bash -s -- --uninstall

# For shell script version:
curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/install.sh | bash -s -- --uninstall
```

## Usage

```bash
# Analyze current directory (auto-detects languages)
csmells

# Analyze a specific project
csmells /path/to/project

# Run specific checks only
csmells --check file-length
csmells --check functions
csmells --check nesting

# Specify languages manually
csmells --lang python
csmells --lang elixir,typescript

# Override thresholds
csmells --func-warn 25 --func-error 40

# Output as JSON
csmells --format json
```

## Default Thresholds

| Language | Metric | Warning | Error |
|----------|--------|---------|-------|
| **Elixir** | File length | 300 | 500 |
| | Function length | 30 | 50 |
| | Nesting depth | 4 | 6 |
| **Dart** | File length | 400 | 600 |
| | Method length | 40 | 70 |
| | Nesting depth | 4 | 6 |
| **TypeScript** | File length | 250 | 400 |
| | Function length | 50 | 80 |
| | Nesting depth | 4 | 6 |
| **Python** | File length | 300 | 500 |
| | Function length | 30 | 50 |
| | Nesting depth | 4 | 6 |
| **Rust** | File length | 400 | 600 |
| | Function length | 40 | 60 |
| | Nesting depth | 4 | 6 |

## Example Output

```
=== Code Smells Report ===
Project: /Users/dev/myproject
Languages: elixir, typescript

--- ERRORS (3) ---
ERROR  lib/myapp/large_module.ex (892 lines, limit: 500)
ERROR  lib/myapp/large_module.ex:156 process_data (87 lines)
ERROR  src/api.ts:42 handleRequest (95 lines)

--- WARNINGS (2) ---
WARN   lib/myapp/utils.ex (345 lines, limit: 300)
WARN   lib/myapp/large_module.ex:156 process_data (depth: 5)

--- SUMMARY ---
Files scanned: 24
Errors: 3
Warnings: 2
```

## Language Detection

The tool automatically detects languages based on project marker files:

| Language | Detected by |
|----------|-------------|
| Elixir | `mix.exs` |
| Dart | `pubspec.yaml` |
| TypeScript | `tsconfig.json` or `package.json` + `.ts` files |
| Python | `setup.py`, `pyproject.toml`, or `requirements.txt` |
| Rust | `Cargo.toml` |

## Options

```
Usage: csmells [OPTIONS] [DIRECTORY]

OPTIONS:
    -h, --help              Show help message
    -c, --check TYPE        Check type: all, file-length, functions, nesting
    -l, --lang LANGUAGES    Comma-separated: elixir,dart,typescript,python,rust
    -f, --format FORMAT     Output format: text, json

    Threshold overrides:
    --file-warn N           File length warning threshold
    --file-error N          File length error threshold
    --func-warn N           Function length warning threshold
    --func-error N          Function length error threshold
    --nest-warn N           Nesting depth warning threshold
    --nest-error N          Nesting depth error threshold
```

## Exit Codes

- `0` - No issues found
- `1` - Warnings found (but no errors)
- `2` - Errors found

## Contributing

See [DEVELOPER.md](DEVELOPER.md) for build instructions, adding new languages, and release process.

## License

MIT License - see [LICENSE](LICENSE) file.
