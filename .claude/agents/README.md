# Claude Code Agents for PestGenie

This directory contains specialized agent configurations for enhanced development support.

## Available Agents

### iOS SwiftUI Expert (`ios-swiftui-expert.md`)

**Purpose**: Provides expert-level iOS and SwiftUI development guidance

**Capabilities**:
- SwiftUI best practices and performance optimization
- iOS architecture patterns (MVVM, Clean Architecture)
- Code review with Apple's standards
- Accessibility and App Store compliance
- Testing strategies for iOS apps

**Usage**: Reference this agent when:
- Reviewing Swift/SwiftUI code
- Making architecture decisions
- Optimizing app performance
- Implementing accessibility features
- Preparing for App Store submission

## How to Use Agents

Since Claude Code doesn't currently support automatic agent activation, use this manual process:

### 1. Reference the Agent
When you need iOS expertise, start your request with:
```
Please use the iOS SwiftUI Expert agent perspective from .claude/agents/ios-swiftui-expert.md to help with [your request]
```

### 2. Agent Activation for Code Reviews
```
Acting as the iOS SwiftUI Expert agent, please review this SwiftUI code for performance, maintainability, and Apple best practices:

[your code here]
```

### 3. Architecture Guidance
```
Using the iOS SwiftUI Expert agent guidelines, how should I structure [specific architectural challenge]?
```

## Example Usage

### Code Review Request
```
@ios-swiftui-expert: Please review this SDUI component renderer for SwiftUI best practices:

struct MyRenderer {
    static func render() -> AnyView {
        // code here
    }
}
```

### Performance Analysis
```
As the iOS SwiftUI Expert, analyze the performance implications of our SDUI dynamic rendering system and suggest optimizations.
```

### Architecture Decision
```
iOS SwiftUI Expert: Should we use @StateObject or @ObservedObject for our RouteViewModel in the SDUI system? Consider the lifecycle and data flow implications.
```

## Integration with Development Workflow

### Pre-commit Reviews
Before committing significant SwiftUI changes, run:
```
Please act as the iOS SwiftUI Expert and review my changes for:
1. Performance implications
2. Memory management
3. SwiftUI best practices
4. Accessibility compliance
```

### Feature Planning
When planning new features:
```
iOS SwiftUI Expert: Help me design the architecture for [feature description] following iOS app development best practices.
```

### Debugging Assistance
For complex iOS issues:
```
@ios-swiftui-expert: I'm experiencing [issue description] in my SwiftUI app. What are the most likely causes and recommended solutions?
```

## Agent Maintenance

### Updating Agent Knowledge
When Apple releases new iOS/SwiftUI features or guidelines:
1. Update the agent's documentation references
2. Add new best practices and patterns
3. Update code examples with latest syntax

### Extending Capabilities
To add new specializations:
1. Create new agent files in this directory
2. Define clear responsibilities and triggers
3. Update this README with usage instructions

## Future Enhancements

When Claude Code supports automatic agent activation:
- Agents will trigger automatically based on file types and keywords
- Proactive suggestions will appear during development
- Integrated code analysis will run continuously

Until then, manual agent invocation provides the same expert guidance with explicit requests.