# Google Sign-In Integration Setup Guide

This document provides step-by-step instructions for completing the Google Sign-In integration in PestGenie.

## Prerequisites

### 1. Google Cloud Console Setup
1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing project
3. Enable the Google Sign-In API
4. Create credentials for iOS application

### 2. OAuth Client Configuration
1. In Google Cloud Console, go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth client ID**
3. Select **iOS** as application type
4. Enter your app's bundle identifier: `com.pestgenie.app` (or your actual bundle ID)
5. Download the `GoogleService-Info.plist` file

## Xcode Project Configuration

### 1. Add GoogleService-Info.plist
1. Download the `GoogleService-Info.plist` file from Google Cloud Console
2. Drag and drop it into your Xcode project
3. Ensure it's added to your app target
4. Verify the CLIENT_ID is present in the plist file

### 2. Add Swift Package Dependencies
1. In Xcode, select **File** > **Add Package Dependencies**
2. Enter repository URL: `https://github.com/google/GoogleSignIn-iOS`
3. Select version 7.1.0 or later (required for iOS 17+ compatibility)
4. Add both `GoogleSignIn` and `GoogleSignInSwift` to your target

### 3. Configure URL Schemes
1. Open your project settings in Xcode
2. Select your app target
3. Go to **Info** tab
4. Expand **URL Types**
5. Add a new URL Type with:
   - **URL Schemes**: Add your REVERSED_CLIENT_ID from GoogleService-Info.plist
   - **Identifier**: `com.google.oauth`
   - **Role**: Editor

Example:
```
URL Schemes: com.googleusercontent.apps.1234567890-abcdefg
Identifier: com.google.oauth
```

### 4. Update Info.plist
Add the following to your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.google.oauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_REVERSED_CLIENT_ID` with the actual value from your GoogleService-Info.plist.

## Architecture Overview

The implementation follows enterprise-grade patterns:

### Core Components
- **AuthenticationManager**: Central coordinator for all authentication flows
- **GoogleSignInProvider**: Wraps Google SDK with error handling
- **SessionManager**: Manages user sessions and token refresh
- **UserProfileManager**: Handles user profile data and privacy compliance

### Security Features
- Secure token storage in Keychain with biometric protection
- Integration with existing SecurityManager for encryption
- GDPR/CCPA compliant data handling
- Privacy consent management

### UI Components
- **AuthenticationView**: Main sign-in interface with Google Sign-In button
- **AppRootView**: Manages authentication state and app navigation
- **BiometricSetupView**: Optional biometric authentication setup

## Testing the Integration

### 1. Development Testing
1. Run the app in Simulator or on device
2. Tap "Sign in with Google" button
3. Complete OAuth flow in Safari/SFSafariViewController
4. Verify successful authentication and token storage

### 2. Error Handling Testing
- Test network connectivity issues
- Test cancelled sign-in flows
- Test token refresh scenarios
- Test biometric authentication (device only)

### 3. Privacy Compliance Testing
- Verify privacy consent dialogs appear
- Test data export functionality
- Test user data deletion
- Verify compliance with App Store requirements

## Production Checklist

### Security
- [ ] GoogleService-Info.plist is added to project
- [ ] URL schemes are correctly configured
- [ ] Tokens are stored securely in Keychain
- [ ] Biometric authentication is properly integrated
- [ ] Certificate pinning is configured for API endpoints

### Privacy
- [ ] Privacy consent is requested before authentication
- [ ] User data export is implemented (GDPR compliance)
- [ ] User data deletion is implemented (GDPR compliance)
- [ ] Privacy policy is accessible from authentication screen

### App Store Compliance
- [ ] Privacy manifest is updated for SDK usage
- [ ] GoogleSignIn SDK v7.1.0+ is used (iOS 17+ compatibility)
- [ ] Required device capabilities are declared in Info.plist
- [ ] App Store review guidelines are followed

### Performance
- [ ] Authentication flows are tested on various devices
- [ ] Token refresh works reliably in background
- [ ] Memory usage is optimized for profile image caching
- [ ] Network requests handle connectivity issues gracefully

## Troubleshooting

### Common Issues

**1. "GoogleService-Info.plist not found"**
- Ensure the plist file is added to your Xcode project
- Verify it's included in your app target
- Check that CLIENT_ID is present in the file

**2. "URL scheme not handled"**
- Verify URL schemes in Info.plist match REVERSED_CLIENT_ID
- Ensure AppRootView includes `.onOpenURL` handler
- Check that GoogleSignInProvider.handleURL is called

**3. "Authentication failed"**
- Verify OAuth client configuration in Google Cloud Console
- Check network connectivity
- Ensure bundle identifier matches OAuth client configuration

**4. "Token storage failed"**
- Verify Keychain access permissions
- Check biometric authentication availability
- Ensure SecurityManager is properly initialized

## Support

For additional support:
1. Review Google Sign-In documentation: https://developers.google.com/identity/sign-in/ios
2. Check Apple's Authentication best practices
3. Review PestGenie's existing SecurityManager implementation
4. Consult GDPR/CCPA compliance documentation

## Version Compatibility

- **Minimum iOS Version**: iOS 12.0
- **Recommended iOS Version**: iOS 15.0+
- **GoogleSignIn SDK**: v7.1.0+ (required for iOS 17+)
- **Xcode**: 14.0+
- **Swift**: 5.5+