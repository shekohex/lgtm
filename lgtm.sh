#!/usr/bin/env bash

# lgtm.sh - Universal Git commit message generator using AI
# Compatible with Linux and macOS

set -uo pipefail

# Load environment files if they exist
if [[ -f ".env.local" ]]; then
    source ".env.local"
fi

if [[ -f ".env" ]]; then
    source ".env"
fi

# Default configuration (can be overridden by environment variables)
: "${LGTM_API_URL:=""}"
: "${LGTM_API_KEY:=""}"
: "${LGTM_MAX_CHUNK_SIZE:=4000}"
: "${LGTM_MAX_INPUT_TOKENS:=8000}"
: "${LGTM_MAX_TOKENS:=100}"
: "${LGTM_IGNORE_PATTERNS:="*.log,*.tmp,node_modules/*,*.min.js,*.map,*.lock,*.md,*.txt,*.json,.toml,*.yaml,*.yml,*.xml,*.csv"}"
: "${LGTM_INCLUDE_EXTENSIONS:=".js,.ts,.tsx,.jsx,.py,.go,.rs,.java,.cpp,.c,.h,.php,.rb,.sh,.bash,.zsh"}"
: "${LGTM_MODEL:="gpt-4"}"
: "${LGTM_TEMPERATURE:="0.1"}"
: "${LGTM_TOP_P:="0.25"}"
: "${LGTM_TIMEOUT:="15"}"
: "${LGTM_AUTO_PUSH:="false"}"
: "${LGTM_SYSTEM_MESSAGE:=""}"

# Global variables
DRY_RUN=false
AUTO_COMMIT=true
VERBOSE=false
INPUT_FROM_STDIN=false
SILENT=false
AUTO_PUSH=false

# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Print functions
print_error() {
    [[ "$SILENT" != "true" ]] && echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    [[ "$SILENT" != "true" ]] && echo -e "${GREEN}$1${NC}" >&2
}

print_warning() {
    [[ "$SILENT" != "true" ]] && echo -e "${YELLOW}Warning: $1${NC}" >&2
}

print_info() {
    [[ "$SILENT" != "true" ]] && echo -e "${BLUE}$1${NC}" >&2
}

print_verbose() {
    [[ "$VERBOSE" == "true" && "$SILENT" != "true" ]] && echo -e "${BLUE}[VERBOSE] $1${NC}" >&2
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate conventional commit messages using AI analysis of Git diff output.

OPTIONS:
    -d, --dry-run                    Preview mode - show what would be done without making changes
    -a, --auto-commit                Automatically commit with generated message (requires -y confirmation)
    -P, --push                       Automatically push to current branch after successful commit
    -v, --verbose                    Enable verbose output
    -q, --silent                     Suppress all output except the final commit message
    -s, --stdin                      Read git diff from STDIN
    -h, --help                       Show this help message
    
    --api-url URL                    API endpoint URL (can be overridden by LGTM_API_URL)
    --model MODEL                    AI model to use (can be overridden by LGTM_MODEL)
    --temperature TEMP               Model temperature 0.0-2.0 (can be overridden by LGTM_TEMPERATURE)
    --top-p VALUE                   Top-p (nucleus) sampling parameter 0.0-1.0 (can be overridden by LGTM_TOP_P)
    -t, --max-tokens NUM             Maximum tokens for response (can be overridden by LGTM_MAX_TOKENS)
    --max-input-tokens NUM           Maximum tokens for input (can be overridden by LGTM_MAX_INPUT_TOKENS)
    --max-chunk-size NUM             Maximum characters per chunk (can be overridden by LGTM_MAX_CHUNK_SIZE)
    --timeout SECONDS                API request timeout in seconds (can be overridden by LGTM_TIMEOUT)
    --ignore PATTERNS                Ignore patterns (can be specified multiple times, merged with .lgtmignore and .gitignore)
    --ignore-patterns PATTERNS       Comma-separated ignore patterns (can be overridden by LGTM_IGNORE_PATTERNS)
    --include EXTS                   Include file extensions (can be specified multiple times)
    --include-extensions EXTS        Comma-separated file extensions (can be overridden by LGTM_INCLUDE_EXTENSIONS)
    --system-message MSG             Custom AI system message (can be overridden by LGTM_SYSTEM_MESSAGE)

ENVIRONMENT VARIABLES:
    LGTM_API_URL           API endpoint URL (required)
    LGTM_API_KEY           API authentication key (required)
    LGTM_MODEL             AI model to use (default: gpt-4)
    LGTM_TEMPERATURE       Model temperature (default: 0.1)
    LGTM_TOP_P            Top-p sampling parameter (default: 0.25)
    LGTM_MAX_TOKENS        Maximum tokens for response (default: 100)
    LGTM_MAX_INPUT_TOKENS  Maximum tokens for input (default: 8000)
    LGTM_MAX_CHUNK_SIZE    Maximum characters per chunk (default: 4000)
    LGTM_TIMEOUT          API request timeout in seconds (default: 15)
    LGTM_AUTO_PUSH         Auto-push after commit (default: false)
    LGTM_IGNORE_PATTERNS   Comma-separated ignore patterns (default: common files)
    LGTM_INCLUDE_EXTENSIONS Comma-separated file extensions to include
    LGTM_SYSTEM_MESSAGE    Custom AI system message for commit generation

NOTE: Environment variables take precedence over CLI flags when both are provided.

IGNORE PATTERN PRIORITY (highest to lowest):
    1. LGTM_IGNORE_PATTERNS environment variable (overrides all)
    2. CLI --ignore flags
    3. .lgtmignore file patterns
    4. .gitignore file patterns
    5. Default ignore patterns

EXAMPLES:
    $0 --dry-run                       # Preview commit message
    $0 --auto-commit --push            # Auto-commit and push to current branch
    $0 --api-url "http://localhost:11434/v1/chat/completions" --model "llama2"
    $0 --ignore "*.log" --ignore "*.tmp" --include ".js" --include ".ts"
    git diff --cached | $0 -s         # Process specific diff from STDIN
    git diff HEAD~1 | $0 -s           # Process diff from last commit

EOF
}

# Read and parse ignore file patterns (supports .gitignore and .lgtmignore)
read_ignore_patterns() {
    local ignore_file="$1"
    local patterns=""
    
    [[ ! -f "$ignore_file" ]] && return 0
    
    while IFS= read -r line; do
        # Skip empty lines and full-line comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Handle inline comments by removing everything after unescaped #
        local processed_line="$line"
        processed_line="${processed_line//\\#/__ESCAPED_HASH__}"
        
        # Remove inline comment (everything after first unescaped #)
        [[ "$processed_line" == *"#"* ]] && processed_line="${processed_line%%#*}"
        
        # Restore escaped # characters and trim trailing whitespace
        processed_line="${processed_line//__ESCAPED_HASH__/#}"
        processed_line=$(echo "$processed_line" | sed 's/[[:space:]]*$//')
        
        [[ -n "$processed_line" ]] && patterns="${patterns}${patterns:+,}$processed_line"
    done < "$ignore_file"
    
    echo "$patterns"
}

# Helper function to validate and set option values
validate_option() {
    local option="$1"
    local value="$2"
    local validation_type="${3:-}"
    
    if [[ -z "$value" ]]; then
        print_error "Option $option requires a value"
        usage
        exit 1
    fi
    
    case "$validation_type" in
        "numeric")
            if [[ ! "$value" =~ ^[0-9]+$ ]]; then
                print_error "Option $option requires a numeric value"
                usage
                exit 1
            fi
            ;;
        "float")
            if [[ ! "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                print_error "Option $option requires a numeric value (0.0-2.0)"
                usage
                exit 1
            fi
            ;;
    esac
}

# Aggregate patterns from array into comma-separated string
aggregate_patterns() {
    local -n arr_ref=$1
    local result=""
    
    if [[ ${#arr_ref[@]} -gt 0 ]]; then
        for pattern in "${arr_ref[@]}"; do
            result="${result}${result:+,}$pattern"
        done
    fi
    
    echo "$result"
}

# Parse command line arguments
parse_args() {
    # Initialize CLI argument variables
    local cli_api_url="" cli_model="" cli_temperature="" cli_top_p="" cli_max_tokens="" cli_max_input_tokens="" cli_max_chunk_size="" cli_timeout="" cli_system_message=""
    local cli_ignore_patterns
    local cli_include_extensions
    cli_ignore_patterns=()
    cli_include_extensions=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run) DRY_RUN=true; shift ;;
            -a|--auto-commit) AUTO_COMMIT=true; shift ;;
            -P|--push) AUTO_PUSH=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--silent) SILENT=true; shift ;;
            -s|--stdin) INPUT_FROM_STDIN=true; shift ;;
            -h|--help) usage; exit 0 ;;
            
            --api-url)
                validate_option "$1" "$2"
                cli_api_url="$2"; shift 2 ;;
            --model)
                validate_option "$1" "$2"
                cli_model="$2"; shift 2 ;;
            --temperature)
                validate_option "$1" "$2" "float"
                cli_temperature="$2"; shift 2 ;;
            --top-p)
                validate_option "$1" "$2" "float"
                cli_top_p="$2"; shift 2 ;;
            -t|--max-tokens)
                validate_option "$1" "$2" "numeric"
                cli_max_tokens="$2"; shift 2 ;;
            --max-input-tokens)
                validate_option "$1" "$2" "numeric"
                cli_max_input_tokens="$2"; shift 2 ;;
            --max-chunk-size)
                validate_option "$1" "$2" "numeric"
                cli_max_chunk_size="$2"; shift 2 ;;
            --timeout)
                validate_option "$1" "$2" "numeric"
                cli_timeout="$2"; shift 2 ;;
            --ignore|--ignore-patterns)
                validate_option "$1" "$2"
                cli_ignore_patterns+=("$2"); shift 2 ;;
            --include|--include-extensions)
                validate_option "$1" "$2"
                cli_include_extensions+=("$2"); shift 2 ;;
            --system-message)
                validate_option "$1" "$2"
                cli_system_message="$2"; shift 2 ;;
            *)
                print_error "Unknown option: $1"
                usage; exit 1 ;;
        esac
    done
    
    # Aggregate ignore patterns with priority: CLI > .lgtmignore > .gitignore > defaults
    # Environment variables override all CLI and file-based patterns
    if [[ -z "$LGTM_IGNORE_PATTERNS" ]]; then
        local aggregated_ignore=""
        local source_patterns
        
        # CLI patterns (highest priority)
        [[ ${#cli_ignore_patterns[@]} -gt 0 ]] && aggregated_ignore=$(aggregate_patterns cli_ignore_patterns)
        
        # .lgtmignore patterns (medium priority)
        source_patterns=$(read_ignore_patterns ".lgtmignore")
        [[ -n "$source_patterns" ]] && aggregated_ignore="${aggregated_ignore}${aggregated_ignore:+,}$source_patterns"
        
        # .gitignore patterns (lower priority)
        source_patterns=$(read_ignore_patterns ".gitignore")
        [[ -n "$source_patterns" ]] && aggregated_ignore="${aggregated_ignore}${aggregated_ignore:+,}$source_patterns"
        
        [[ -n "$aggregated_ignore" ]] && LGTM_IGNORE_PATTERNS="$aggregated_ignore"
    fi
    
    # Aggregate include patterns - merge CLI patterns with existing patterns
    if [[ ${#cli_include_extensions[@]} -gt 0 ]]; then
        local cli_patterns
        cli_patterns=$(aggregate_patterns cli_include_extensions)
        if [[ -n "$LGTM_INCLUDE_EXTENSIONS" ]]; then
            LGTM_INCLUDE_EXTENSIONS="${LGTM_INCLUDE_EXTENSIONS},${cli_patterns}"
        else
            LGTM_INCLUDE_EXTENSIONS="$cli_patterns"
        fi
    fi
    
    # Apply other CLI values only if environment variables are not set
    # Environment variables take precedence over CLI flags
    [[ -z "$LGTM_API_URL" && -n "$cli_api_url" ]] && LGTM_API_URL="$cli_api_url"
    [[ -z "$LGTM_MODEL" && -n "$cli_model" ]] && LGTM_MODEL="$cli_model"
    [[ -z "$LGTM_TEMPERATURE" && -n "$cli_temperature" ]] && LGTM_TEMPERATURE="$cli_temperature"
    [[ -z "$LGTM_TOP_P" && -n "$cli_top_p" ]] && LGTM_TOP_P="$cli_top_p"
    [[ -z "$LGTM_MAX_TOKENS" && -n "$cli_max_tokens" ]] && LGTM_MAX_TOKENS="$cli_max_tokens"
    [[ -z "$LGTM_MAX_INPUT_TOKENS" && -n "$cli_max_input_tokens" ]] && LGTM_MAX_INPUT_TOKENS="$cli_max_input_tokens"
    [[ -z "$LGTM_MAX_CHUNK_SIZE" && -n "$cli_max_chunk_size" ]] && LGTM_MAX_CHUNK_SIZE="$cli_max_chunk_size"
    [[ -z "$LGTM_TIMEOUT" && -n "$cli_timeout" ]] && LGTM_TIMEOUT="$cli_timeout"
    [[ -z "$LGTM_SYSTEM_MESSAGE" && -n "$cli_system_message" ]] && LGTM_SYSTEM_MESSAGE="$cli_system_message"
    
    # Apply push setting - environment variable takes precedence over CLI flag
    [[ "$LGTM_AUTO_PUSH" == "true" ]] && AUTO_PUSH=true
}

# Validate requirements
validate_requirements() {
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        print_error "Not in a Git repository"
        exit 1
    fi

    # Check required tools
    local required_tools=("curl" "git")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_error "Required tool not found: $tool"
            exit 1
        fi
    done

    # Check API configuration
    if [[ -z "$LGTM_API_URL" ]]; then
        print_error "LGTM_API_URL environment variable is required"
        exit 1
    fi

    if [[ -z "$LGTM_API_KEY" ]]; then
        print_error "LGTM_API_KEY environment variable is required"
        exit 1
    fi
}

# Check if file should be ignored based on patterns
should_ignore_file() {
    local file="$1"
    local filename=$(basename "$file")
    local extension="${filename##*.}"
    
    # Convert comma-separated patterns to arrays
    IFS=',' read -ra ignore_patterns <<< "$LGTM_IGNORE_PATTERNS"
    IFS=',' read -ra include_extensions <<< "$LGTM_INCLUDE_EXTENSIONS"
    
    # Check if file is in include list (if specified) - include patterns take precedence
    if [[ -n "$LGTM_INCLUDE_EXTENSIONS" ]]; then
        for pattern in "${include_extensions[@]}"; do
            pattern=$(echo "$pattern" | xargs) # trim whitespace
            
            # Check direct file/filename match
            [[ "$file" == $pattern || "$filename" == $pattern ]] && return 1 # should not ignore
            
            # Handle glob-like patterns
            case "$file" in $pattern) return 1 ;; esac
            case "$filename" in $pattern) return 1 ;; esac
            
            # Handle extension matching (for patterns like .md, .js, etc.)
            if [[ "$pattern" =~ ^\.[a-zA-Z0-9]+$ ]]; then
                local ext_pattern="${pattern#.}"  # remove leading dot
                [[ "$extension" == "$ext_pattern" ]] && return 1 # should not ignore
            fi
        done
        return 0 # not in include list, so ignore
    fi
    
    # Check ignore patterns (only if no include patterns specified)
    for pattern in "${ignore_patterns[@]}"; do
        pattern=$(echo "$pattern" | xargs) # trim whitespace
        [[ "$file" == $pattern || "$filename" == $pattern ]] && return 0
        
        # Handle glob-like patterns
        case "$file" in $pattern) return 0 ;; esac
        case "$filename" in $pattern) return 0 ;; esac
    done
    
    return 1 # don't ignore by default
}

# Process a single file block for filtering
process_file_block() {
    local current_file="$1"
    local current_block="$2"
    local -n filtered_diff_ref="$3"
    
    if ! should_ignore_file "$current_file"; then
        filtered_diff_ref="${filtered_diff_ref}${filtered_diff_ref:+$'\n'}${current_block}"
        print_verbose "Including diff for: $current_file"
    else
        print_verbose "Ignoring diff for: $current_file"
    fi
}

# Filter git diff output based on file patterns
filter_git_diff() {
    local diff_content="$1"
    local filtered_diff=""
    local current_file="" current_block=""
    local in_file_block=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^diff\ --git\ a/(.+)\ b/(.+)$ ]]; then
            # Capture the match immediately to avoid corruption
            local matched_file="${BASH_REMATCH[1]}"
            
            # Process previous block
            [[ "$in_file_block" == "true" && -n "$current_file" ]] &&
                process_file_block "$current_file" "$current_block" filtered_diff
            
            # Start new block
            current_file="$matched_file"
            current_block="$line"
            in_file_block=true
        elif [[ "$in_file_block" == "true" ]]; then
            current_block="${current_block}${current_block:+$'\n'}$line"
        fi
    done <<< "$diff_content"
    
    # Handle last block
    [[ "$in_file_block" == "true" && -n "$current_file" ]] &&
        process_file_block "$current_file" "$current_block" filtered_diff
    
    echo "$filtered_diff"
}

# Get git diff output
get_git_diff() {
    local diff_output=""
    
    if [[ "$INPUT_FROM_STDIN" == "true" ]]; then
        diff_output=$(cat)
    else
        # Priority: staged > unstaged > last commit
        if ! git diff --cached --quiet 2>/dev/null; then
            diff_output=$(git diff --cached --no-ext-diff -M -C -B --color=never 2>/dev/null || true)
            print_verbose "Using staged changes"
            print_verbose "Staged changes size: ${#diff_output} characters"
            print_verbose "Staged changes content: $(echo "$diff_output")" 
        elif ! git diff --quiet 2>/dev/null; then
            diff_output=$(git diff --no-ext-diff -M -C -B --color=never 2>/dev/null || true)
            print_verbose "Using unstaged changes"
            print_verbose "Unstaged changes size: ${#diff_output} characters"
            print_verbose "Unstaged changes content: $(echo "$diff_output")"
        else
            diff_output=$(git diff --no-ext-diff -M -C -B --color=never HEAD~1 2>/dev/null || git -c core.pager=cat show HEAD --format="" --no-ext-diff 2>/dev/null || true)
            print_verbose "Using last commit changes"
            print_verbose "Last commit changes size: ${#diff_output} characters"
            print_verbose "Last commit changes content: $(echo "$diff_output")"
        fi
    fi
    
    if [[ -z "$diff_output" ]]; then
        # Check if there are any files that could be staged
        local stageable_files
        stageable_files=$(git diff --name-only)
        
        if [[ -n "$stageable_files" ]]; then
            print_warning "No staged changes found, but there are files that could be staged:"
            echo "$stageable_files"
            print_warning "Would you like to stage these files? (y/N)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                if git add .; then
                    print_info "Files staged successfully"
                    # Try to get the diff again, now with staged files
                    diff_output=$(git diff --cached --no-ext-diff -M -C -B --color=never 2>/dev/null || true)
                    if [[ -n "$diff_output" ]]; then
                        return 0
                    fi
                else
                    print_error "Failed to stage files"
                fi
            fi
        fi
        print_warning "No git diff output found"
        return 1
    fi
    
    echo "$diff_output"
}

# Estimate token count (rough approximation: 1 token ≈ 4 characters)
estimate_token_count() {
    local content="$1"
    echo $(( ${#content} / 4 ))
}

# Split content into chunks
split_into_chunks() {
    local content="$1"
    local chunk_size="$LGTM_MAX_CHUNK_SIZE"
    local chunks=()
    local current_chunk=""
    
    while IFS= read -r line; do
        if (( ${#current_chunk} + ${#line} + 1 > chunk_size )) && [[ -n "$current_chunk" ]]; then
            chunks+=("$current_chunk")
            current_chunk="$line"
        else
            current_chunk="${current_chunk}${current_chunk:+$'\n'}$line"
        fi
    done <<< "$content"
    
    [[ -n "$current_chunk" ]] && chunks+=("$current_chunk")
    
    printf '%s\n' "${chunks[@]}"
}

# Call AI API to generate commit message
call_ai_api() {
    local content="$1"
    # Use custom system message if provided, otherwise use default
    local system_message
    if [[ -n "$LGTM_SYSTEM_MESSAGE" ]]; then
        system_message="$LGTM_SYSTEM_MESSAGE"
    else
        system_message="You are an expert software developer who generates conventional commit messages. Based on git diff output, create comprehensive commit messages using the format: type(scope): description

Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build

INSTRUCTIONS:
- Analyze ALL file changes in the diff to understand the complete scope of work
- Focus on the PRIMARY/MOST IMPORTANT change for the main commit message title
- Keep the main title under 50 characters when possible
- Use present tense (add, fix, update, not added, fixed, updated)
- Omit scope if not clear or applicable
- BREAKING CHANGE: a commit that has a footer BREAKING CHANGE:, or appends a ! after the type/scope, introduces a breaking API change (correlating with MAJOR in Semantic Versioning). A BREAKING CHANGE can be part of commits of any type.

COMMIT MESSAGE FORMAT:
- First line: Concise conventional commit message focusing on the primary change
- Empty line
- Body: Add 2-4 bullet points describing other significant changes, improvements, or secondary modifications that complement the main change. Include file-specific details for context.
- Empty line
- Footer (Optional): Include any relevant issue numbers, links, or additional context.

EXAMPLES:
---
feat: add user authentication system

- Implement JWT token validation middleware
- Add password hashing utilities
- Create user registration and login endpoints
- Update database schema with user table

Closes #123
---
fix: resolve memory leak in data processing

- Optimize buffer allocation in parser.js
- Add proper cleanup in event handlers
- Update documentation for memory best practices
---
chore!: drop support for Node 6

BREAKING CHANGE: use JavaScript features not available in Node 6.
---

Only return the commit message, body and footer, no explanations or additional text."
    fi

    local response
    local http_code
    
    # Create temporary files for response
    local temp_response=$(mktemp)
    local temp_header=$(mktemp)
    
    print_verbose "Calling AI API..."
    
    # Prepare JSON payload
    local json_payload
    json_payload=$(jq -n \
        --arg model "$LGTM_MODEL" \
        --arg system_msg "$system_message" \
        --arg user_msg "$content" \
        --argjson temperature "$LGTM_TEMPERATURE" \
        --argjson top_p "$LGTM_TOP_P" \
        --argjson max_tokens "$LGTM_MAX_TOKENS" \
        '{
            model: $model,
            messages: [
                {role: "system", content: $system_msg},
                {role: "user", content: $user_msg}
            ],
            temperature: $temperature,
            top_p: $top_p,
            max_tokens: $max_tokens
        }')
    
    print_verbose "API Request URL: $LGTM_API_URL"
    print_verbose "API Request Model: $LGTM_MODEL"
    print_verbose "API Request Temperature: $LGTM_TEMPERATURE"
    print_verbose "API Request Top-p: $LGTM_TOP_P"
    print_verbose "API Request Max Output Tokens: $LGTM_MAX_TOKENS"
    print_verbose "API Request Max Input Tokens: $LGTM_MAX_INPUT_TOKENS"
    print_verbose "API Request Timeout: ${LGTM_TIMEOUT}s"
    print_verbose "API Request Content Length: ${#content} characters"
    print_verbose "API Request Estimated Input Tokens: $(estimate_token_count "$content")"
    
    # Make API call with proper system/user message structure
    http_code=$(curl -s -w "%{http_code}" \
        --max-time "$LGTM_TIMEOUT" \
        --connect-timeout "$LGTM_TIMEOUT" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $LGTM_API_KEY" \
        -d "$json_payload" \
        -o "$temp_response" \
        -D "$temp_header" \
        "$LGTM_API_URL")
    
    print_verbose "API Response HTTP Code: $http_code"
    
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        print_verbose "API Response Body: $(cat "$temp_response")"
        # Extract message from response (adjust based on API format)
        response=$(jq -r '.choices[0].message.content // .message // .text // .' "$temp_response" 2>/dev/null)
        print_verbose "Extracted commit message: $response"
        echo "$response"
    else
        print_error "API call failed with HTTP code: $http_code"
        print_verbose "Error Response Headers: $(cat "$temp_header")"
        print_verbose "Error Response Body: $(cat "$temp_response")"
        rm -f "$temp_response" "$temp_header"
        return 1
    fi
    
    rm -f "$temp_response" "$temp_header"
}

# Generate commit message
generate_commit_message() {
    print_info "Analyzing git diff..."
    
    # Get git diff output
    local diff_output
    diff_output=$(get_git_diff)
    
    if [[ -z "$diff_output" ]]; then
        print_error "No git diff content to analyze"
        return 1
    fi
    
    print_verbose "Raw diff size: ${#diff_output} characters"
    
    # Filter diff based on file patterns
    local filtered_diff
    filtered_diff=$(filter_git_diff "$diff_output")
    
    if [[ -z "$filtered_diff" ]]; then
        print_warning "No relevant changes found after filtering"
        return 1
    fi
    
    print_verbose "Filtered diff size: ${#filtered_diff} characters"
    
    # Check if content needs chunking based on size and token limits
    local content_to_send="$filtered_diff"
    local estimated_tokens=$(estimate_token_count "$filtered_diff")
    
    print_verbose "Estimated tokens: $estimated_tokens (limit: $LGTM_MAX_INPUT_TOKENS)"
    print_verbose "Content size: ${#filtered_diff} characters (chunk limit: $LGTM_MAX_CHUNK_SIZE)"
    
    # Only chunk if content exceeds limits
    if [[ ${#filtered_diff} -gt $LGTM_MAX_CHUNK_SIZE ]] || [[ $estimated_tokens -gt $LGTM_MAX_INPUT_TOKENS ]]; then
        print_verbose "Content exceeds limits, chunking required"
        
        local chunks=()
        while IFS= read -r chunk; do
            [[ -n "$chunk" ]] && chunks+=("$chunk")
        done < <(split_into_chunks "$filtered_diff")
        
        print_verbose "Generated ${#chunks[@]} chunks"
        content_to_send="${chunks[0]}"
        print_verbose "Using first chunk due to size/token limit"
    else
        print_verbose "Content within limits, no chunking needed"
    fi
    
    # Call AI API
    local commit_message
    commit_message=$(call_ai_api "$content_to_send")
    
    if [[ -n "$commit_message" ]]; then
        echo "$commit_message"
    else
        print_error "Failed to generate commit message"
        return 1
    fi
}

# Push to current branch
push_to_current_branch() {
    print_verbose "Attempting to push to current branch..."
    
    # Get current branch name
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    
    if [[ -z "$current_branch" ]]; then
        print_error "Could not determine current branch for push"
        return 1
    fi
    
    print_verbose "Current branch: $current_branch"
    
    # Check if remote exists
    local remote_url
    remote_url=$(git config --get "branch.$current_branch.remote" 2>/dev/null || echo "origin")
    
    if ! git remote get-url "$remote_url" >/dev/null 2>&1; then
        print_error "Remote '$remote_url' not found. Cannot push."
        return 1
    fi
    
    print_info "Pushing to $remote_url/$current_branch..."
    
    if git push "$remote_url" "$current_branch"; then
        print_success "Successfully pushed to $remote_url/$current_branch"
        return 0
    else
        print_error "Failed to push to $remote_url/$current_branch"
        return 1
    fi
}
# Handle commit action based on mode
handle_commit() {
    local commit_message="$1"
    
    case "$DRY_RUN$AUTO_COMMIT" in
        "truetrue"|"truefalse")
            print_info "DRY RUN - Generated commit message:"
            echo "$commit_message" ;;
        "falsetrue")
            print_info "Generated commit message: $commit_message"
            if [[ "$AUTO_PUSH" == "true" ]]; then
                print_warning "About to commit and push with this message. Continue? (y/N)"
            else
                print_warning "About to commit with this message. Continue? (y/N)"
            fi
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                if git commit -m "$commit_message"; then
                    print_success "Successfully committed with message: $commit_message"
                    
                    # Push if auto-push is enabled
                    if [[ "$AUTO_PUSH" == "true" ]]; then
                        if push_to_current_branch; then
                            print_success "Commit and push completed successfully"
                        else
                            print_error "Commit succeeded but push failed"
                            exit 1
                        fi
                    fi
                else
                    print_error "Failed to commit"
                    exit 1
                fi
            else
                print_info "Commit cancelled"
            fi ;;
        *)
            echo "$commit_message" ;;
    esac
}

# Main function
main() {
    parse_args "$@"
    validate_requirements
    
    print_info "LGTM - Generating commit message from git diff..."
    
    local commit_message
    commit_message=$(generate_commit_message) || {
        print_error "Failed to generate commit message"
        exit 1
    }
    
    # Clean up the commit message (preserve newlines and multi-line structure)
    commit_message=$(printf '%s' "$commit_message" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    handle_commit "$commit_message"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
# Test comment
