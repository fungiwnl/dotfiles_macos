#!/usr/bin/env zsh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_prompt() {
    echo -e "${CYAN}[PROMPT]${NC} $1"
}

prompt_var() {
    local var_name="$1"
    local prompt_text="$2"
    local default_value="$3"
    local is_required="${4:-true}"
    
    local current_value="${(P)var_name}"  # Get current value of variable
    
    # If variable is already set (from environment), use it
    if [[ -n "$current_value" ]]; then
        log_info "$prompt_text (using existing value: $current_value)"
        return 0
    fi
    
    # Build prompt
    local full_prompt="$prompt_text"
    if [[ -n "$default_value" ]]; then
        full_prompt="$full_prompt [$default_value]"
    fi
    full_prompt="$full_prompt: "
    
    # Prompt for input
    while true; do
        log_prompt "$full_prompt"
        read -r input
        
        # Use default if no input provided
        if [[ -z "$input" && -n "$default_value" ]]; then
            input="$default_value"
        fi
        
        # Check if required field is empty
        if [[ "$is_required" == "true" && -z "$input" ]]; then
            log_error "This field is required. Please enter a value."
            continue
        fi
        
        # Set the variable
        export "$var_name"="$input"
        break
    done
}

confirm_settings() {
    echo ""
    log_info "Please confirm your settings:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📧 Git Email:        $SSH_EMAIL"
    echo "🔑 SSH Key Name:     $SSH_KEYNAME"
    echo "🔄 Overwrite Keys:   $SSH_OVERWRITE"
    echo "⏭️  Skip Prompts:     $SSH_SKIP_PROMPT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    while true; do
        log_prompt "Are these settings correct? [Y/n]: "
        read -r confirm
        case $confirm in
            [Yy]* | "" ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) log_error "Please answer yes or no." ;;
        esac
    done
}

save_settings() {
    local config_file="$SCRIPT_DIR/.env"
    
    log_prompt "Save these settings for future runs? [Y/n]: "
    read -r save_choice
    
    case $save_choice in
        [Yy]* | "" )
            cat > "$config_file" << EOF
# Dotfiles configuration
# This file is sourced by setup.zsh to avoid re-prompting
SSH_EMAIL="$SSH_EMAIL"
SSH_KEYNAME="$SSH_KEYNAME"
SSH_OVERWRITE="$SSH_OVERWRITE"
SSH_SKIP_PROMPT="$SSH_SKIP_PROMPT"
EOF
            log_success "Settings saved to $config_file"
            log_info "Delete this file if you want to be prompted again"
            ;;
        [Nn]* )
            log_info "Settings not saved"
            ;;
    esac
}

load_settings() {
    local config_file="$SCRIPT_DIR/.env"
    
    if [[ -f "$config_file" ]]; then
        log_info "Loading existing settings from $config_file"
        source "$config_file"
        return 0
    fi
    return 1
}

run_dotbot() {
    local config_file="${1:-install.conf.yaml}"
    
    log_info "Running dotbot with configuration: $config_file"
    
    # Check if dotbot is available
    if ! command -v dotbot >/dev/null 2>&1; then
        # Try to use local dotbot installation
        if [[ -f "$SCRIPT_DIR/dotbot/bin/dotbot" ]]; then
            log_info "Using local dotbot installation"
            python3 "$SCRIPT_DIR/dotbot/bin/dotbot" -d "$SCRIPT_DIR" -c "$config_file"
        else
            log_error "dotbot not found. Please install dotbot or run:"
            log_error "git submodule update --init --recursive"
            exit 1
        fi
    else
        # Use system dotbot
        dotbot -d "$SCRIPT_DIR" -c "$config_file"
    fi
}

main() {
    echo ""
    echo "🏠 Dotfiles Setup Script"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Try to load existing settings
    load_settings
    
    # Prompt for required variables
    log_info "Setting up environment variables for dotfiles installation..."
    echo ""
    
    prompt_var "SSH_EMAIL" "📧 Enter your Git email address"
    prompt_var "SSH_KEYNAME" "🔑 Enter a name for your SSH key" "github"
    prompt_var "SSH_OVERWRITE" "🔄 Overwrite existing SSH keys if they exist? [y/N]" "n" false
    prompt_var "SSH_SKIP_PROMPT" "⏭️  Skip manual GitHub key confirmation prompts? [Y/n]" "y" false
    
    echo ""
    
    # Confirm settings
    while ! confirm_settings; do
        log_warning "Let's try again..."
        echo ""
        unset SSH_EMAIL SSH_KEYNAME SSH_OVERWRITE SSH_SKIP_PROMPT
        prompt_var "SSH_EMAIL" "📧 Enter your Git email address"
        prompt_var "SSH_KEYNAME" "🔑 Enter a name for your SSH key" "github"
        prompt_var "SSH_OVERWRITE" "🔄 Overwrite existing SSH keys if they exist? [y/N]" "n" false
        prompt_var "SSH_SKIP_PROMPT" "⏭️  Skip manual GitHub key confirmation prompts? [Y/n]" "y" false
        echo ""
    done
    
    # Save settings if requested
    save_settings
    
    echo ""
    log_success "Environment variables configured successfully!"
    log_info "Starting dotbot installation..."
    echo ""
    
    # Export all variables for child processes
    export SSH_EMAIL SSH_KEYNAME SSH_OVERWRITE SSH_SKIP_PROMPT
    
    # Run dotbot
    run_dotbot "${1:-install.conf.yaml}"
    
    echo ""
    log_success "🎉 Dotfiles installation completed!"
    
    # Show post-installation notes
    if [[ "$SSH_SKIP_PROMPT" != "y" ]]; then
        echo ""
        log_warning "📌 Don't forget to add your SSH key to GitHub:"
        echo "    👉 https://github.com/settings/keys"
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-c CONFIG_FILE] [-h]"
            echo ""
            echo "Options:"
            echo "  -c, --config CONFIG_FILE    Specify dotbot config file (default: install.conf.yaml)"
            echo "  -h, --help                  Show this help message"
            echo ""
            echo "Environment variables can be pre-set to avoid prompts:"
            echo "  SSH_EMAIL       - Git email address"
            echo "  SSH_KEYNAME     - SSH key name"
            echo "  SSH_OVERWRITE   - Overwrite existing keys (y/n)"
            echo "  SSH_SKIP_PROMPT - Skip GitHub confirmation (y/n)"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main "$CONFIG_FILE"
