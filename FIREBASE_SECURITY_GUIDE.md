# 🔒 Firebase Credentials Security Guide

This guide explains how to securely manage Firebase credentials in the PestGenie app while avoiding accidental exposure in version control.

## 🚨 **Security Overview**

### **What's Protected**

The following files are automatically excluded from Git commits:
- `GoogleService-Info.plist` (Production)
- `GoogleService-Info-Dev.plist` (Development)
- `GoogleService-Info-Staging.plist` (Staging)
- All `*.secrets` and `api-keys.plist` files

### **Current Security Measures**

✅ **Git Ignore Protection**: Credentials files excluded from version control
✅ **Environment Separation**: Different configs for dev/staging/production
✅ **Validation System**: Automatic detection of template/invalid values
✅ **Secure Loading**: Runtime configuration with fallback handling
✅ **Bundle ID Verification**: Prevents credential mismatches

## 📁 **File Organization**

### **Credential Files (Keep Private)**

```
PestGenie/
├── GoogleService-Info.plist          # Production (NEVER commit)
├── GoogleService-Info-Dev.plist      # Development (NEVER commit)
├── GoogleService-Info-Staging.plist  # Staging (NEVER commit)
└── Core/Configuration/
    └── FirebaseConfig.swift           # Safe to commit
```

### **What Gets Committed**

✅ **FirebaseConfig.swift** - Configuration management code
✅ **Template files** - With placeholder values
❌ **Real credential files** - Automatically ignored by Git

## 🛠 **Setup Instructions**

### **Step 1: Download Your Firebase Configs**

1. **Production Environment**:
   - Download from Firebase Console → Project Settings → iOS App
   - Save as: `GoogleService-Info.plist`
   - Place in: `/PestGenie/GoogleService-Info.plist`

2. **Development Environment** (Optional):
   - Create separate Firebase project for development
   - Download and save as: `GoogleService-Info-Dev.plist`

### **Step 2: Verify Security**

Run this command to check your `.gitignore` is working:

```bash
git status
```

You should **NOT** see any `GoogleService-Info*.plist` files listed.

### **Step 3: Test Configuration**

The app will automatically:
- ✅ Load the correct config based on build environment
- ✅ Validate all required fields are present
- ✅ Check for template values that need replacement
- ✅ Verify bundle ID matches your app

## 🔐 **Advanced Security Options**

### **Option 1: Environment Variables (CI/CD)**

For automated builds, store credentials as secure environment variables:

```swift
// In FirebaseConfig.swift - add this method
private func loadFromEnvironment() -> [String: Any]? {
    guard let clientId = ProcessInfo.processInfo.environment["FIREBASE_CLIENT_ID"],
          let apiKey = ProcessInfo.processInfo.environment["FIREBASE_API_KEY"] else {
        return nil
    }

    return [
        "CLIENT_ID": clientId,
        "API_KEY": apiKey,
        // ... other required fields
    ]
}
```

### **Option 2: Encrypted Configuration**

For maximum security, encrypt credential files:

```bash
# Encrypt credentials file
gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
    --s2k-digest-algo SHA512 --s2k-count 65536 --symmetric \
    --output GoogleService-Info.plist.gpg GoogleService-Info.plist

# Decrypt at build time (CI/CD)
gpg --quiet --batch --yes --decrypt --passphrase="$GPG_PASSPHRASE" \
    --output GoogleService-Info.plist GoogleService-Info.plist.gpg
```

### **Option 3: Keychain Storage**

Store sensitive values in macOS Keychain during development:

```swift
// Store in Keychain
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "PestGenie-Firebase",
    kSecAttrAccount as String: "CLIENT_ID",
    kSecValueData as String: clientId.data(using: .utf8)!
]
SecItemAdd(query as CFDictionary, nil)

// Retrieve from Keychain
let retrieveQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "PestGenie-Firebase",
    kSecAttrAccount as String: "CLIENT_ID",
    kSecReturnData as String: true
]
```

## 🚫 **What NOT to Do**

### **Never Commit These**

❌ Real `GoogleService-Info.plist` files
❌ API keys in source code
❌ Hard-coded credentials
❌ Unencrypted credential files
❌ Screenshots containing credentials

### **Avoid These Mistakes**

❌ Adding credentials to comments
❌ Logging sensitive values
❌ Storing in UserDefaults
❌ Including in error messages
❌ Putting in Git commit messages

## 🧪 **Testing Security**

### **Verify Git Ignore**

```bash
# Check what Git sees
git ls-files | grep -E "(GoogleService|firebase|credential)"

# Should return empty or only template files
```

### **Scan for Exposed Secrets**

```bash
# Install git-secrets
brew install git-secrets

# Scan repository
git secrets --scan

# Scan history
git secrets --scan-history
```

### **Validate Configuration**

The app includes built-in validation:

```swift
let validation = FirebaseConfig.shared.validateConfiguration()
if !validation.isValid {
    print("Security issues found:")
    validation.issues.forEach { print("- \($0)") }
}
```

## 📱 **Production Deployment**

### **App Store Submission**

1. ✅ Ensure production `GoogleService-Info.plist` is included in app bundle
2. ✅ Verify no development credentials are included
3. ✅ Test OAuth flows work with production Firebase project
4. ✅ Confirm bundle ID matches Firebase configuration

### **TestFlight/Beta Testing**

- Use staging environment configuration
- Separate Firebase project for beta testing
- Different OAuth consent screen settings if needed

## 🆘 **Emergency Procedures**

### **If Credentials Are Accidentally Committed**

1. **Immediately revoke credentials** in Firebase Console
2. **Generate new credentials**
3. **Remove from Git history**:
   ```bash
   # Remove from history
   git filter-branch --force --index-filter \
     'git rm --cached --ignore-unmatch GoogleService-Info.plist' \
     --prune-empty --tag-name-filter cat -- --all

   # Force push (dangerous - coordinate with team)
   git push origin --force --all
   ```

### **If Project Is Compromised**

1. **Revoke all OAuth clients** in Google Cloud Console
2. **Regenerate all API keys**
3. **Create new Firebase project**
4. **Update app configuration**
5. **Force app update** if credentials were in production

## 🔍 **Monitoring & Alerts**

### **Firebase Console Monitoring**

- Monitor authentication usage for suspicious activity
- Set up alerts for unusual sign-in patterns
- Review OAuth consent screen analytics

### **Google Cloud Console**

- Enable audit logging for credential access
- Set up budget alerts to detect abuse
- Monitor API usage quotas

## ✅ **Security Checklist**

### **Before Each Commit**

- [ ] No credential files staged for commit
- [ ] No API keys in source code
- [ ] No secrets in comments or logs
- [ ] `.gitignore` includes all credential patterns

### **Before Release**

- [ ] Production Firebase configuration tested
- [ ] OAuth consent screen properly configured
- [ ] Bundle ID matches all configurations
- [ ] No development credentials in production build

The security system is now in place to protect your Firebase credentials while maintaining a smooth development workflow!