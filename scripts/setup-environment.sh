#!/bin/bash

# PestGenie Environment Setup Script
# This script sets up the development and build environment for the PestGenie iOS app

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Homebrew
install_homebrew() {
    if ! command_exists brew; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        log_success "Homebrew installed successfully"
    else
        log_info "Homebrew is already installed"
    fi
}

# Function to install Xcode Command Line Tools
install_xcode_tools() {
    if ! command_exists xcodebuild; then
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        log_success "Xcode Command Line Tools installed successfully"
    else
        log_info "Xcode Command Line Tools are already installed"
    fi
}

# Function to install required tools
install_tools() {
    log_info "Installing required tools..."
    
    # Update Homebrew
    brew update
    
    # Install essential tools
    local tools=(
        "git"
        "curl"
        "wget"
        "jq"
        "yq"
        "swiftlint"
        "semgrep"
        "fastlane"
        "cocoapods"
        "swift-doc"
        "swift-dependency-analyzer"
    )
    
    for tool in "${tools[@]}"; do
        if ! command_exists "$tool"; then
            log_info "Installing $tool..."
            brew install "$tool"
        else
            log_info "$tool is already installed"
        fi
    done
    
    log_success "All required tools installed"
}

# Function to setup Git configuration
setup_git() {
    log_info "Setting up Git configuration..."
    
    # Check if git is configured
    if ! git config --global user.name >/dev/null 2>&1; then
        log_warning "Git user.name is not configured"
        read -p "Enter your Git user name: " git_name
        git config --global user.name "$git_name"
    fi
    
    if ! git config --global user.email >/dev/null 2>&1; then
        log_warning "Git user.email is not configured"
        read -p "Enter your Git user email: " git_email
        git config --global user.email "$git_email"
    fi
    
    # Set up useful Git aliases
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.st status
    git config --global alias.unstage 'reset HEAD --'
    git config --global alias.last 'log -1 HEAD'
    git config --global alias.visual '!gitk'
    
    log_success "Git configuration completed"
}

