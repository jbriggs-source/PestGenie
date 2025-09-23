#!/bin/bash

# Script to run tests with fallback simulator selection
# This handles cases where the preferred simulator might not be available

set -e

PROJECT="PestGenie.xcodeproj"
SCHEME="PestGenie"
IOS_VERSION="18.2"

# Function to find available iPhone simulator
find_iphone_simulator() {
    local preferred_name="$1"
    local fallback_name="$2"
    
    echo "Looking for iPhone simulators..." >&2
    
    # First, try to find a booted simulator
    local booted_sim=$(xcrun simctl list devices | grep "iPhone.*(Booted)" | head -1)
    if [ -n "$booted_sim" ]; then
        local sim_name=$(echo "$booted_sim" | sed 's/.*iPhone \([^(]*\).*/iPhone \1/' | xargs)
        echo "Found booted simulator: $sim_name" >&2
        echo "$sim_name"
        return 0
    fi
    
    # Try preferred simulator first
    local preferred_sim=$(xcrun simctl list devices | grep "iPhone.*$preferred_name" | head -1)
    if [ -n "$preferred_sim" ]; then
        echo "Found preferred simulator: iPhone $preferred_name" >&2
        echo "iPhone $preferred_name"
        return 0
    fi
    
    # Try fallback simulator
    local fallback_sim=$(xcrun simctl list devices | grep "iPhone.*$fallback_name" | head -1)
    if [ -n "$fallback_sim" ]; then
        echo "Found fallback simulator: iPhone $fallback_name" >&2
        echo "iPhone $fallback_name"
        return 0
    fi
    
    # Try any iPhone simulator
    local any_iphone=$(xcrun simctl list devices | grep "iPhone" | head -1 | sed 's/.*iPhone \([^(]*\).*/iPhone \1/' | xargs)
    if [ -n "$any_iphone" ]; then
        echo "Found available simulator: $any_iphone" >&2
        echo "$any_iphone"
        return 0
    fi
    
    echo "No iPhone simulators found"
    return 1
}

# Function to run tests
run_tests() {
    local simulator_name="$1"
    local test_args="$2"
    
    echo "Running tests on $simulator_name..."
    
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$simulator_name,OS=$IOS_VERSION" \
        $test_args
}

# Main execution
case "$1" in
    "unit")
        SIMULATOR=$(find_iphone_simulator "16 Pro" "16")
        run_tests "$SIMULATOR" "-resultBundlePath TestResults.xcresult -enableCodeCoverage YES"
        ;;
    "ui")
        SIMULATOR=$(find_iphone_simulator "16 Pro" "16")
        run_tests "$SIMULATOR" "-only-testing:PestGenieUITests -resultBundlePath UITestResults.xcresult"
        ;;
    "performance")
        SIMULATOR=$(find_iphone_simulator "16 Pro" "16")
        run_tests "$SIMULATOR" "-only-testing:PestGenieTests/PerformanceTests -resultBundlePath PerformanceTestResults.xcresult"
        ;;
    "build")
        SIMULATOR=$(find_iphone_simulator "16 Pro" "16")
        echo "Building for $SIMULATOR..."
        xcodebuild build \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -destination "platform=iOS Simulator,name=$SIMULATOR,OS=$IOS_VERSION" \
            -configuration Debug
        ;;
    *)
        echo "Usage: $0 {unit|ui|performance|build}"
        echo "  unit       - Run unit tests"
        echo "  ui         - Run UI tests"
        echo "  performance - Run performance tests"
        echo "  build      - Build for simulator"
        exit 1
        ;;
esac

echo "✅ $1 tests completed successfully"
