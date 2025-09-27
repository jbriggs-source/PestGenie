# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PestGenie is an enterprise-grade iOS SwiftUI application for pest control technicians managing daily routes. The app features a **Server-Driven UI (SDUI)** architecture where the user interface is dynamically rendered from JSON configurations, combined with comprehensive offline-first capabilities, push notifications, and App Store-ready compliance features.

## Build and Development Commands

### Recommended: Use Makefile Commands (Prevents All Build Issues)

- **Safe Build**: `make safe-build` - 🛡️ Safe build with GUID corruption prevention
- **Clean Build**: `make clean-build` - Ensures fresh SDUI JSON files
- **Build**: `make build` - Standard build
- **Run**: `make run` - Clean build and launch in simulator
- **Test**: `make test` - Run unit tests
- **Fix Build**: `make fix-build` - 🔧 Fix GUID corruption and build issues
- **Check Build**: `make check-build` - 🔍 Check for build issues
- **Clean**: `make clean` - Clear all build caches
- **Help**: `make help` - Show all available commands

### Alternative: Standard Xcode Commands

- **Build**: Open `PestGenie.xcodeproj` in Xcode and build (⌘+B)
- **Run**: Build and run on simulator/device (⌘+R)
- **Test**: Run tests (⌘+U)
- **Clean**: Product → Clean Build Folder (⌘+Shift+K)

**⚠️ Important:**
- For daily development, use `make safe-build` to prevent GUID corruption errors
- When modifying SDUI JSON files, use `make clean-build` to prevent caching issues
- If you encounter build errors, run `make fix-build` to automatically resolve them

### Dependencies
Uses Swift Package Manager for Google Sign-In and related dependencies.

## Architecture

### Server-Driven UI (SDUI) System
The app's core innovation is its SDUI architecture that allows UI changes without app updates:

- **JSON Definitions**: UI screens are defined in JSON files (e.g., `TechnicianScreen.json`, `TechnicianScreen_v3.json`)
- **SDUI Components**: Mapped to SwiftUI views via `SDUIComponent` class and `SDUIComponentType` enum
- **Dynamic Rendering**: `SDUIRenderer` interprets JSON and builds SwiftUI views at runtime
- **Versioned Loading**: App attempts to load newer JSON versions first, falling back to older ones

### Key Components

**Models** (`Models.swift`):
- `Job`: Core data model for service appointments with status tracking
- `JobStatus`: Enum for job states (pending, inProgress, completed, skipped)
- `ReasonCode`: Predefined reasons for job changes

**SDUI Engine** (`SDUI.swift`):
- `SDUIScreen`: Top-level container for JSON-defined screens
- `SDUIComponent`: Recursive component tree supporting containers, primitives, and styling
- `SDUIComponentType`: Enum defining supported UI components (vstack, hstack, list, text, button, etc.)

**View Model** (`RouteViewModel.swift`):
- Manages job collection and state changes
- Handles offline mode with action queuing
- Provides SDUI input value storage (text fields, toggles, sliders)
- Network connectivity monitoring

**Main Views**:
- `SDUITechnicianApp.swift`: App entry point with environment setup
- `SDUIContentView.swift`: Loads JSON and renders SDUI screens
- `SDUIRenderer.swift`: Core rendering engine (not shown but referenced)

### Enterprise Features

#### Offline-First Data Synchronization
- **Core Data Stack**: Persistent storage with CloudKit integration
- **Background Sync**: Automatic synchronization with conflict resolution
- **Network Monitoring**: Intelligent sync based on connection quality
- **Data Versioning**: Comprehensive migration and version management

#### Push Notifications & Deep Linking
- **Apple Push Notifications**: Full APNs integration with notification categories
- **Deep Linking**: Universal links and custom URL schemes
- **Background Tasks**: Scheduled background sync and maintenance
- **Notification Actions**: Interactive notifications with job management

#### Performance & Bundle Optimization
- **Memory Management**: Intelligent caching and memory pressure handling
- **Bundle Optimization**: On-demand resources and asset optimization
- **Performance Monitoring**: Real-time metrics and diagnostics
- **Battery Efficiency**: Network-aware operations and background task optimization

#### App Store Compliance
- **Privacy Compliance**: GDPR/CCPA data export and deletion
- **Accessibility**: Full VoiceOver and Dynamic Type support
- **Security**: Data encryption and privacy controls
- **Submission Ready**: Complete App Store metadata and compliance checking

### Location Features
- `LocationManager.swift`: CoreLocation integration for job site monitoring
- Job coordinates stored in `Job` model for navigation

### UI Components
- `SignatureView.swift`: Capture signatures for job completion
- `ReasonPickerView.swift`: Select reasons for job changes/skips

## Development Guidelines

### Core Principles
1. **SDUI First**: When adding new UI features, consider if they should be SDUI components rather than hardcoded SwiftUI views
2. **Offline First**: All data operations must work offline with automatic sync when connected
3. **Performance Aware**: Monitor memory usage, battery consumption, and network efficiency
4. **Privacy Compliant**: Implement proper data handling and user consent mechanisms
5. **Accessible by Design**: Support VoiceOver, Dynamic Type, and inclusive design principles

