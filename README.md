# code-smells

A fast, portable command-line tool to detect code smells across multiple programming languages. No dependencies required - just bash and standard Unix tools.

## Features

- **Multi-language support**: Elixir, Dart, TypeScript, Python, Rust
- **Auto-detection**: Automatically identifies languages in your project
- **Three types of checks**:
  - File length (too many lines per file)
  - Function/method length (functions that are too long)
  - Nesting depth (deeply nested code blocks)
- **Portable**: Works on macOS and Linux with no external dependencies
- **Configurable**: Override thresholds via command-line arguments

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/install.sh | bash
```

### Manual installation

```bash
git clone https://github.com/byronsalty/code-smells.git ~/.local/bin/code-smells
ln -s ~/.local/bin/code-smells/code-smells ~/.local/bin/csmells
```

### Uninstall

```bash
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

--- FILE LENGTH (Elixir) ---
ERROR  lib/myapp/large_module.ex (892 lines, limit: 500)
WARN   lib/myapp/utils.ex (345 lines, limit: 300)

--- FUNCTION LENGTH (Elixir) ---
ERROR  lib/myapp/large_module.ex:156 process_data (87 lines)
WARN   lib/myapp/utils.ex:42 transform (35 lines)

--- NESTING DEPTH (Elixir) ---
WARN   lib/myapp/large_module.ex:156 process_data (depth: 5)

--- SUMMARY ---
Files scanned: 24
Errors: 2
Warnings: 3
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

## Adding New Languages

To add support for a new language:

1. Create `lib/newlang.sh` with these functions:
   - `check_newlang_functions()` - Check function lengths
   - `check_newlang_nesting()` - Check nesting depth
2. Add the language to `lib/detect.sh`
3. Add the language case to `code-smells` main script

## License

MIT License - see [LICENSE](LICENSE) file.
