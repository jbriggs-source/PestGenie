# PestGenie iOS Project Makefile
# Ensures clean builds with fresh JSON files and prevents GUID corruption

.PHONY: clean build clean-build safe-build run test help fix-build check-build

# Default target
help:
	@echo "🦌 PestGenie Build Commands:"
	@echo ""
	@echo "  make safe-build     - 🛡️  Safe build with GUID corruption prevention"
	@echo "  make clean-build    - Clean and build with fresh JSON files"
	@echo "  make build          - Build the project"
	@echo "  make clean          - Clean build cache and derived data"
	@echo "  make run            - Clean build and run in simulator"
	@echo "  make test           - Run unit tests"
	@echo "  make fix-build      - 🔧 Fix GUID corruption and build issues"
	@echo "  make check-build    - 🔍 Check for build issues"
	@echo "  make help           - Show this help message"
	@echo ""

# Clean all caches and derived data
clean:
	@echo "🧹 Cleaning build cache..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/PestGenie-*
	@rm -rf ./DerivedData
	@echo "✅ Cache cleaned"

# Build the project
build:
	@echo "🔨 Building PestGenie..."
	@xcodebuild build \
		-project PestGenie.xcodeproj \
		-scheme PestGenie \
		-configuration Debug \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		-quiet

# Clean build - ensures fresh JSON files
clean-build: clean
	@echo "🔄 Starting clean build with fresh JSON files..."
	@./Scripts/refresh-json-files.sh || echo "⚠️  JSON refresh script not available"
	@$(MAKE) build
	@echo "🎉 Clean build completed!"

# Run in simulator
run: clean-build
	@echo "🚀 Launching in simulator..."
	@xcodebuild build \
		-project PestGenie.xcodeproj \
		-scheme PestGenie \
		-configuration Debug \
		-destination 'platform=iOS Simulator,name=iPhone 16'

# Run tests
test:
	@echo "🧪 Running tests..."
	@xcodebuild test \
		-project PestGenie.xcodeproj \
		-scheme PestGenie \
		-destination 'platform=iOS Simulator,name=iPhone 16'

# Safe build with GUID corruption prevention
safe-build:
	@echo "🛡️  Starting safe build with corruption prevention..."
	@./Scripts/fix-build-issues.sh setup
	@./Scripts/refresh-json-files.sh || echo "⚠️  JSON refresh script not available"
	@$(MAKE) build
	@echo "🎉 Safe build completed!"

# Fix GUID corruption and other build issues
fix-build:
	@echo "🔧 Fixing build issues..."
	@./Scripts/fix-build-issues.sh fix
	@echo "✅ Build issues fixed!"

# Check for build issues
check-build:
	@echo "🔍 Checking for build issues..."
	@./Scripts/fix-build-issues.sh check