#!/bin/bash

# PestGenie Code Signing Setup Script
# This script helps set up code signing certificates and provisioning profiles

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

# Configuration
CERTS_DIR="certs"
KEYCHAIN_NAME="PestGenie.keychain"
KEYCHAIN_PASSWORD="PestGenieKeychain123"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create certificates directory
create_certs_directory() {
    log_info "Creating certificates directory..."
    
    if [ ! -d "$CERTS_DIR" ]; then
        mkdir -p "$CERTS_DIR"
        log_success "Created certificates directory: $CERTS_DIR"
    else
        log_info "Certificates directory already exists: $CERTS_DIR"
    fi
    
    # Create .gitignore to exclude sensitive files
    cat > "$CERTS_DIR/.gitignore" << 'EOF'
# Ignore all certificate files
*.p12
*.mobileprovision
*.p8
*.cer
*.crt
*.key
*.pem

# But keep the directory structure
!.gitignore
!README.md
EOF
    
    # Create README for certificates directory
    cat > "$CERTS_DIR/README.md" << 'EOF'
# Certificates Directory

This directory contains code signing certificates and provisioning profiles for the PestGenie iOS app.

## Required Files

### Certificates
- `distribution.p12` - iOS Distribution Certificate
- `development.p12` - iOS Development Certificate

### Provisioning Profiles
- `PestGenie_AdHoc.mobileprovision` - Ad Hoc Distribution Profile
- `PestGenie_AppStore.mobileprovision` - App Store Distribution Profile
- `PestGenie_Development.mobileprovision` - Development Profile

### App Store Connect API Key
- `AuthKey_XXXXXXXXXX.p8` - App Store Connect API Key

## Security Notes

- Never commit these files to version control
- Store them securely and share only with authorized team members
- Use strong passwords for certificate files
- Regularly rotate certificates and API keys

## Setup Instructions

1. Download certificates from Apple Developer Portal
2. Import them using the setup script: `./scripts/setup-code-signing.sh --import`
3. Verify installation: `./scripts/setup-code-signing.sh --verify`
EOF
    
    log_success "Certificates directory setup completed"
}

# Function to create keychain
create_keychain() {
    log_info "Creating keychain for code signing..."
    
    # Delete existing keychain if it exists
    if security list-keychains | grep -q "$KEYCHAIN_NAME"; then
        log_info "Deleting existing keychain..."
        security delete-keychain "$KEYCHAIN_NAME" 2>/dev/null || true
    fi
    
    # Create new keychain
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    
    # Set keychain as default
    security default-keychain -s "$KEYCHAIN_NAME"
    
    # Unlock keychain
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    
    # Set keychain timeout
    security set-keychain-settings -t 3600 -l "$KEYCHAIN_NAME"
    
    log_success "Keychain created and configured: $KEYCHAIN_NAME"
}

# Function to import certificate
import_certificate() {
    local cert_file=$1
    local cert_password=$2
    
    if [ ! -f "$cert_file" ]; then
        log_error "Certificate file not found: $cert_file"
        return 1
    fi
    
    log_info "Importing certificate: $cert_file"
    
    # Import certificate to keychain
    security import "$cert_file" \
        -k "$KEYCHAIN_NAME" \
        -P "$cert_password" \
        -T /usr/bin/codesign \
        -T /usr/bin/security \
        -T /usr/bin/productbuild
    
    log_success "Certificate imported successfully: $cert_file"
}

# Function to import provisioning profile
import_provisioning_profile() {
    local profile_file=$1
    
    if [ ! -f "$profile_file" ]; then
        log_error "Provisioning profile file not found: $profile_file"
        return 1
    fi
    
    log_info "Importing provisioning profile: $profile_file"
    
    # Copy provisioning profile to system location
    cp "$profile_file" ~/Library/MobileDevice/Provisioning\ Profiles/
    
    log_success "Provisioning profile imported successfully: $profile_file"
}

# Function to list certificates
list_certificates() {
    log_info "Listing certificates in keychain..."
    
    security find-identity -v -p codesigning "$KEYCHAIN_NAME"
}

# Function to list provisioning profiles
list_provisioning_profiles() {
    log_info "Listing provisioning profiles..."
    
    ls -la ~/Library/MobileDevice/Provisioning\ Profiles/
}

# Function to verify code signing setup
verify_code_signing() {
    log_info "Verifying code signing setup..."
    
    local errors=0
    
    # Check if keychain exists
    if ! security list-keychains | grep -q "$KEYCHAIN_NAME"; then
        log_error "Keychain not found: $KEYCHAIN_NAME"
        ((errors++))
    fi
    
    # Check if certificates exist
    local cert_count=$(security find-identity -v -p codesigning "$KEYCHAIN_NAME" | grep -c "valid")
    if [ $cert_count -eq 0 ]; then
        log_error "No valid certificates found in keychain"
        ((errors++))
    else
        log_info "Found $cert_count valid certificate(s)"
    fi
    
    # Check if provisioning profiles exist
    local profile_count=$(ls ~/Library/MobileDevice/Provisioning\ Profiles/ 2>/dev/null | wc -l)
    if [ $profile_count -eq 0 ]; then
        log_error "No provisioning profiles found"
        ((errors++))
    else
        log_info "Found $profile_count provisioning profile(s)"
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Code signing setup verification passed"
        return 0
    else
        log_error "Code signing setup verification failed with $errors errors"
        return 1
    fi
}

