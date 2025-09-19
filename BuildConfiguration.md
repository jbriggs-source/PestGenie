# PestGenie Build Configuration Guide

## Release Build Settings

### Xcode Project Configuration

#### Build Settings
1. **Code Signing**
   - Development Team: Set to your Apple Developer Team ID
   - Code Signing Identity: "iPhone Distribution" for Release
   - Provisioning Profile: Use "Automatic" or specify distribution profile

2. **Optimization**
   - Swift Compiler - Code Generation:
     - Optimization Level: `-O` (Optimize for Speed)
     - Whole Module Optimization: Yes
   - Apple Clang - Code Generation:
     - Optimization Level: `-Os` (Optimize for Size)

3. **Deployment**
   - iOS Deployment Target: 15.0 (minimum supported)
   - Supported Platforms: iOS
   - Targeted Device Family: iPhone, iPad

4. **Bitcode**
   - Enable Bitcode: No (deprecated by Apple)

5. **App Thinning**
   - Enable On Demand Resources: Yes
   - Asset Catalog Compiler: Optimize for deployment

#### Info.plist Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Identity -->
    <key>CFBundleDisplayName</key>
    <string>PestGenie</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourcompany.pestgenie</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>

    <!-- Required Device Capabilities -->
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>location-services</string>
        <string>gps</string>
    </array>

    <!-- Privacy Usage Descriptions -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>PestGenie needs location access to navigate to job sites and track service areas for accurate pest control services.</string>

    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>PestGenie needs location access to provide background job notifications and optimize route planning for pest control services.</string>

    <key>NSCameraUsageDescription</key>
    <string>PestGenie uses the camera to capture before and after photos of pest control treatments for service documentation.</string>

    <key>NSPhotoLibraryUsageDescription</key>
    <string>PestGenie accesses your photo library to attach existing photos to service reports and job documentation.</string>

    <key>NSContactsUsageDescription</key>
    <string>PestGenie accesses contacts to easily add customer information and streamline job scheduling.</string>

    <!-- Supported Interface Orientations -->
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>

    <!-- Background Modes -->
    <key>UIBackgroundModes</key>
    <array>
        <string>background-app-refresh</string>
        <string>location</string>
        <string>remote-notification</string>
    </array>

    <!-- URL Schemes -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.yourcompany.pestgenie</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>pestgenie</string>
            </array>
        </dict>
    </array>

    <!-- Associated Domains -->
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:pestgenie.com</string>
        <string>applinks:www.pestgenie.com</string>
    </array>

    <!-- App Transport Security -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>api.pestgenie.com</key>
            <dict>
                <key>NSExceptionRequiresForwardSecrecy</key>
                <false/>
                <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
                <false/>
            </dict>
        </dict>
    </dict>

    <!-- Privacy Manifest -->
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeLocation</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypePhotos</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>

    <!-- Accessibility -->
    <key>UIAccessibilityEnabled</key>
    <true/>
    <key>UILargeContentViewerEnabled</key>
    <true/>
</dict>
</plist>
```

## Build Scripts

### Pre-build Script (Run Script Phase)
```bash
#!/bin/bash

# Update build number with current timestamp
BUILD_NUMBER=$(date +%Y%m%d%H%M)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "${INFOPLIST_FILE}"

# Validate required files exist
if [ ! -f "${SRCROOT}/PestGenie/TechnicianScreen.json" ]; then
    echo "error: Required SDUI configuration file missing"
    exit 1
fi

# Verify privacy manifest
if [ ! -f "${SRCROOT}/PrivacyInfo.xcprivacy" ]; then
    echo "warning: Privacy manifest not found - required for App Store submission"
fi

echo "Pre-build validation completed successfully"
```

### Post-build Script (Run Script Phase)
```bash
#!/bin/bash

# Archive symbols for crash reporting
if [ "${CONFIGURATION}" = "Release" ]; then
    echo "Archiving symbols for release build"
    # dsymutil commands would go here for crash reporting setup
fi

# Validate bundle size
BUNDLE_SIZE=$(du -sh "${CODESIGNING_FOLDER_PATH}" | cut -f1)
echo "Bundle size: $BUNDLE_SIZE"

# Validate required entitlements
if [ "${CONFIGURATION}" = "Release" ]; then
    codesign -d --entitlements :- "${CODESIGNING_FOLDER_PATH}" > /tmp/entitlements.xml
    if grep -q "com.apple.developer.location" /tmp/entitlements.xml; then
        echo "Location entitlements verified"
    else
        echo "warning: Location entitlements not found"
    fi
