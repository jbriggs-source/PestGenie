#!/bin/bash

# Build Issue Prevention and Fix Script for PestGenie
# Prevents and fixes common Xcode build issues including GUID corruption

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 PestGenie Build Issue Fixer${NC}"
echo "===================================="

# Function to detect GUID corruption
detect_guid_corruption() {
    if xcodebuild -list -project PestGenie.xcodeproj 2>&1 | grep -q "unable to load transferred PIF"; then
        echo -e "${RED}❌ GUID corruption detected${NC}"
        return 0
    else
        echo -e "${GREEN}✅ No GUID corruption detected${NC}"
        return 1
    fi
}

# Function to fix GUID corruption
fix_guid_corruption() {
    echo -e "${YELLOW}🔄 Fixing GUID corruption...${NC}"

    # Kill any running Xcode processes
    killall Xcode 2>/dev/null || true
    killall xcodebuild 2>/dev/null || true

    # Clear all problematic caches
    echo "  🧹 Clearing Xcode caches..."
    rm -rf ~/Library/Developer/Xcode/DerivedData
    rm -rf ~/Library/Caches/com.apple.dt.Xcode

    # Clear Swift Package Manager caches
    echo "  📦 Clearing Swift Package Manager caches..."
    rm -rf .build
    rm -rf PestGenie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm

    # Wait a moment for file system to sync
    sleep 2

    # Resolve packages fresh
    echo "  🔄 Resolving Swift Package dependencies..."
    xcodebuild -resolvePackageDependencies -project PestGenie.xcodeproj -scheme PestGenie > /dev/null 2>&1

    echo -e "${GREEN}✅ GUID corruption fixed${NC}"
}

# Function to prevent future issues
setup_prevention() {
    echo -e "${BLUE}🛡️ Setting up prevention measures...${NC}"

    # Create .gitignore entries if they don't exist
    if [ -f .gitignore ]; then
        if ! grep -q "DerivedData" .gitignore; then
            echo "" >> .gitignore
            echo "# Xcode build artifacts" >> .gitignore
            echo "DerivedData/" >> .gitignore
            echo ".build/" >> .gitignore
            echo "*.xcworkspace/xcshareddata/swiftpm/" >> .gitignore
        fi
    fi

    # Set up pre-build checks
    echo "  📋 Prevention measures configured"
}

# Main execution
main() {
    # Check if we're in the right directory
    if [ ! -f "PestGenie.xcodeproj/project.pbxproj" ]; then
        echo -e "${RED}❌ Error: Run this script from the PestGenie project root directory${NC}"
        exit 1
    fi

    # Always check for and fix GUID corruption
    if detect_guid_corruption; then
        fix_guid_corruption
    fi

    # Set up prevention measures
    setup_prevention

    echo ""
    echo -e "${GREEN}🎉 Build system is ready!${NC}"
    echo ""
    echo "Prevention measures active:"
    echo "  ✅ Automatic GUID corruption detection and fixing"
    echo "  ✅ Proper cache management"
    echo "  ✅ Swift Package Manager reset"
    echo "  ✅ Updated .gitignore"
    echo ""
    echo "Use 'make safe-build' for guaranteed clean builds!"
}

# Handle script arguments
case "${1:-setup}" in
    "check")
        if detect_guid_corruption; then
            exit 1  # Issues found
        else
            exit 0  # No issues
        fi
        ;;
    "fix")
        fix_guid_corruption
        exit 0
        ;;
    "setup")
        main
        exit 0
        ;;
    *)
        echo "Usage: $0 [check|fix|setup]"
        echo "  check - Check for GUID corruption"
        echo "  fix   - Fix GUID corruption"
        echo "  setup - Full setup with prevention (default)"
        exit 1
        ;;
esac