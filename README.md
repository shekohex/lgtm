# LGTM - AI-Powered Git Commit Message Generator

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)

A universal Bash script that analyzes Git changes and generates conventional commit messages using AI. Built following the UNIX philosophy for seamless integration with existing workflows.

## Overview

**LGTM** (Looks Good To Me) is a command-line tool that automates the generation of meaningful commit messages by:

1. **Processing Git diff output** from staged/unstaged changes or piped input
2. **Filtering relevant code changes** using configurable patterns and file extensions
3. **Sending to AI models** via REST API with structured prompts
4. **Generating conventional commit messages** following industry standards
5. **Auto-committing** with user confirmation or outputting for pipeline integration

The tool adheres to the **UNIX philosophy** by accepting input from STDIN, producing clean output for piping, and doing one thing well - generating commit messages.

## Features

### Core Functionality

- ✅ **Universal Compatibility**: Works on Linux and macOS
- ✅ **AI-Powered Analysis**: Uses configurable AI models (OpenAI, Anthropic, local APIs)
- ✅ **Smart Filtering**: Ignores irrelevant files, focuses on code changes
- ✅ **Conventional Commits**: Generates standardized commit message format
- ✅ **Multiple Input Sources**: Auto-detects changes or reads from STDIN

### Operation Modes

- 🔍 **Dry-run Mode**: Preview generated messages without committing
- 🤖 **Auto-commit Mode**: Generate and commit with user confirmation
- 🔇 **Silent Mode**: Output only commit message for automation
- 📝 **Verbose Mode**: Detailed processing information for debugging

### File Filtering

- 🚫 **.lgtmignore Support**: Advanced ignore pattern configuration with priority-based aggregation

### UNIX Philosophy Compliance

- 📥 **STDIN Support**: Accepts `git diff` output from pipes
- 📤 **Clean Output**: Produces commit messages suitable for other tools
- ⚙️ **Environment-based Configuration**: No config files needed
- 🔗 **Pipeline-friendly**: Integrates seamlessly with Git workflows

## Installation

An installation script will be provided to install the tool system-wide. For now, you can use it directly:

```bash
# Make executable
chmod +x lgtm.sh

# Optional: Add to PATH
sudo cp lgtm.sh /usr/local/bin/lgtm
```

## Quick Start

1. **Configure API access**:

   ```bash
   export LGTM_API_URL="https://api.openai.com/v1/chat/completions"
   export LGTM_API_KEY="your-api-key-here"
   ```

2. **Basic usage**:

   ```bash
   # Preview commit message
   ./lgtm.sh --dry-run

   # Generate and output message (for automation)
   ./lgtm.sh --silent

   # Auto-commit with confirmation
   ./lgtm.sh --auto-commit
   ```

## Usage Instructions

### Command Line Options

```
Usage: lgtm.sh [OPTIONS]

Generate conventional commit messages using AI analysis of Git diff output.

OPTIONS:
    -d, --dry-run       Preview mode - show what would be done without making changes
    -a, --auto-commit   Automatically commit with generated message (requires confirmation)
    -P, --push          Automatically push to current branch after successful commit
    -v, --verbose       Enable verbose output for debugging
    -q, --silent        Suppress all output except the final commit message
    -s, --stdin         Read git diff output from STDIN
    -t, --max-tokens N        Maximum tokens for AI response (overrides environment)
    --max-input-tokens N      Maximum tokens for AI input (overrides environment)
    -i, --ignore PATTERN      Add ignore pattern (can be used multiple times)
    -h, --help          Show help message
```

### Usage Examples

#### Basic Operations

```bash
# Preview what would be committed
./lgtm.sh --dry-run

# Generate commit message silently (automation-friendly)
./lgtm.sh --silent

# Auto-commit with confirmation prompt
./lgtm.sh --auto-commit

# Auto-commit and push to current branch
./lgtm.sh --auto-commit --push

# Verbose output for debugging
./lgtm.sh --verbose --dry-run

# Custom token limits for AI model constraints
./lgtm.sh --max-tokens 150 --max-input-tokens 4000 --silent

# Override ignore patterns with CLI flags
./lgtm.sh --ignore "*.test.js" --ignore "coverage/*" --dry-run
```

#### UNIX Pipeline Integration