# Function to create necessary directories
create_directories() {
    log_info "Creating necessary directories..."
    
    local directories=(
        "build"
        "archives"
        "certs"
        "fastlane/screenshots"
        "Documentation"
        "scripts"
        ".github/workflows"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        else
            log_info "Directory already exists: $dir"
        fi
    done
    
    log_success "All necessary directories created"
}

# Function to setup SwiftLint configuration
setup_swiftlint() {
    log_info "Setting up SwiftLint configuration..."
    
    local swiftlint_config=".swiftlint.yml"
    
    if [ ! -f "$swiftlint_config" ]; then
        cat > "$swiftlint_config" << 'EOF'
# SwiftLint Configuration for PestGenie

# Paths to include/exclude
included:
  - PestGenie
  - PestGenieTests
  - PestGenieUITests

excluded:
  - Pods
  - build
  - archives
  - Documentation

# Rules to disable
disabled_rules:
  - trailing_whitespace
  - line_length
  - function_body_length
  - file_length
  - type_body_length
  - identifier_name

# Rules to enable
opt_in_rules:
  - empty_count
  - empty_string
  - force_unwrapping
  - implicitly_unwrapped_optional
  - overridden_super_call
  - prohibited_interface_builder
  - redundant_nil_coalescing
  - redundant_type_annotation
  - unused_closure_parameter
  - unused_optional_binding
  - vertical_parameter_alignment_on_call
  - yoda_condition

# Custom rules
custom_rules:
  # Prevent force unwrapping
  no_force_unwrapping:
    name: "No Force Unwrapping"
    regex: '!\s*$'
    message: "Force unwrapping should be avoided"
    severity: warning

  # Prevent print statements in production code
  no_print_statements:
    name: "No Print Statements"
    regex: '\bprint\s*\('
    message: "Use proper logging instead of print statements"
    severity: warning
    excluded: ".*Test.*"

# Line length configuration
line_length:
  warning: 120
  error: 150
  ignores_urls: true
  ignores_function_declarations: true
  ignores_comments: true

# File length configuration
file_length:
  warning: 500
  error: 1000

# Function body length configuration
function_body_length:
  warning: 50
  error: 100

# Type body length configuration
type_body_length:
  warning: 300
  error: 500

# Identifier name configuration
identifier_name:
  min_length:
    warning: 2
    error: 1
  max_length:
    warning: 40
    error: 60
  excluded:
    - id
    - url
    - api
    - ui
    - db
    - ok
    - no
    - yes
EOF
        log_success "SwiftLint configuration created"
    else
        log_info "SwiftLint configuration already exists"
    fi
}

# Function to setup environment variables
setup_environment_variables() {
    log_info "Setting up environment variables..."
    
    local env_file=".env"
    
    if [ ! -f "$env_file" ]; then
        cat > "$env_file" << 'EOF'
# PestGenie Environment Variables
# Copy this file to .env.local and fill in your actual values

# Apple Developer Account
APPLE_ID=your-apple-id@example.com
TEAM_ID=YOUR_TEAM_ID
BUNDLE_IDENTIFIER=Greenix.PestGenie

# Code Signing
CERTIFICATE_PASSWORD=your_certificate_password
PROVISIONING_PROFILE_NAME=PestGenie_AdHoc

# App Store Connect
APP_STORE_CONNECT_API_KEY_ID=your_api_key_id
APP_STORE_CONNECT_API_ISSUER_ID=your_issuer_id
APP_STORE_CONNECT_API_KEY_PATH=./certs/AuthKey_XXXXXXXXXX.p8

# TestFlight
TESTFLIGHT_GROUPS=Internal,External

# Slack Integration
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
SLACK_CHANNEL=#ios-releases

# Build Configuration
BUILD_CONFIGURATION=Release
EXPORT_METHOD=app-store
INCLUDE_BITCODE=false
INCLUDE_SYMBOLS=true

# Testing
TEST_DESTINATION=platform=iOS Simulator,name=iPhone 15 Pro,OS=18.2
CODE_COVERAGE=true

# Security
ENABLE_SECURITY_SCAN=true
ENABLE_DEPENDENCY_CHECK=true
EOF
        log_success "Environment variables template created: $env_file"
        log_warning "Please copy $env_file to .env.local and fill in your actual values"
    else
        log_info "Environment variables file already exists"
    fi
}

# Function to setup Git hooks
setup_git_hooks() {
    log_info "Setting up Git hooks..."
    
    local hooks_dir=".git/hooks"
    
    # Pre-commit hook
    cat > "$hooks_dir/pre-commit" << 'EOF'
#!/bin/bash

# Pre-commit hook for PestGenie
echo "Running pre-commit checks..."

# Run SwiftLint
if command -v swiftlint >/dev/null 2>&1; then
    echo "Running SwiftLint..."
    swiftlint lint --strict
    if [ $? -ne 0 ]; then
        echo "SwiftLint found issues. Please fix them before committing."
        exit 1
    fi
else
    echo "SwiftLint not found. Please install it: brew install swiftlint"
fi

# Run security scan
if command -v semgrep >/dev/null 2>&1; then
    echo "Running security scan..."
    semgrep --config=auto --error
    if [ $? -ne 0 ]; then
        echo "Security scan found issues. Please review them before committing."
        exit 1
    fi
else
    echo "Semgrep not found. Please install it: brew install semgrep"
fi

echo "Pre-commit checks passed!"
EOF
    
    chmod +x "$hooks_dir/pre-commit"
    
    # Commit-msg hook
    cat > "$hooks_dir/commit-msg" << 'EOF'
#!/bin/bash

# Commit message hook for PestGenie
commit_regex='^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "Invalid commit message format!"
    echo "Format: type(scope): description"
    echo "Types: feat, fix, docs, style, refactor, test, chore"
    echo "Example: feat(auth): add login functionality"
    exit 1
fi
EOF
    
    chmod +x "$hooks_dir/commit-msg"
    
    log_success "Git hooks set up successfully"
}

# Function to setup Xcode project settings
setup_xcode_project() {
    log_info "Setting up Xcode project settings..."
    
    # Create .xcode.env file for environment variables
    cat > ".xcode.env" << 'EOF'
# Xcode Environment Variables
# This file is used by Xcode to set environment variables during build

# Build configuration
BUILD_CONFIGURATION=Release
EXPORT_METHOD=app-store

# Code signing
CODE_SIGN_IDENTITY=iPhone Distribution
CODE_SIGN_STYLE=Automatic

# Deployment
IPHONEOS_DEPLOYMENT_TARGET=15.0
TARGETED_DEVICE_FAMILY=1,2

# Optimization
SWIFT_OPTIMIZATION_LEVEL=-O
GCC_OPTIMIZATION_LEVEL=s
ENABLE_BITCODE=NO
ENABLE_TESTABILITY=NO
EOF
    
    log_success "Xcode project settings configured"
}

# Function to validate setup
validate_setup() {
    log_info "Validating setup..."
    
    local errors=0
    
    # Check required tools
    local required_tools=("xcodebuild" "swiftlint" "fastlane" "git")
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            log_error "$tool is not installed"
            ((errors++))
        fi
    done
    
    # Check Xcode project
    if [ ! -f "PestGenie.xcodeproj/project.pbxproj" ]; then
        log_error "Xcode project not found"
        ((errors++))
    fi
    
    # Check required directories
    local required_dirs=("build" "archives" "certs" "fastlane")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "Required directory not found: $dir"
            ((errors++))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        log_success "Setup validation passed"
        return 0
    else
        log_error "Setup validation failed with $errors errors"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -t, --tools             Install tools only"
    echo "  -g, --git               Setup Git configuration only"
    echo "  -d, --directories       Create directories only"
    echo "  -s, --swiftlint         Setup SwiftLint only"
    echo "  -e, --environment       Setup environment variables only"
    echo "  -x, --xcode             Setup Xcode project only"
    echo "  -v, --validate          Validate setup only"
    echo "  -f, --full              Full setup (default)"
    echo ""
    echo "Examples:"
    echo "  $0 --full              # Full setup"
    echo "  $0 --tools             # Install tools only"
    echo "  $0 --validate          # Validate current setup"
}

# Main function
main() {
    local action="full"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -t|--tools)
                action="tools"
                shift
                ;;
            -g|--git)
                action="git"
                shift
                ;;
            -d|--directories)
                action="directories"
                shift
                ;;
            -s|--swiftlint)
                action="swiftlint"
                shift
                ;;
            -e|--environment)
                action="environment"
                shift
                ;;
            -x|--xcode)
                action="xcode"
                shift
                ;;
            -v|--validate)
                action="validate"
                shift
                ;;
            -f|--full)
                action="full"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "Starting PestGenie environment setup..."
    log_info "Action: $action"
    
    # Execute based on action
    case $action in
        "tools")
            install_homebrew
            install_xcode_tools
            install_tools
            ;;
        "git")
            setup_git
            setup_git_hooks
            ;;
        "directories")
            create_directories
            ;;
        "swiftlint")
            setup_swiftlint
            ;;
        "environment")
            setup_environment_variables
            ;;
        "xcode")
            setup_xcode_project
            ;;
        "validate")
            validate_setup
            ;;
        "full")
            install_homebrew
            install_xcode_tools
            install_tools
            setup_git
            create_directories
            setup_swiftlint
            setup_environment_variables
            setup_git_hooks
            setup_xcode_project
            validate_setup
            ;;
        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
    
    log_success "Environment setup completed successfully!"
    log_info "Next steps:"
    log_info "1. Copy .env to .env.local and fill in your actual values"
    log_info "2. Set up your Apple Developer certificates in the certs/ directory"
    log_info "3. Run './scripts/build.sh --test' to verify everything works"
}

# Run main function with all arguments
main "$@"
