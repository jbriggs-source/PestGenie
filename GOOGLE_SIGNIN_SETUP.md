# Google Sign-In Configuration Guide

This guide explains how to complete the Google Sign-In setup for PestGenie.

## Prerequisites

✅ **Already Completed:**
- Google Sign-In SDK v9.0.0 integrated via Swift Package Manager
- Authentication architecture implemented
- Template GoogleService-Info.plist created
- URL handling configured in app

## Required Configuration Steps

### 1. Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing project
3. Click "Add app" → iOS
4. Enter bundle identifier: `com.pestgenie.app`
5. Download the `GoogleService-Info.plist` file

### 2. Replace Configuration File

1. Replace the template `GoogleService-Info.plist` with your downloaded file
2. Ensure the file is added to your Xcode project target

### 3. Configure URL Schemes in Xcode

1. Open `PestGenie.xcodeproj` in Xcode
2. Select the PestGenie target
3. Go to Info tab
4. Expand "URL Types" section
5. Add a new URL Type with:
   - **Identifier**: `com.googleusercontent.apps.YOUR_CLIENT_ID`
   - **URL Schemes**: Your `REVERSED_CLIENT_ID` from GoogleService-Info.plist
   - **Role**: Editor

**Example:**
- If your CLIENT_ID is `123456-abcdef.apps.googleusercontent.com`
- Your REVERSED_CLIENT_ID will be `com.googleusercontent.apps.123456-abcdef`
- Add `com.googleusercontent.apps.123456-abcdef` to URL Schemes

### 4. Test Authentication

Once configured, you can test the authentication flow:

1. Build and run the app
2. Navigate to the authentication screen
3. Tap "Sign in with Google"
4. Complete the OAuth flow in the browser
5. Verify you return to the app successfully

## Architecture Overview

The authentication system includes:

- **AuthenticationManager**: Central coordinator for auth operations
- **GoogleSignInProvider**: Google SDK integration with error handling
- **SessionManager**: User session lifecycle management
- **UserProfileManager**: Profile data and privacy compliance
- **AuthenticationView**: SwiftUI interface with Google Sign-In button

## Troubleshooting

### Common Issues

**"GoogleService-Info.plist not found"**
- Ensure the plist file is in your Xcode project target
- Verify the file is named exactly `GoogleService-Info.plist`

**"URL scheme not configured"**
- Check URL Schemes in project Info settings
- Ensure REVERSED_CLIENT_ID matches your plist file

**Authentication fails**
- Verify CLIENT_ID and REVERSED_CLIENT_ID are correct
- Check Firebase project configuration
- Ensure bundle identifier matches Firebase app configuration

### Debug Logs

The app includes helpful debug logging:
- Configuration warnings at app startup
- Authentication flow logging via SecurityLogger
- Network connectivity monitoring

## Privacy & Security

✅ **Enterprise Features Included:**
- Biometric authentication with Keychain storage
- GDPR/CCPA compliance with data export
- Privacy settings integration
- Security event logging
- Offline-first architecture with secure sync

## Next Steps

After configuration:
1. Test authentication flows thoroughly
2. Configure Firebase Authentication settings
3. Set up any additional OAuth providers if needed
4. Review privacy settings and consent flows

The authentication system is production-ready once properly configured with your Firebase credentials.