```bash
# Generate and use commit message
COMMIT_MSG=$(./lgtm.sh --silent)
git commit -m "$COMMIT_MSG"

# Analyze specific staged changes
git diff --cached | ./lgtm.sh --stdin --silent

# Analyze last commit
git diff HEAD~1 | ./lgtm.sh -s -q

# One-liner automated workflow
git add . && git commit -m "$(./lgtm.sh -q)"

# Integration with Git hooks
echo "$(git diff --cached | ./lgtm.sh -s -q)" > .git/PREPARE_COMMIT_MSG
```

#### Advanced Workflows

```bash
# Process specific file types only
export LGTM_INCLUDE_EXTENSIONS=".py,.js"
./lgtm.sh --dry-run

# Use custom ignore patterns via CLI
./lgtm.sh --ignore "*.test.js" --ignore "coverage/*" --dry-run

# Analyze large changes with bigger chunks
export LGTM_MAX_CHUNK_SIZE=8000
git diff HEAD~5 | ./lgtm.sh --stdin --verbose

# Use with different Git commands
git stash show -p | ./lgtm.sh --stdin --silent
git show <commit-hash> | ./lgtm.sh --stdin --silent
```

## Configuration

All configuration is handled through environment variables, following the UNIX philosophy of external configuration.

### Required Variables

| Variable       | Description            | Example                                      |
| -------------- | ---------------------- | -------------------------------------------- |
| `LGTM_API_URL` | AI API endpoint URL    | `https://api.openai.com/v1/chat/completions` |
| `LGTM_API_KEY` | API authentication key | `sk-...`                                     |

### Optional Configuration

| Variable                  | Description                       | Default   |
| ------------------------- | --------------------------------- | --------- |
| `LGTM_MAX_CHUNK_SIZE`     | Maximum characters per diff chunk | `4000`    |
| `LGTM_MAX_INPUT_TOKENS`   | Maximum tokens for AI input       | `8000`    |
| `LGTM_MAX_TOKENS`         | Maximum tokens for AI response    | `100`     |
| `LGTM_MODEL`              | AI model to use                   | `gpt-4`   |
| `LGTM_TEMPERATURE`        | Model creativity (0.0-2.0)        | `0.1`     |
| `LGTM_TOP_P`              | Top-p sampling value (0.0-1.0)    | `0.25`    |
| `LGTM_AUTO_PUSH`          | Auto-push after commit            | `false`   |
| `LGTM_IGNORE_PATTERNS`    | Comma-separated ignore patterns   | See below |
| `LGTM_INCLUDE_EXTENSIONS` | File extensions to analyze        | See below |

### Ignore Pattern Configuration

LGTM supports multiple sources for ignore patterns with the following priority order (highest to lowest):

1. **Environment Variable** (`LGTM_IGNORE_PATTERNS`)
2. **CLI Flags** (`--ignore` or `-i`)
3. **.lgtmignore file** (repository-specific patterns)
4. **.gitignore file** (Git ignore patterns)
5. **Default patterns** (built-in common patterns)

#### Default Ignore Patterns

```bash
LGTM_IGNORE_PATTERNS="*.log,*.tmp,node_modules/*,*.min.js,*.map,*.lock,*.md,*.txt,*.json,*.yaml,*.yml,*.xml,*.csv"
```

#### .lgtmignore File Format

Create a `.lgtmignore` file in your repository root to specify custom ignore patterns:

```bash
# LGTM ignore patterns
*.log
*.tmp
build/
dist/
*.min.js
*.map
node_modules/
__pycache__/
*.pyc
coverage/
.env*
```

The file follows the same format as `.gitignore` with one pattern per line. Comments (lines starting with `#`) are supported.

#### Pattern Priority Examples

```bash
# Environment variable takes highest priority
export LGTM_IGNORE_PATTERNS="*.log,*.tmp"

# CLI flags override .lgtmignore and .gitignore
./lgtm.sh --ignore "*.test.js" --ignore "coverage/*"

# .lgtmignore overrides .gitignore
echo "*.spec.js" >> .lgtmignore

# .gitignore patterns are used as fallback
# Default patterns are used if no other sources exist
```

#### How Pattern Aggregation Works

LGTM intelligently combines ignore patterns from all available sources:

1. **Starts with default patterns** for common files (logs, temp files, etc.)
2. **Adds .gitignore patterns** if the file exists
3. **Adds .lgtmignore patterns** if the file exists (higher priority than .gitignore)
4. **Adds CLI flag patterns** specified with `--ignore` (higher priority than files)
5. **Uses environment variable** `LGTM_IGNORE_PATTERNS` as highest priority if set

This approach ensures maximum flexibility while maintaining sensible defaults.

