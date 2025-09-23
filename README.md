# PestGenie iOS App

Professional pest control management app for technicians and field workers.

## 🚀 Quick Start

### Prerequisites

- macOS 14.0 or later
- Xcode 16.2 or later
- iOS 15.0+ deployment target
- Apple Developer Account

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/pestgenie-ios.git
   cd pestgenie-ios
   ```

2. **Run the setup script**
   ```bash
   ./scripts/setup-environment.sh --full
   ```

3. **Configure environment variables**
   ```bash
   cp .env .env.local
   # Edit .env.local with your actual values
   ```

4. **Set up code signing**
   ```bash
   ./scripts/setup-code-signing.sh --full
   ```

5. **Build and test**
   ```bash
   ./scripts/build.sh --test
   ```

## 📱 Features

- **Intelligent Route Planning**: Optimize job scheduling and navigation
- **Offline Capability**: Work without internet connection
- **Digital Documentation**: Capture signatures and photos
- **Real-time GPS**: Navigate to job sites efficiently
- **Customer Management**: Track service history and communication
- **Comprehensive Reporting**: Analytics and insights
- **Server-Driven UI**: Dynamic interface updates without app updates

## 🛠 Development

### Project Structure

```
PestGenie/
├── PestGenie/                 # Main app source code
│   ├── Models.swift          # Data models
│   ├── SDUI.swift            # Server-driven UI components
│   ├── WeatherAPI.swift      # Weather integration
│   └── ...                   # Other source files
├── PestGenieTests/           # Unit tests
├── PestGenieUITests/         # UI tests
├── fastlane/                 # Fastlane configuration
├── scripts/                  # Build and deployment scripts
├── .github/workflows/        # CI/CD workflows
└── certs/                    # Code signing certificates
```

### Build Commands

```bash
# Run tests
./scripts/build.sh --test

# Build for development
./scripts/build.sh --build --debug

# Build for release
./scripts/build.sh --build --release

# Create archive
./scripts/build.sh --archive

# Full build process
./scripts/build.sh --full
```

### Code Quality

The project uses several tools to maintain code quality:

- **SwiftLint**: Code style and convention enforcement
- **Semgrep**: Security vulnerability scanning
- **SwiftDoc**: Documentation generation
- **Code Coverage**: Test coverage reporting

Run quality checks:
```bash
# Run SwiftLint
swiftlint lint

# Run security scan
semgrep --config=auto .

# Generate documentation
swift-doc generate PestGenie --output Documentation
```

## 🚀 Deployment

### TestFlight Deployment

```bash
# Deploy to TestFlight
./scripts/deploy.sh --testflight

# Or use Fastlane directly
fastlane beta
```

### App Store Deployment

```bash
# Deploy to App Store
./scripts/deploy.sh --appstore

# Or use Fastlane directly
fastlane release
```

### Full Deployment Process

```bash
# Complete deployment (TestFlight + App Store)
./scripts/deploy.sh --full
```

## 🔧 Configuration

### Environment Variables

Create a `.env.local` file with your configuration:

```bash
# Apple Developer Account
APPLE_ID=your-apple-id@example.com
TEAM_ID=YOUR_TEAM_ID
BUNDLE_IDENTIFIER=Greenix.PestGenie

# Code Signing
CERTIFICATE_PASSWORD=your_certificate_password

# App Store Connect API
APP_STORE_CONNECT_API_KEY_ID=your_api_key_id
APP_STORE_CONNECT_API_ISSUER_ID=your_issuer_id

# Slack Integration
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

### Code Signing

The project supports both manual certificate management and Fastlane Match:

#### Manual Setup
```bash
./scripts/setup-code-signing.sh --import
```

#### Fastlane Match (Recommended)
```bash
# Initialize Match
fastlane match init

# Generate certificates
fastlane match development
fastlane match adhoc
fastlane match appstore
```

## 🧪 Testing

### Unit Tests
```bash
# Run unit tests
xcodebuild test -project PestGenie.xcodeproj -scheme PestGenie -destination "platform=iOS Simulator,name=iPhone 15 Pro"
```

### UI Tests
```bash
# Run UI tests
xcodebuild test -project PestGenie.xcodeproj -scheme PestGenie -only-testing:PestGenieUITests
```

### Performance Tests
```bash
# Run performance tests
xcodebuild test -project PestGenie.xcodeproj -scheme PestGenie -only-testing:PestGenieTests/PerformanceTests
```

## 📊 CI/CD

The project uses GitHub Actions for continuous integration and deployment:

- **Pull Request**: Runs tests, code quality checks, and security scans
- **Main Branch**: Builds, tests, and deploys to TestFlight
- **Release**: Creates App Store builds and releases

### Workflow Triggers

- `push` to `main` or `develop` branches
- `pull_request` to `main` or `develop` branches
- `workflow_dispatch` for manual triggers

### Build Matrix

- **macOS**: Latest version
- **Xcode**: 16.2
- **iOS Simulator**: iPhone 15 Pro
- **iOS Version**: 18.2

## 🔒 Security

### Privacy Manifest

The app includes a comprehensive privacy manifest that declares:
- Data collection types (Location, Photos)
- Data usage purposes (App Functionality)
- No tracking or data sharing

### Security Scanning

Automated security scanning includes:
- **Semgrep**: Static analysis for vulnerabilities
- **Dependency Check**: Third-party library vulnerabilities
- **Code Review**: Manual security review process

## 📱 App Store

### App Information

- **Name**: PestGenie
- **Category**: Business
- **Content Rating**: 4+
- **Minimum iOS**: 15.0
- **Target iOS**: 18.2

### Privacy Policy

The app collects the following data:
- **Location**: For job site navigation and route optimization
- **Photos**: For service documentation and before/after photos
- **Contact Info**: For customer management and communication

### App Store Optimization

- **Keywords**: pest control, exterminator, route management, job tracking, field service
- **Screenshots**: Optimized for all device sizes
- **App Preview**: 30-second video showcasing core features

## 🤝 Contributing

### Development Workflow

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow Swift style guidelines
   - Add tests for new functionality
   - Update documentation as needed

3. **Run quality checks**
   ```bash
   ./scripts/build.sh --test
   swiftlint lint
   semgrep --config=auto .
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat(feature): add your feature description"
   ```

5. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

### Commit Message Format

Use conventional commits:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Maintenance tasks

Example: `feat(auth): add biometric authentication`

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Documentation

- [Build Configuration Guide](BuildConfiguration.md)
- [Implementation Guide](IMPLEMENTATION_GUIDE.md)
- [Enterprise Architecture Analysis](ENTERPRISE_ARCHITECTURE_ANALYSIS.md)

### Getting Help

- **Issues**: Create a GitHub issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Slack**: Join our #ios-development channel

### Team

- **iOS Team**: ios-team@yourcompany.com
- **DevOps Team**: devops@yourcompany.com
- **Product Team**: product@yourcompany.com

---

**PestGenie** - Professional pest control management made simple.