### Implementation Standards
1. **JSON Versioning**: Use versioned JSON files (v2, v3, etc.) to maintain backward compatibility
2. **Background Safe**: Ensure proper background task limits and state preservation
3. **Component Reusability**: New SDUI components should be generic and configurable via JSON properties
4. **State Management**: Use proper SwiftUI state management with @StateObject/@ObservedObject patterns
5. **Error Handling**: Implement comprehensive error boundaries and user feedback
6. **Security First**: Encrypt sensitive data and implement proper authentication
7. **Testing Coverage**: Unit tests for business logic, UI tests for critical user flows

## SDUI Component Library

The expanded SDUI system now supports a comprehensive set of components for full-featured app development:

### Layout Components
- `vstack`, `hstack`: Vertical and horizontal stacks with spacing control
- `grid`: Multi-column grid layouts with configurable columns
- `list`: Dynamic lists with custom item templates
- `scroll`: Scrollable content containers
- `section`: Grouped content with optional headers
- `tabView`: Tab-based navigation

### Basic UI Elements
- `text`: Rich text with fonts, weights, and colors
- `button`: Interactive buttons with actions and styling
- `image`: Local and remote images with AsyncImage support
- `spacer`: Flexible spacing
- `divider`: Visual separators
- `progressView`: Progress indicators with values

### Form Input Components
- `textField`: Text input with validation
- `toggle`: Boolean switches
- `slider`: Numeric sliders with ranges and steps
- `picker`: Single/multiple selection from options
- `datePicker`: Date and time selection
- `stepper`: Numeric steppers with increment/decrement
- `segmentedControl`: Segmented selection controls

### Navigation & Presentation
- `navigationLink`: Screen navigation
- `alert`: Alert dialogs
- `actionSheet`: Action sheet presentations
- `conditional`: Conditional rendering based on job data

### Advanced Components (Extensible)
- `mapView`: Map integration (requires MapKit)
- `webView`: Web content (requires WebKit)
- `chart`: Data visualization (requires Charts framework)
- `gauge`: Gauge displays (iOS 16+)

### Advanced Styling System
- **Layout**: `padding`, `spacing`, `columns`, `cornerRadius`
- **Colors**: `foregroundColor`, `backgroundColor`, `borderColor`, `shadowColor`
- **Visual Effects**: `borderWidth`, `shadowRadius`, `shadowOffset`, `opacity`
- **Transforms**: `rotation`, `scale`
- **Typography**: `font`, `fontWeight`
- **Animations**: `animation` (spring, easeIn, easeOut, linear)
- **Transitions**: `transition` (slide, opacity, scale, move)
- **Hex Color Support**: Use `#RRGGBB` format for custom colors

### Data Binding & State Management
- **Job Data**: Bind to job properties via `key` attribute
- **Input Values**: Store form data with `valueKey` in RouteViewModel
- **Presentation State**: Manage sheet/alert visibility
- **Offline Support**: Automatic action queuing when offline

### JSON Schema Versioning
- **v1**: Basic components (vstack, hstack, list, text, button)
- **v2**: Added image, conditional rendering
- **v3**: Form inputs (textField, toggle, slider)
- **v4**: Comprehensive library with all components and advanced styling

## Development Support

### iOS SwiftUI Expert Agent
The project includes a specialized iOS SwiftUI Expert agent in `.claude/agents/` for enhanced development support:

**To use the agent**: Start requests with "Please use the iOS SwiftUI Expert agent perspective" when you need:
- SwiftUI code reviews and optimization
- iOS architecture guidance (MVVM, Clean Architecture)
- Performance analysis and memory management
- Accessibility and App Store compliance
- Testing strategies for iOS applications

**Example usage**:
```
@ios-swiftui-expert: Review this SDUI renderer for SwiftUI best practices and performance optimizations
```

See `.claude/agents/README.md` for complete usage instructions.

## Enterprise Architecture Files

### Core Data & Persistence
- `PersistenceController.swift`: Core Data stack with CloudKit integration
- `SyncManager.swift`: Offline-first data synchronization with conflict resolution
- `PestGenieDataModel.xcdatamodeld`: Complete data model for enterprise features

### Push Notifications & Deep Linking
- `NotificationManager.swift`: Comprehensive push notification and local notification handling
- `DeepLinkManager.swift`: Universal links and custom URL scheme management
- Background task scheduling and notification categories

### Performance & Optimization
- `PerformanceManager.swift`: Real-time performance monitoring and optimization
- `BundleOptimizer.swift`: On-demand resources and bundle size management
- `NetworkMonitor.swift`: Enhanced network monitoring with data usage optimization

### App Store Compliance
- `AppStoreCompliance.swift`: Privacy compliance, accessibility, and submission requirements
- `BuildConfiguration.md`: Complete build settings and release configuration
- Privacy manifest and data usage descriptions

## SDUI Component Extension
To add new SDUI component types:
1. Add case to `SDUIComponentType` enum in `SDUI.swift`
2. Add properties to `SDUIComponent` class if needed
3. Implement rendering logic in appropriate renderer (performance-optimized)
4. Update RouteViewModel for input components with offline support
5. Test with JSON examples including edge cases
6. **Use iOS SwiftUI Expert agent to review implementation for enterprise compliance**
7. **Verify accessibility and performance implications**
8. **Test offline functionality and data synchronization**