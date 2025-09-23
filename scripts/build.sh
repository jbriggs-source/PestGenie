#!/bin/bash

# PestGenie Build Script
# This script handles the complete build process for the PestGenie iOS app

set -e  # Exit on any error

# Configuration
PROJECT_NAME="PestGenie"
SCHEME_NAME="PestGenie"
WORKSPACE_PATH="."
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

# Function to check if required tools are installed
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v xcodebuild &> /dev/null; then
        log_error "xcodebuild is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v xcrun &> /dev/null; then
        log_error "xcrun is not installed or not in PATH"
        exit 1
    fi
    
    # Check Xcode version
    XCODE_VERSION=$(xcodebuild -version | head -n1 | awk '{print $2}')
    log_info "Using Xcode version: $XCODE_VERSION"
    
    log_success "All dependencies are available"
}

# Function to clean previous builds
clean_build() {
    log_info "Cleaning previous builds..."
    
    # Clean derived data
    rm -rf ~/Library/Developer/Xcode/DerivedData
    
    # Clean build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Clean archive directory
    rm -rf "$ARCHIVE_DIR"
    mkdir -p "$ARCHIVE_DIR"
    
    log_success "Build environment cleaned"
}

# Function to resolve package dependencies
resolve_dependencies() {
    log_info "Resolving Swift Package Manager dependencies..."
    
    xcodebuild -resolvePackageDependencies \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME"
    
    log_success "Dependencies resolved"
}

# Function to run tests
run_tests() {
    log_info "Running tests..."
    
    # Run unit tests
    xcodebuild test \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=18.2" \
        -resultBundlePath "$BUILD_DIR/TestResults.xcresult" \
        -enableCodeCoverage YES
    
    if [ $? -eq 0 ]; then
        log_success "All tests passed"
    else
        log_error "Tests failed"
        exit 1
    fi
}

# Function to build the app
build_app() {
    local build_type=$1
    local configuration=$2
    
    log_info "Building app for $build_type configuration..."
    
    xcodebuild build \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration "$configuration" \
        -destination "generic/platform=iOS" \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO
    
    if [ $? -eq 0 ]; then
        log_success "App built successfully for $build_type"
    else
        log_error "Build failed for $build_type"
        exit 1
    fi
}

# Function to create archive
create_archive() {
    log_info "Creating archive..."
    
    local archive_path="$ARCHIVE_DIR/$PROJECT_NAME.xcarchive"
    
    xcodebuild archive \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=iOS" \
        -archivePath "$archive_path" \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO
    
    if [ $? -eq 0 ]; then
        log_success "Archive created: $archive_path"
    else
        log_error "Archive creation failed"
        exit 1
    fi
}

# Function to export IPA
export_ipa() {
    log_info "Exporting IPA..."
    
    local archive_path="$ARCHIVE_DIR/$PROJECT_NAME.xcarchive"
    local export_path="$BUILD_DIR/Export"
    local ipa_path="$BUILD_DIR/$PROJECT_NAME.ipa"
    
    # Create export options plist
    cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$EXPORT_METHOD</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF
    
    xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"
    
    if [ $? -eq 0 ]; then
        log_success "IPA exported: $export_path/$PROJECT_NAME.ipa"
    else
        log_error "IPA export failed"
        exit 1
    fi
}

# Function to validate build
validate_build() {
    log_info "Validating build..."
    
    local ipa_path="$BUILD_DIR/Export/$PROJECT_NAME.ipa"
    
    if [ ! -f "$ipa_path" ]; then
        log_error "IPA file not found: $ipa_path"
        exit 1
    fi
    
    # Check IPA size
    local ipa_size=$(du -h "$ipa_path" | cut -f1)
    log_info "IPA size: $ipa_size"
    
    # Validate bundle identifier
    local bundle_id=$(unzip -p "$ipa_path" "Payload/$PROJECT_NAME.app/Info.plist" | plutil -p - | grep -A1 "CFBundleIdentifier" | tail -n1 | awk '{print $3}' | tr -d '"')
    log_info "Bundle identifier: $bundle_id"
    
    log_success "Build validation completed"
}

# Function to generate build report
generate_report() {
    log_info "Generating build report..."
    
    local report_file="$BUILD_DIR/build-report.txt"
    
    cat > "$report_file" << EOF
PestGenie Build Report
=====================
Build Date: $(date)
Build Configuration: $CONFIGURATION
Export Method: $EXPORT_METHOD
Xcode Version: $(xcodebuild -version | head -n1)
iOS Deployment Target: 18.2

Build Artifacts:
- Archive: $ARCHIVE_DIR/$PROJECT_NAME.xcarchive
- IPA: $BUILD_DIR/Export/$PROJECT_NAME.ipa
- Test Results: $BUILD_DIR/TestResults.xcresult

Build Status: SUCCESS
EOF
    
    log_success "Build report generated: $report_file"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -c, --clean             Clean build environment only"
    echo "  -t, --test              Run tests only"
    echo "  -b, --build             Build app only"
    echo "  -a, --archive           Create archive only"
    echo "  -e, --export            Export IPA only"
    echo "  -f, --full              Full build process (default)"
    echo "  -d, --debug             Use Debug configuration"
    echo "  -r, --release           Use Release configuration (default)"
    echo ""
    echo "Examples:"
    echo "  $0 --full              # Full build process"
    echo "  $0 --test              # Run tests only"
    echo "  $0 --build --debug     # Build with Debug configuration"
}

# Main function
main() {
    local action="full"
    local configuration="Release"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--clean)
                action="clean"
                shift
                ;;
            -t|--test)
                action="test"
                shift
                ;;
            -b|--build)
                action="build"
                shift
                ;;
            -a|--archive)
                action="archive"
                shift
                ;;
            -e|--export)
                action="export"
                shift
                ;;
            -f|--full)
                action="full"
                shift
                ;;
            -d|--debug)
                configuration="Debug"
                shift
                ;;
            -r|--release)
                configuration="Release"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "Starting PestGenie build process..."
    log_info "Action: $action"
    log_info "Configuration: $configuration"
    
    # Execute based on action
    case $action in
        "clean")
            check_dependencies
            clean_build
            ;;
        "test")
            check_dependencies
            clean_build
            resolve_dependencies
            run_tests
            ;;
        "build")
            check_dependencies
            clean_build
            resolve_dependencies
            build_app "development" "$configuration"
            ;;
        "archive")
            check_dependencies
            clean_build
            resolve_dependencies
            create_archive
            ;;
        "export")
            check_dependencies
            export_ipa
            validate_build
            ;;
        "full")
            check_dependencies
            clean_build
            resolve_dependencies
            run_tests
            build_app "development" "$configuration"
            create_archive
            export_ipa
            validate_build
            generate_report
            ;;
        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
    
    log_success "Build process completed successfully!"
}

# Run main function with all arguments
main "$@"
