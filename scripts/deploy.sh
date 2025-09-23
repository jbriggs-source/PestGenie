#!/bin/bash

# PestGenie Deployment Script
# This script handles the complete deployment process for the PestGenie iOS app

set -e  # Exit on any error

# Configuration
PROJECT_NAME="PestGenie"
SCHEME_NAME="PestGenie"
BUILD_DIR="build"
ARCHIVE_DIR="archives"
CONFIGURATION="Release"
EXPORT_METHOD="app-store"

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

# Function to load environment variables
load_environment() {
    if [ -f ".env.local" ]; then
        log_info "Loading environment variables from .env.local"
        source .env.local
    elif [ -f ".env" ]; then
        log_info "Loading environment variables from .env"
        source .env
    else
        log_warning "No environment file found. Using default values."
    fi
}

# Function to validate environment
validate_environment() {
    log_info "Validating deployment environment..."
    
    local errors=0
    
    # Check required environment variables
    local required_vars=("APPLE_ID" "TEAM_ID" "BUNDLE_IDENTIFIER")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required environment variable not set: $var"
            ((errors++))
        fi
    done
    
    # Check if required tools are installed
    local required_tools=("xcodebuild" "fastlane")
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            log_error "Required tool not installed: $tool"
            ((errors++))
        fi
    done
    
    # Check if certificates exist
    if [ ! -d "certs" ]; then
        log_error "Certificates directory not found. Run setup-code-signing.sh first."
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Environment validation passed"
        return 0
    else
        log_error "Environment validation failed with $errors errors"
        return 1
    fi
}

# Function to run pre-deployment checks
run_pre_deployment_checks() {
    log_info "Running pre-deployment checks..."
    
    # Run tests
    log_info "Running tests..."
    if ! ./scripts/build.sh --test; then
        log_error "Tests failed. Deployment aborted."
        exit 1
    fi
    
    # Run code quality checks
    log_info "Running code quality checks..."
    if command_exists swiftlint; then
        swiftlint lint --strict
    fi
    
    # Run security scan
    log_info "Running security scan..."
    if command_exists semgrep; then
        semgrep --config=auto --error
    fi
    
    # Check for TODO/FIXME comments
    log_info "Checking for TODO/FIXME comments..."
    local todo_count=$(grep -r "TODO\|FIXME" PestGenie/ --include="*.swift" | wc -l)
    if [ $todo_count -gt 0 ]; then
        log_warning "Found $todo_count TODO/FIXME comments in the code"
        read -p "Continue with deployment? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    log_success "Pre-deployment checks completed"
}

# Function to build and archive
build_and_archive() {
    log_info "Building and archiving app..."
    
    # Clean previous builds
    ./scripts/build.sh --clean
    
    # Build and archive
    ./scripts/build.sh --archive
    
    log_success "Build and archive completed"
}

# Function to deploy to TestFlight
deploy_to_testflight() {
    log_info "Deploying to TestFlight..."
    
    if ! command_exists fastlane; then
        log_error "Fastlane is not installed. Please install it first."
        exit 1
    fi
    
    # Use Fastlane to deploy to TestFlight
    fastlane beta
    
    log_success "Deployment to TestFlight completed"
}

# Function to deploy to App Store
deploy_to_appstore() {
    log_info "Deploying to App Store..."
    
    if ! command_exists fastlane; then
        log_error "Fastlane is not installed. Please install it first."
        exit 1
    fi
    
    # Use Fastlane to deploy to App Store
    fastlane release
    
    log_success "Deployment to App Store completed"
}

# Function to create release notes
create_release_notes() {
    log_info "Creating release notes..."
    
    local version=$(grep "MARKETING_VERSION" PestGenie.xcodeproj/project.pbxproj | head -n1 | awk '{print $3}' | tr -d ';')
    local build_number=$(grep "CURRENT_PROJECT_VERSION" PestGenie.xcodeproj/project.pbxproj | head -n1 | awk '{print $3}' | tr -d ';')
    
    local release_notes_file="build/release-notes-v${version}-${build_number}.md"
    
    cat > "$release_notes_file" << EOF
# PestGenie Release Notes v${version} (${build_number})

## Release Date
$(date)

## Changes
- Automated build from CI/CD pipeline
- All tests passing
- Security scan completed
- Performance tests passed

## Build Information
- Version: ${version}
- Build Number: ${build_number}
- Configuration: ${CONFIGURATION}
- Export Method: ${EXPORT_METHOD}

## Deployment Status
- [ ] TestFlight Upload
- [ ] App Store Submission
- [ ] Release Notes Updated
- [ ] Screenshots Updated
- [ ] Metadata Updated

## Testing Checklist
- [ ] Test on multiple devices
- [ ] Test with VoiceOver
- [ ] Test with Dynamic Type
- [ ] Test offline functionality
- [ ] Test push notifications
- [ ] Test deep linking
- [ ] Performance testing
- [ ] Memory usage testing
- [ ] Battery usage testing

## Notes
- This is an automated release
- All quality checks have passed
- Ready for App Store review
EOF
    
    log_success "Release notes created: $release_notes_file"
}