### Default Include Extensions

```bash
LGTM_INCLUDE_EXTENSIONS=".js,.ts,.py,.go,.rs,.java,.cpp,.c,.h,.php,.rb,.sh,.bash,.zsh"
```

### Configuration Examples

```bash
# OpenAI Configuration
export LGTM_API_URL="https://api.openai.com/v1/chat/completions"
export LGTM_API_KEY="sk-your-key-here"
export LGTM_MODEL="gpt-4"
export LGTM_TOP_P="0.25"

# Anthropic Claude Configuration
export LGTM_API_URL="https://api.anthropic.com/v1/messages"
export LGTM_API_KEY="your-anthropic-key"
export LGTM_MODEL="claude-3-sonnet-20240229"

# Local/Self-hosted API (Ollama, etc.)
export LGTM_API_URL="http://localhost:11434/v1/chat/completions"
export LGTM_MODEL="llama2"

# Custom filtering - Python projects only
export LGTM_INCLUDE_EXTENSIONS=".py"
export LGTM_IGNORE_PATTERNS="*.pyc,__pycache__/*,*.log"

# Override ignore patterns with CLI flags
./lgtm.sh --ignore "*.test.py" --ignore "migrations/*" --dry-run

# Large diff handling with optimized chunking
export LGTM_MAX_CHUNK_SIZE=8000
export LGTM_MAX_INPUT_TOKENS=6000
export LGTM_MAX_TOKENS=200

# Auto-push configuration
export LGTM_AUTO_PUSH=true
./lgtm.sh --auto-commit  # Will commit and push automatically
```

### .lgtmignore Configuration Examples

Create a `.lgtmignore` file for repository-specific ignore patterns:

```bash
# JavaScript/Node.js project
node_modules/
dist/
build/
*.min.js
*.bundle.js
coverage/
.env*
*.log

# Python project
__pycache__/
*.pyc
*.pyo
dist/
build/
*.egg-info/
.coverage
.pytest_cache/

# General development files
.DS_Store
*.swp
*.swo
*~
.vscode/
.idea/
```

### Environment File Usage

```bash
# Copy example configuration
cp .env.example .env

# Edit configuration
vim .env

# Load configuration
source .env

# Run with loaded config
./lgtm.sh --dry-run
```

## Integration

### Git Workflow Integration

The tool integrates seamlessly with standard Git workflows:

```bash
# Stage changes
git add .

# Generate and preview commit message
./lgtm.sh --dry-run

# Commit with generated message
git commit -m "$(./lgtm.sh --silent)"

# Or use auto-commit mode
./lgtm.sh --auto-commit

# Auto-commit and push in one step
./lgtm.sh --auto-commit --push

# Environment-based auto-push
export LGTM_AUTO_PUSH=true
./lgtm.sh --auto-commit
```

### Pipeline Integration

LGTM accepts input from STDIN and produces clean output, making it perfect for automation:

```bash
# CI/CD Pipeline example
git diff --cached | ./lgtm.sh --stdin --silent > commit-message.txt
git commit -F commit-message.txt

# Git hook integration (pre-commit)
#!/bin/bash
if [ -n "$(git diff --cached)" ]; then
    COMMIT_MSG=$(git diff --cached | ./lgtm.sh --stdin --silent)
    echo "Suggested commit message: $COMMIT_MSG"
fi
```

### Integration with Other Tools

```bash
# With GitHub CLI
gh pr create --title "$(./lgtm.sh --silent)" --body "Auto-generated PR"

# With conventional changelog tools
./lgtm.sh --silent | tee -a CHANGELOG.md

# With commit message linters
./lgtm.sh --silent | commitlint --stdin
```

## How It Works

### 1. Git Diff Processing

The script intelligently determines what changes to analyze:

- **Staged changes**: `git diff --cached` (highest priority)
- **Unstaged changes**: `git diff` (fallback)
- **Last commit**: `git diff HEAD~1` (when no current changes)
- **STDIN input**: Custom diff from pipes

### 2. Smart Content Filtering

Applies sophisticated filtering to focus on relevant changes:

- **Priority-based ignore patterns**: Aggregates patterns from multiple sources with defined precedence
- **Multiple ignore sources**: Environment variables, CLI flags, .lgtmignore, .gitignore, and defaults
- **Include extensions**: Focuses on specified programming languages
- **File-level filtering**: Preserves diff structure while filtering content
- **Size management**: Splits large diffs into manageable chunks

### 3. AI API Communication

