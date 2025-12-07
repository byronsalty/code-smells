# Developer Guide

This document covers building from source, adding new languages, and the release process.

## Project Structure

```
code-smells/
├── code-smells          # Main bash script (shell version)
├── lib/                 # Shell script modules
│   ├── detect.sh        # Language auto-detection
│   ├── output.sh        # Output formatting
│   ├── file-length.sh   # File length check
│   ├── elixir.sh        # Elixir parser
│   ├── dart.sh          # Dart parser
│   ├── typescript.sh    # TypeScript parser
│   ├── python.sh        # Python parser
│   └── rust.sh          # Rust parser
├── rust/                # Rust implementation
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs
│       ├── cli.rs
│       ├── config.rs
│       ├── detect.rs
│       ├── output.rs
│       ├── checks/
│       └── languages/
└── .github/workflows/   # CI/CD
    └── release.yml      # Build and release binaries
```

## Building from Source

### Rust version

```bash
cd rust
cargo build --release
# Binary is at: target/release/code-smells
```

### Shell version

No build needed - the shell scripts run directly.

## Running Tests

### Rust

```bash
cd rust
cargo test
```

### Manual testing

```bash
# Create a test project
mkdir -p /tmp/test-project/src
echo '{"compilerOptions":{}}' > /tmp/test-project/tsconfig.json
cat > /tmp/test-project/src/test.ts << 'EOF'
function example() {
    // ... lots of lines ...
}
EOF

# Test both versions
./code-smells /tmp/test-project
./rust/target/release/code-smells /tmp/test-project
```

## Adding a New Language

### Rust version

1. Create `rust/src/languages/newlang.rs`:

```rust
use super::{FunctionInfo, LanguageParser};
use std::path::Path;

pub struct NewLangParser;

impl LanguageParser for NewLangParser {
    fn parse_functions(&self, content: &str) -> Vec<FunctionInfo> {
        // Implement parsing logic
        vec![]
    }

    fn should_skip(&self, path: &Path) -> bool {
        // Return true for paths to skip (build dirs, generated files)
        false
    }
}
```

2. Add to `rust/src/languages/mod.rs`:
   - Add `pub mod newlang;`
   - Add variant to `LanguageType` enum
   - Add match arms for `name()`, `extensions()`, etc.
   - Add case in `get_parser()`

3. Add detection in `rust/src/detect.rs`:
   - Check for marker files (e.g., `project.newlang`)

4. Add thresholds in `rust/src/config.rs`:
   - Add `LanguageType::NewLang` case in `Thresholds::for_language()`

### Shell version

1. Create `lib/newlang.sh` with:
   - `check_newlang_functions()` - Parse and check function lengths
   - `check_newlang_nesting()` - Parse and check nesting depth

2. Add detection in `lib/detect.sh`:
   - Add marker file check in `detect_languages()`

3. Add to main `code-smells` script:
   - Source the new file
   - Add default thresholds
   - Add case in the language loop

## Release Process

Releases are automated via GitHub Actions when you push a tag.

### Creating a Release

1. Update version in `rust/Cargo.toml`:
   ```toml
   version = "0.2.0"
   ```

2. Commit the change:
   ```bash
   git add rust/Cargo.toml
   git commit -m "Bump version to 0.2.0"
   ```

3. Create and push a tag:
   ```bash
   git tag v0.2.0
   git push origin main
   git push origin v0.2.0
   ```

4. GitHub Actions will automatically:
   - Build binaries for all platforms (macOS x64/ARM, Linux x64/ARM)
   - Create a GitHub Release with the binaries attached
   - Generate release notes from commits

### Supported Platforms

| Platform | Target |
|----------|--------|
| macOS (Intel) | `x86_64-apple-darwin` |
| macOS (Apple Silicon) | `aarch64-apple-darwin` |
| Linux (x64) | `x86_64-unknown-linux-gnu` |
| Linux (ARM64) | `aarch64-unknown-linux-gnu` |

### Manual Release (if needed)

Build for your current platform:

```bash
cd rust
cargo build --release
```

Cross-compile (requires appropriate toolchains):

```bash
rustup target add aarch64-apple-darwin
cargo build --release --target aarch64-apple-darwin
```

## Architecture Notes

### Parser Design

Both versions use state machines to parse source files:

- **Brace-based** (TypeScript, Dart, Rust): Track `{` and `}` depth
- **Keyword-based** (Elixir): Track `do`/`end` pairs
- **Indentation-based** (Python): Track whitespace indentation levels

### Performance Considerations

The Rust version is designed for future parallelization:
- `Language` trait is `Send + Sync`
- No shared mutable state during parsing
- Easy to add `rayon` for parallel file processing