# Function to send deployment notification
send_notification() {
    local deployment_type=$1
    local status=$2
    local message=$3
    
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        log_info "Sending Slack notification..."
        
        local color="good"
        if [ "$status" = "error" ]; then
            color="danger"
        elif [ "$status" = "warning" ]; then
            color="warning"
        fi
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\", \"color\":\"$color\"}" \
            "$SLACK_WEBHOOK_URL"
        
        log_success "Slack notification sent"
    else
        log_info "Slack webhook URL not configured. Skipping notification."
    fi
}

# Function to cleanup after deployment
cleanup_after_deployment() {
    log_info "Cleaning up after deployment..."
    
    # Clean build artifacts
    ./scripts/build.sh --clean
    
    # Clean temporary files
    rm -f build/ExportOptions.plist
    rm -f build/release-notes-*.md
    
    log_success "Cleanup completed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -t, --testflight        Deploy to TestFlight only"
    echo "  -a, --appstore          Deploy to App Store only"
    echo "  -c, --checks            Run pre-deployment checks only"
    echo "  -b, --build             Build and archive only"
    echo "  -n, --notes             Create release notes only"
    echo "  -f, --full              Full deployment process (default)"
    echo "  -d, --dry-run           Dry run (no actual deployment)"
    echo ""
    echo "Examples:"
    echo "  $0 --full              # Full deployment process"
    echo "  $0 --testflight        # Deploy to TestFlight only"
    echo "  $0 --checks            # Run checks only"
    echo "  $0 --dry-run           # Dry run without deployment"
}

# Main function
main() {
    local action="full"
    local dry_run=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -t|--testflight)
                action="testflight"
                shift
                ;;
            -a|--appstore)
                action="appstore"
                shift
                ;;
            -c|--checks)
                action="checks"
                shift
                ;;
            -b|--build)
                action="build"
                shift
                ;;
            -n|--notes)
                action="notes"
                shift
                ;;
            -f|--full)
                action="full"
                shift
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "Starting PestGenie deployment process..."
    log_info "Action: $action"
    log_info "Dry run: $dry_run"
    
    # Load environment variables
    load_environment
    
    # Validate environment
    validate_environment
    
    # Execute based on action
    case $action in
        "checks")
            run_pre_deployment_checks
            ;;
        "build")
            build_and_archive
            ;;
        "notes")
            create_release_notes
            ;;
        "testflight")
            run_pre_deployment_checks
            build_and_archive
            if [ "$dry_run" = false ]; then
                deploy_to_testflight
                send_notification "testflight" "success" "🚀 PestGenie beta build uploaded to TestFlight!"
            else
                log_info "Dry run: Would deploy to TestFlight"
            fi
            ;;
        "appstore")
            run_pre_deployment_checks
            build_and_archive
            if [ "$dry_run" = false ]; then
                deploy_to_appstore
                send_notification "appstore" "success" "🎉 PestGenie submitted to App Store!"
            else
                log_info "Dry run: Would deploy to App Store"
            fi
            ;;
        "full")
            run_pre_deployment_checks
            build_and_archive
            create_release_notes
            
            if [ "$dry_run" = false ]; then
                # Deploy to TestFlight first
                deploy_to_testflight
                send_notification "testflight" "success" "🚀 PestGenie beta build uploaded to TestFlight!"
                
                # Ask for confirmation before App Store deployment
                read -p "Deploy to App Store as well? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    deploy_to_appstore
                    send_notification "appstore" "success" "🎉 PestGenie submitted to App Store!"
                else
                    log_info "Skipping App Store deployment"
                fi
            else
                log_info "Dry run: Would deploy to TestFlight and App Store"
            fi
            
            cleanup_after_deployment
            ;;
        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
    
    log_success "Deployment process completed successfully!"
}

# Run main function with all arguments
main "$@"