Sends processed content to AI models with structured prompts:

- **System message**: Sets context for conventional commit generation
- **User message**: Contains filtered git diff output
- **Request format**: OpenAI-compatible JSON with configurable parameters
- **Error handling**: Graceful fallback and informative error messages

### 4. Output Generation

Produces clean, actionable results:

- **Conventional format**: `type(scope): description`
- **UNIX-friendly**: Clean output suitable for piping
- **Multiple modes**: Preview, auto-commit, or silent operation
- **Error reporting**: Clear feedback on issues

### Diff Analysis Intelligence

The tool processes various types of Git changes:

- **File additions**: New files and their content
- **File deletions**: Removed files (summarized)
- **File modifications**: Context lines and actual changes
- **File renames**: Rename operations with content changes
- **Binary files**: Handled appropriately without content analysis

## Conventional Commit Format

Generated messages follow the [Conventional Commits](https://conventionalcommits.org/) specification:

```
type(scope): description

Types:
- feat: A new feature
- fix: A bug fix
- docs: Documentation only changes
- style: Changes that do not affect code meaning
- refactor: Code change that neither fixes a bug nor adds a feature
- test: Adding missing tests or correcting existing tests
- chore: Changes to build process or auxiliary tools
- perf: Code change that improves performance
- ci: Changes to CI configuration files and scripts
- build: Changes that affect the build system or dependencies

Examples:
feat(auth): add OAuth2 integration with Google
fix(api): resolve null pointer exception in user service
docs(readme): update installation instructions
refactor(utils): simplify string manipulation functions
test(auth): add unit tests for login validation
chore(deps): update dependencies to latest versions
```

## Requirements

### System Requirements

- **Operating System**: Linux or macOS
- **Shell**: Bash 4.0+
- **Git**: Any recent version
- **Network**: Internet access for API calls

### Required Tools

- `curl` - For API communication
- `jq` - For JSON processing
- `git` - For repository operations

### API Requirements

- Valid API key for chosen AI service
- Sufficient API quota/credits
- Network access to API endpoint

### Installation Check

```bash
# Verify all requirements
command -v bash && echo "✓ Bash available"
command -v git && echo "✓ Git available"
command -v curl && echo "✓ curl available"
command -v jq && echo "✓ jq available"

# Check Git repository
git rev-parse --is-inside-work-tree && echo "✓ In Git repository"

# Check API configuration
[[ -n "$LGTM_API_URL" ]] && echo "✓ API URL configured"
[[ -n "$LGTM_API_KEY" ]] && echo "✓ API key configured"
```

## Troubleshooting

### Common Issues

**"Not in a Git repository"**

```bash
# Ensure you're in a Git repository
git init  # or cd to existing repository
```

**"Required tool not found"**

```bash
# Install missing tools (Ubuntu/Debian)
sudo apt-get install curl jq

# Install missing tools (macOS)
brew install curl jq
```

**"API call failed"**

```bash
# Check API configuration
echo $LGTM_API_URL
echo $LGTM_API_KEY

# Test API connectivity
curl -H "Authorization: Bearer $LGTM_API_KEY" $LGTM_API_URL
```

**"No git diff output found"**

```bash
# Check for changes
git status
git diff --cached  # staged changes
git diff           # unstaged changes

# Or provide input via STDIN
git diff HEAD~1 | ./lgtm.sh --stdin
```

### Debug Mode

```bash
# Enable verbose output for troubleshooting
./lgtm.sh --verbose --dry-run

# Check what files are being processed
export LGTM_INCLUDE_EXTENSIONS=".js,.py"
./lgtm.sh --verbose --dry-run 2>&1 | grep "Including\|Ignoring"
```

## API Compatibility

The script uses OpenAI-compatible API format. Supported services:

- **OpenAI**: GPT-3.5, GPT-4, GPT-4 Turbo
- **Anthropic**: Claude 3 models (requires endpoint adjustment)
- **Local APIs**: Ollama, LocalAI, FastChat
- **Cloud APIs**: Azure OpenAI, AWS Bedrock (with compatible endpoints)

For non-OpenAI APIs, you may need to modify the JSON payload in the `call_ai_api()` function.

## Contributing

Contributions are welcome! Please ensure:

- Bash compatibility (Linux/macOS)
- UNIX philosophy compliance
- Comprehensive error handling
- Documentation updates

## License

MIT License - see LICENSE file for details.

---

**LGTM** - Because good commit messages shouldn't require manual effort.