fi

echo "Post-build validation completed"
```

## Entitlements

### PestGenie.entitlements
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Push Notifications -->
    <key>aps-environment</key>
    <string>production</string>

    <!-- Associated Domains -->
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:pestgenie.com</string>
        <string>applinks:www.pestgenie.com</string>
    </array>

    <!-- Background Modes -->
    <key>com.apple.developer.background-modes</key>
    <array>
        <string>background-app-refresh</string>
        <string>location</string>
        <string>remote-notification</string>
    </array>

    <!-- Core Data CloudKit -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.yourcompany.pestgenie</string>
    </array>

    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)com.yourcompany.pestgenie</string>
</dict>
</plist>
```

## App Store Metadata

### App Store Connect Configuration

#### App Information
- **Name**: PestGenie
- **Subtitle**: Professional Pest Control Management
- **Category**: Business
- **Content Rating**: 4+ (No objectionable content)

#### App Privacy
- **Privacy Policy URL**: https://pestgenie.com/privacy
- **Data Types Collected**:
  - Location (for job site navigation)
  - Photos (for service documentation)
  - Contact Info (for customer management)

#### Pricing and Availability
- **Price**: Free (with optional in-app purchases for premium features)
- **Availability**: All territories
- **Release**: Manual release after approval

#### App Store Optimization
- **Keywords**: pest control, exterminator, route management, job tracking, field service
- **Description**:
```
PestGenie is the ultimate pest control management app designed specifically for professional exterminators and pest control technicians.

KEY FEATURES:
• Intelligent route planning and job scheduling
• Offline-capable job management
• Digital signature capture and photo documentation
• Real-time GPS navigation to job sites
• Customer communication and service history
• Comprehensive reporting and analytics

BUILT FOR PROFESSIONALS:
✓ Works offline - no internet required for basic operations
✓ Syncs automatically when connected
✓ Optimized for iOS devices and tablets
✓ Enterprise-grade security and data protection

STREAMLINE YOUR WORKFLOW:
PestGenie's server-driven UI adapts to your business needs without requiring app updates. Get new features and customizations deployed instantly.

Perfect for:
• Independent pest control operators
• Large pest control companies
• Technicians and field workers
• Route managers and supervisors

Download PestGenie today and transform your pest control business with professional-grade mobile technology.
```

#### Screenshots Requirements
- iPhone 6.7": 1290 x 2796 pixels (3 required)
- iPhone 6.5": 1242 x 2688 pixels (3 required)
- iPhone 5.5": 1242 x 2208 pixels (optional)
- iPad Pro 12.9": 2048 x 2732 pixels (2 required)
- iPad Pro 11": 1668 x 2388 pixels (optional)

#### App Preview Videos
- Maximum 30 seconds per video
- Show core functionality: job management, navigation, offline capability
- Include captions for accessibility

## Testing Checklist

### Pre-submission Testing
- [ ] Test on multiple device sizes (iPhone SE, iPhone 14 Pro Max, iPad)
- [ ] Test with VoiceOver enabled
- [ ] Test with Dynamic Type (largest text size)
- [ ] Test with poor network connectivity
- [ ] Test offline functionality completely
- [ ] Test push notifications
- [ ] Test deep linking from various sources
- [ ] Test memory usage with large datasets
- [ ] Test battery usage during extended use
- [ ] Verify all privacy permissions work correctly
- [ ] Test data export/deletion functionality

### Performance Benchmarks
- [ ] App launch time < 3 seconds
- [ ] Memory usage < 150MB under normal load
- [ ] Battery usage rated as "Low" in Settings
- [ ] Network usage optimized for cellular connections
- [ ] Bundle size < 50MB after App Store optimization

### Compliance Verification
- [ ] All user-facing text supports localization
- [ ] Privacy manifest complete and accurate
- [ ] All required permissions have usage descriptions
- [ ] No use of deprecated APIs
- [ ] Accessibility labels on all interactive elements
- [ ] Support for iOS 15.0 and later verified

## Continuous Integration

### GitHub Actions Workflow
```yaml
name: iOS Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_14.3.app

    - name: Build and test
      run: |
        xcodebuild clean build test \
          -project PestGenie.xcodeproj \
          -scheme PestGenie \
          -destination 'platform=iOS Simulator,name=iPhone 14 Pro'

    - name: Upload test results
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: build/reports/
```

This comprehensive build configuration ensures PestGenie meets all App Store requirements while maintaining high performance and user experience standards.