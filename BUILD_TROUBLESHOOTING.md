# Build Troubleshooting Guide

## Fixed Issues

### ✅ GUID Corruption Error

**Error:** `Could not compute dependency graph: unable to load transferred PIF: The workspace contains multiple references with the same GUID`

**Cause:** Conflicting Swift Package Manager configurations

**Solution Applied:**
1. Removed duplicate `Package.resolved` files
2. Cleared all Swift Package Manager caches
3. Reset package dependencies with `xcodebuild -resolvePackageDependencies`

### ✅ JSON File Caching Issue

**Problem:** Changes to SDUI JSON files (like `ProfileScreen.json`) not reflecting in the app

**Cause:** Xcode's build system caching old versions of JSON files in DerivedData

**Solutions Implemented:**

#### Option 1: Use Makefile (Recommended)
```bash
# Clean build with fresh JSON files
make clean-build

# Just build
make build

# Clean, build, and run
make run
```

#### Option 2: Manual Clean Build
```bash
# Clean all caches
rm -rf ~/Library/Developer/Xcode/DerivedData

# Build fresh
xcodebuild clean build -project PestGenie.xcodeproj -scheme PestGenie
```

#### Option 3: Use Build Script
Run the refresh script manually:
```bash
./Scripts/refresh-json-files.sh
```

## Prevention Tips

1. **Use `make clean-build`** instead of regular Xcode builds when working with JSON files
2. **Check bundle contents** after builds to verify JSON files are updated
3. **Clear DerivedData** if you notice stale content issues

## Verification Commands

Check if JSON files are properly bundled:
```bash
# Find the app bundle
find ~/Library/Developer/Xcode/DerivedData -name "PestGenie.app" -type d

# Check JSON content in bundle
cat "/path/to/PestGenie.app/ProfileScreen.json" | grep -A5 -B5 "caption"
```

## 🛡️ Build Error Prevention System

### **Recommended Build Commands (GUID-Safe)**
```bash
# Use this for daily development (prevents GUID corruption)
make safe-build

# Quick check for issues
make check-build

# Fix any detected issues
make fix-build
```

### **What Causes GUID Corruption?**
1. **Conflicting Swift Package Manager states**
2. **Corrupted Xcode DerivedData**
3. **Multiple Xcode versions with different package resolvers**
4. **Interrupted package resolution**
5. **Network issues during package downloads**

### **Prevention Strategies**
1. **Always use `make safe-build`** instead of regular Xcode builds
2. **Never commit** Swift Package Manager build artifacts:
   - `*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`
   - `Package.resolved` (when conflicting)
   - `.build/` directory
3. **Run prevention script** regularly: `./Scripts/fix-build-issues.sh setup`
4. **Close Xcode** before running build scripts

### **Automated Prevention**
Our prevention system includes:
- ✅ **Automatic GUID corruption detection**
- ✅ **Smart cache cleanup**
- ✅ **Swift Package Manager reset**
- ✅ **Proper .gitignore configuration**
- ✅ **JSON file refresh for SDUI**

## Emergency Reset

If build issues persist:
```bash
# Use our comprehensive fix script
make fix-build

# Or manual nuclear option
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode
killall Xcode
make safe-build
```