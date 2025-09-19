# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PestGenie is an iOS SwiftUI application for pest control technicians managing daily routes. The app uses a **Server-Driven UI (SDUI)** architecture where the user interface is dynamically rendered from JSON configurations rather than hardcoded views.

## Build and Development Commands

This is a standard iOS project built with Xcode:

- **Build**: Open `PestGenie.xcodeproj` in Xcode and build (⌘+B)
- **Run**: Build and run on simulator/device (⌘+R)
- **Test**: Run tests (⌘+U)
- **Clean**: Product → Clean Build Folder (⌘+Shift+K)

No package managers (CocoaPods, SPM dependencies) are currently used.

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

### Offline Support
The app queues actions when offline and syncs them when connectivity returns:
- `PendingAction` struct tracks offline operations
- Network monitoring via `NWPathMonitor`
- Automatic sync on connectivity restoration

### Location Features
- `LocationManager.swift`: CoreLocation integration for job site monitoring
- Job coordinates stored in `Job` model for navigation

### UI Components
- `SignatureView.swift`: Capture signatures for job completion
- `ReasonPickerView.swift`: Select reasons for job changes/skips

## Development Guidelines

1. **SDUI First**: When adding new UI features, consider if they should be SDUI components rather than hardcoded SwiftUI views
2. **JSON Versioning**: Use versioned JSON files (v2, v3, etc.) to maintain backward compatibility
3. **Offline Awareness**: New features that modify data should queue actions when offline
4. **Component Reusability**: New SDUI components should be generic and configurable via JSON properties
5. **State Management**: Use `RouteViewModel` for domain state; avoid direct job manipulation in views

## SDUI Component Extension
To add new SDUI component types:
1. Add case to `SDUIComponentType` enum
2. Add properties to `SDUIComponent` class if needed
3. Implement rendering logic in `SDUIRenderer`
4. Update JSON schema documentation