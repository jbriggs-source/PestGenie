#!/bin/bash

# Quick GUID Fix for Xcode
echo "🔧 Fixing Xcode GUID corruption..."

# Kill Xcode
killall Xcode 2>/dev/null || true
echo "  ✅ Xcode closed"

# Clear problematic caches
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode
echo "  ✅ Xcode caches cleared"

# Clear Swift Package Manager caches
rm -rf .build
rm -rf PestGenie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
echo "  ✅ Swift Package caches cleared"

# Wait for file system
sleep 2

echo "🎉 Fix complete! Now open Xcode and try building."
echo ""
echo "In Xcode:"
echo "1. File → Packages → Reset Package Caches"
echo "2. Product → Clean Build Folder (⌘+Shift+K)"
echo "3. Build and Run (⌘+R)"