# Function to generate App Store Connect API key
generate_api_key() {
    log_info "Generating App Store Connect API key..."
    
    log_warning "This requires manual steps:"
    log_info "1. Go to App Store Connect"
    log_info "2. Navigate to Users and Access > Keys > App Store Connect API"
    log_info "3. Click the '+' button to create a new key"
    log_info "4. Select 'Developer' role"
    log_info "5. Download the .p8 file and save it as: $CERTS_DIR/AuthKey_XXXXXXXXXX.p8"
    log_info "6. Note the Key ID and Issuer ID for your .env file"
    
    read -p "Press Enter when you have completed these steps..."
    
    # Check if API key file exists
    local api_key_file=$(ls "$CERTS_DIR"/AuthKey_*.p8 2>/dev/null | head -n1)
    if [ -f "$api_key_file" ]; then
        log_success "App Store Connect API key found: $api_key_file"
    else
        log_warning "App Store Connect API key not found. Please add it to the $CERTS_DIR directory."
    fi
}

# Function to setup Fastlane match (alternative to manual certificate management)
setup_fastlane_match() {
    log_info "Setting up Fastlane Match for certificate management..."
    
    if ! command_exists fastlane; then
        log_error "Fastlane is not installed. Please install it first: brew install fastlane"
        return 1
    fi
    
    # Create Matchfile
    cat > "fastlane/Matchfile" << 'EOF'
# Fastlane Match Configuration

# Storage mode (git, s3, google_cloud)
storage_mode("git")

# Git URL for storing certificates
git_url("https://github.com/your-org/pestgenie-certificates.git")

# Git branch for certificates
git_branch("main")

# App identifier
app_identifier("Greenix.PestGenie")

# Username for Apple Developer Portal
username("your-apple-id@example.com")

# Team ID
team_id("YOUR_TEAM_ID")

# Keychain name
keychain_name("PestGenie.keychain")

# Keychain password
keychain_password("PestGenieKeychain123")

# Readonly mode (set to true for CI/CD)
readonly(false)

# Skip confirmation
skip_confirmation(true)

# Skip dependency validation
skip_dependency_validation(true)

# Shallow clone
shallow_clone(true)
EOF
    
    log_success "Fastlane Match configuration created"
    log_info "Next steps:"
    log_info "1. Update the Matchfile with your actual values"
    log_info "2. Run 'fastlane match init' to initialize the certificate repository"
    log_info "3. Run 'fastlane match development' to generate development certificates"
    log_info "4. Run 'fastlane match adhoc' to generate ad hoc certificates"
    log_info "5. Run 'fastlane match appstore' to generate app store certificates"
}

# Function to cleanup keychain
cleanup_keychain() {
    log_info "Cleaning up keychain..."
    
    # Delete keychain
    if security list-keychains | grep -q "$KEYCHAIN_NAME"; then
        security delete-keychain "$KEYCHAIN_NAME"
        log_success "Keychain deleted: $KEYCHAIN_NAME"
    else
        log_info "Keychain not found: $KEYCHAIN_NAME"
    fi
    
    # Reset default keychain
    security default-keychain -s login.keychain
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -i, --import            Import certificates and provisioning profiles"
    echo "  -l, --list              List certificates and provisioning profiles"
    echo "  -v, --verify            Verify code signing setup"
    echo "  -k, --keychain          Create keychain only"
    echo "  -a, --api-key           Generate App Store Connect API key"
    echo "  -m, --match             Setup Fastlane Match"
    echo "  -c, --cleanup           Cleanup keychain"
    echo "  -f, --full              Full setup (default)"
    echo ""
    echo "Examples:"
    echo "  $0 --full              # Full setup"
    echo "  $0 --import            # Import certificates only"
    echo "  $0 --verify            # Verify setup only"
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
            -i|--import)
                action="import"
                shift
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -v|--verify)
                action="verify"
                shift
                ;;
            -k|--keychain)
                action="keychain"
                shift
                ;;
            -a|--api-key)
                action="api-key"
                shift
                ;;
            -m|--match)
                action="match"
                shift
                ;;
            -c|--cleanup)
                action="cleanup"
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
    
    log_info "Starting PestGenie code signing setup..."
    log_info "Action: $action"
    
    # Execute based on action
    case $action in
        "import")
            create_certs_directory
            create_keychain
            
            # Prompt for certificate files
            read -p "Enter path to distribution certificate (.p12): " dist_cert
            read -s -p "Enter certificate password: " cert_password
            echo
            
            if [ -f "$dist_cert" ]; then
                import_certificate "$dist_cert" "$cert_password"
            fi
            
            # Prompt for provisioning profiles
            read -p "Enter path to App Store provisioning profile (.mobileprovision): " appstore_profile
            if [ -f "$appstore_profile" ]; then
                import_provisioning_profile "$appstore_profile"
            fi
            
            verify_code_signing
            ;;
        "list")
            list_certificates
            echo
            list_provisioning_profiles
            ;;
        "verify")
            verify_code_signing
            ;;
        "keychain")
            create_keychain
            ;;
        "api-key")
            create_certs_directory
            generate_api_key
            ;;
        "match")
            setup_fastlane_match
            ;;
        "cleanup")
            cleanup_keychain
            ;;
        "full")
            create_certs_directory
            create_keychain
            generate_api_key
            setup_fastlane_match
            verify_code_signing
            ;;
        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
    
    log_success "Code signing setup completed successfully!"
    log_info "Next steps:"
    log_info "1. Download certificates from Apple Developer Portal"
    log_info "2. Run './scripts/setup-code-signing.sh --import' to import them"
    log_info "3. Update your .env file with the correct values"
    log_info "4. Test the setup with './scripts/build.sh --test'"
}

# Run main function with all arguments
main "$@"
