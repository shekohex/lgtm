#!/usr/bin/env bash
set -euo pipefail

# Default configuration
AUTO_CONFIG=true
INSTALL_GIT_SUBCOMMAND=true

# Check for required tools
check_dependencies() {
  local missing_deps=()
  for cmd in curl git jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_deps+=("$cmd")
    fi
  done

  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "Error: Missing required dependencies: ${missing_deps[*]}"
    echo "Please install them using your package manager:"
    echo "  Debian/Ubuntu: sudo apt-get install ${missing_deps[*]}"
    echo "  macOS: brew install ${missing_deps[*]}"
    exit 1
  fi
}

# Print environment variables for manual setup
print_env_config() {
  cat << 'EOF'
# LGTM Configuration
export PATH="$HOME/.local/bin:$PATH"
# Required variables (customize these)
export LGTM_API_URL="https://api.openai.com/v1/chat/completions"
export LGTM_API_KEY="your-api-key-here"
# Optional variables (adjust as needed)
export LGTM_MODEL="gpt-4"
export LGTM_TEMPERATURE="0.1"
export LGTM_TOP_P="0.25"
export LGTM_MAX_TOKENS="100"
export LGTM_MAX_INPUT_TOKENS="8000"
export LGTM_MAX_CHUNK_SIZE="4000"
export LGTM_TIMEOUT="15"
EOF
}

# Setup environment variables in shell config
setup_environment() {
  if [ "$AUTO_CONFIG" = false ]; then
    echo "Auto-configuration is disabled. Add these environment variables to your shell configuration:"
    echo
    print_env_config
    return
  fi

  local config_file
  # Detect shell and config file
  if [ -n "${BASH_VERSION:-}" ]; then
    config_file="$HOME/.bashrc"
  elif [ -n "${ZSH_VERSION:-}" ]; then
    config_file="$HOME/.zshrc"
  elif [ -n "${FISH_VERSION:-}" ]; then
    config_file="$HOME/.config/fish/config.fish"
  else
    # Default to .profile which is usually sourced by most shells
    config_file="$HOME/.profile"
  fi

  # Create or append to config file
  {
    echo ""
    echo "# LGTM Configuration"
    print_env_config
  } >> "$config_file"

  echo "Environment variables added to $config_file"
  echo "Please edit $config_file to set your API key and customize other variables"
}

# Show usage information
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Options:
  --no-auto-config        Disable automatic profile modification and print environment
                         variables to stdout instead
  --without-git-subcommand  Do not install as a Git subcommand (git-lgtm)
  -h, --help             Show this help message

Environment variables:
  LGTM_NO_AUTO_CONFIG        Set to "true" to disable automatic profile modification
  LGTM_NO_GIT_SUBCOMMAND    Set to "true" to disable Git subcommand installation
EOF
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --no-auto-config)
        AUTO_CONFIG=false
        shift
        ;;
      --without-git-subcommand)
        INSTALL_GIT_SUBCOMMAND=false
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Check environment variable overrides
  if [ "${LGTM_NO_AUTO_CONFIG:-false}" = "true" ]; then
    AUTO_CONFIG=false
  fi
  if [ "${LGTM_NO_GIT_SUBCOMMAND:-false}" = "true" ]; then
    INSTALL_GIT_SUBCOMMAND=false
  fi
}

main() {
  # Parse command line arguments
  parse_args "$@"

  echo "Installing LGTM..."
  
  # Check for dependencies first
  check_dependencies

  # Create local bin directory if it doesn't exist
  mkdir -p "$HOME/.local/bin"

  # Download the script
  echo "Downloading LGTM script..."
  curl -fsSL "https://raw.githubusercontent.com/shekohex/lgtm/main/lgtm.sh" -o "$HOME/.local/bin/lgtm"

  # Make executable
  chmod +x "$HOME/.local/bin/lgtm"

  # Install Git subcommand if enabled
  if [ "$INSTALL_GIT_SUBCOMMAND" = true ]; then
    echo "Installing Git subcommand..."
    ln -sf "$HOME/.local/bin/lgtm" "$HOME/.local/bin/git-lgtm"
    echo "Git subcommand 'git lgtm' installed"
  fi

  # Setup environment
  setup_environment

  echo "Installation complete!"
  if [ "$AUTO_CONFIG" = true ]; then
    echo "Please:"
    echo "1. Edit your shell config file to set your API key"
    echo "2. Reload your shell configuration:"
    echo "   source ~/.bashrc  # or ~/.zshrc, ~/.profile, etc."
  else
    echo "Please add the above environment variables to your shell configuration"
  fi
  echo "3. Run 'lgtm --help' to verify installation"
}

main "$@"
