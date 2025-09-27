import SwiftUI

// MARK: - Data Resolution Utilities

struct SDUIDataResolver {
    /// Resolves text content from component key or static text
    static func resolveText(component: SDUIComponent, context: SDUIContext) -> String {
        if let key = component.key, let job = context.currentJob {
            return valueForKey(key: key, job: job) ?? ""
        } else if let text = component.text {
            // Check if the text contains template variables like {{user.email}}
            return resolveTemplateVariables(text: text, context: context)
        }
        return ""
    }

    /// Resolves label text for buttons and inputs
    static func resolveLabel(component: SDUIComponent, context: SDUIContext) -> String {
        if let key = component.key, let job = context.currentJob {
            return valueForKey(key: key, job: job) ?? component.label ?? ""
        }
        return component.label ?? ""
    }

    /// Creates a composite key for storing input values
    static func makeContextKey(key: String, job: Job?) -> String {
        let jobIdString: String = job?.id.uuidString ?? "global"
        return key + "_" + jobIdString
    }

    /// Looks up a field on Job based on a key string
    static func valueForKey(key: String, job: Job) -> String? {
        switch key {
        case "customerName": return job.customerName
        case "address": return job.address
        case "scheduledTime":
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: job.scheduledDate)
        case "scheduledDate":
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: job.scheduledDate)
        case "scheduledDateTime":
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: job.scheduledDate)
        case "status": return job.status.rawValue.capitalized
        case "statusColor": return job.status.rawValue.lowercased()
        case "pinnedNotes": return job.pinnedNotes
        case "notes": return job.notes
        case "id": return job.id.uuidString
        case "isActive": return job.status == .inProgress ? "true" : "false"
        case "isCompleted": return job.status == .completed ? "true" : "false"
        case "isPending": return job.status == .pending ? "true" : "false"
        case "isSkipped": return job.status == .skipped ? "true" : "false"
        default: return nil
        }
    }

    /// Resolves template variables in text strings like {{user.email}}
    static func resolveTemplateVariables(text: String, context: SDUIContext) -> String {
        var resolvedText = text

        // Find all template variables in the format {{variable}}
        let pattern = "\\{\\{([^}]+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        // Process matches in reverse order to maintain string indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text),
                  let variableRange = Range(match.range(at: 1), in: text) else {
                continue
            }

            let variable = String(text[variableRange])

            // Look up the value from the RouteViewModel's text values
            let value = context.routeViewModel.textFieldValues[variable] ?? ""

            // Replace the template with the actual value
            resolvedText.replaceSubrange(range, with: value)
        }

        return resolvedText
    }
}

// MARK: - Style Resolution Utilities

struct SDUIStyleResolver {
    /// Converts a font identifier string to a SwiftUI Font
    static func resolveFont(_ fontName: String?) -> Font {
        guard let name = fontName else { return .body }
        switch name.lowercased() {
        // Standard SwiftUI fonts
        case "headline": return .headline
        case "subheadline": return .subheadline
        case "caption": return .caption
        case "caption2": return .caption2
        case "footnote": return .footnote
        case "title": return .title
        case "title2": return .title2
        case "title3": return .title3
        case "largetitle": return .largeTitle
        case "callout": return .callout
        case "body": return .body

        // Custom semantic fonts for the design system
        case "headlinelarge": return .title
        case "headlinemedium": return .title2
        case "headlinesmall": return .title3
        case "bodylarge": return .body
        case "bodymedium": return .callout
        case "bodysmall": return .caption
        case "captionemphasis": return .caption.bold()
        case "displaylarge": return .largeTitle
        case "displaysmall": return .title
        case "titlemedium": return .title2
        case "titlelarge": return .title

        default: return .body
        }
    }

    /// Converts a color identifier string to a SwiftUI Color
    static func resolveColor(_ colorName: String?, job: Job?) -> Color {
        guard let name = colorName else { return .primary }
        let lower = name.lowercased()

        // Special case: map statusColor to job status
        if lower == "statuscolor", let job = job {
            switch job.status {
            case .pending: return .gray
            case .inProgress: return .blue
            case .completed: return .green
            case .skipped: return .orange
            }
        }

        // Standard colors
        switch lower {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "gray", "grey": return .gray
        case "black": return .black
        case "white": return .white
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "mint": return .mint
        case "teal": return .teal
        case "indigo": return .indigo
        case "brown": return .brown
        case "secondary": return .secondary
        case "primary": return .primary
        case "accent": return .accentColor
        case "clear", "transparent": return .clear
        default:
            // Try to parse hex colors like #RRGGBB
            if lower.hasPrefix("#"), let hexColor = Color(hexString: lower) {
                return hexColor
            }
            return .primary
        }
    }

    /// Resolves a font weight from a string name
    static func resolveFontWeight(_ name: String) -> Font.Weight {
        switch name.lowercased() {
        case "bold": return .bold
        case "semibold": return .semibold
        case "light": return .light
        case "medium": return .medium
        case "heavy": return .heavy
        case "thin": return .thin
        case "ultralight": return .ultraLight
        default: return .regular
        }
    }
}

// MARK: - Style Application Utilities

struct SDUIStyleApplicator {
    /// Applies comprehensive styling to any view
    static func apply(styling component: SDUIComponent, to view: AnyView, job: Job?) -> AnyView {
        var modified = view

        // Basic styling
        modified = applyBasicStyling(component: component, to: modified, job: job)

        // Visual effects
        modified = applyVisualEffects(component: component, to: modified, job: job)

        // Transforms
        modified = applyTransforms(component: component, to: modified)

        return modified
    }

    private static func applyBasicStyling(component: SDUIComponent, to view: AnyView, job: Job?) -> AnyView {
        var modified = view

        // Padding
        if let padding = component.padding {
            modified = AnyView(modified.padding(padding))
        }

        // Background and corner radius - skip if transparent
        if let bgName = component.backgroundColor, bgName.lowercased() != "transparent" {
            let bgColor = SDUIStyleResolver.resolveColor(bgName, job: job)
            // Only apply background if it's not clear/transparent
            if bgColor != .clear {
                if let radius = component.cornerRadius {
                    modified = AnyView(modified
                        .background(RoundedRectangle(cornerRadius: radius).fill(bgColor)))
                } else {
                    modified = AnyView(modified.background(bgColor))
                }
            }
        }

        return modified
    }

    private static func applyVisualEffects(component: SDUIComponent, to view: AnyView, job: Job?) -> AnyView {
        var modified = view

        // Border
        if let borderWidth = component.borderWidth {
            let borderColor = SDUIStyleResolver.resolveColor(component.borderColor, job: job)
            if let radius = component.cornerRadius {
                modified = AnyView(modified.overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(borderColor, lineWidth: borderWidth)
                ))
            } else {
                modified = AnyView(modified.border(borderColor, width: borderWidth))
            }
        }

        // Shadow
        if let shadowRadius = component.shadowRadius {
            let shadowColor = SDUIStyleResolver.resolveColor(component.shadowColor, job: job)
            let offset = component.shadowOffset
            modified = AnyView(modified.shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: offset?.x ?? 0,
                y: offset?.y ?? 2
            ))
        }

        // Opacity
        if let opacity = component.opacity {
            modified = AnyView(modified.opacity(opacity))
        }

        return modified
    }

    private static func applyTransforms(component: SDUIComponent, to view: AnyView) -> AnyView {
        var modified = view

        // Rotation
        if let rotation = component.rotation {
            modified = AnyView(modified.rotationEffect(.degrees(rotation)))
        }

        // Scale
        if let scale = component.scale {
            modified = AnyView(modified.scaleEffect(scale))
        }

        return modified
    }
}

// MARK: - Animation Utilities

struct SDUIAnimationApplicator {
    /// Applies animation and transition effects to a view
    static func apply(animation component: SDUIComponent, to view: AnyView) -> AnyView {
        var modified = view

        // Apply animation if defined
        if let animConfig = component.animation, let animation = resolveAnimation(animConfig) {
            modified = AnyView(modified.animation(animation, value: UUID()))
        }

        // Apply transition if defined
        if let transitionConfig = component.transition {
            let transition = resolveTransition(transitionConfig)
            modified = AnyView(modified.transition(transition))
        }

        return modified
    }

    private static func resolveAnimation(_ anim: SDUIAnimation) -> Animation? {
        let type = anim.type?.lowercased() ?? "easeinout"
        let duration = anim.duration

        switch type {
        case "linear":
            return duration != nil ? .linear(duration: duration!) : .linear
        case "easein":
            return duration != nil ? .easeIn(duration: duration!) : .easeIn
        case "easeout":
            return duration != nil ? .easeOut(duration: duration!) : .easeOut
        case "easeinout":
            return duration != nil ? .easeInOut(duration: duration!) : .easeInOut
        case "spring":
            return .spring(response: duration ?? 0.3, dampingFraction: 0.75)
        default:
            return nil
        }
    }

    private static func resolveTransition(_ transition: SDUITransition) -> AnyTransition {
        guard let type = transition.type?.lowercased() else { return .identity }
        switch type {
        case "slide": return .slide
        case "opacity": return .opacity
        case "scale": return .scale
        case "movein": return .move(edge: .leading)
        case "moveout": return .move(edge: .trailing)
        default: return .identity
        }
    }
}

// MARK: - Error Handling Utilities

struct SDUIErrorHandler {
    /// Creates a user-friendly error view for rendering failures
    static func createErrorView(message: String, component: SDUIComponent? = nil) -> AnyView {
        AnyView(
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Rendering Error")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                if component != nil {
                    Text("Component: \\(component.type.rawValue)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange, lineWidth: 1)
            )
        )
    }

    /// Validates component configuration and returns error if invalid
    static func validateComponent(_ component: SDUIComponent) -> String? {
        // Validate required ID
        if component.id.isEmpty {
            return "Component missing required 'id'"
        }

        // Validate input components have required keys
        if [.textField, .toggle, .slider, .picker, .datePicker, .stepper, .segmentedControl].contains(component.type) {
            if component.valueKey == nil {
                return "Input component missing required 'valueKey'"
            }
        }

        // Validate picker has options
        if component.type == .picker || component.type == .segmentedControl {
            if component.options?.isEmpty != false {
                return "Picker component missing 'options'"
            }
        }

        // Validate slider has valid range
        if component.type == .slider {
            if let min = component.minValue, let max = component.maxValue, min >= max {
                return "Slider minValue must be less than maxValue"
            }
        }

        // Validate stepper has valid range
        if component.type == .stepper {
            if let min = component.minValue, let max = component.maxValue, min >= max {
                return "Stepper minValue must be less than maxValue"
            }
        }

        // Validate container components have children
        if [.vstack, .hstack, .scroll, .grid, .section].contains(component.type) {
            if component.children?.isEmpty != false {
                return "Container component missing 'children'"
            }
        }

        // Validate list component has itemView
        if component.type == .list && component.itemView == nil {
            return "List component missing 'itemView'"
        }

        // Validate navigation components
        if component.type == .navigationLink && component.destination == nil {
            return "NavigationLink missing 'destination'"
        }

        if [.alert, .actionSheet].contains(component.type) && component.isPresented == nil {
            return "\(component.type.rawValue) missing 'isPresented' key"
        }

        // Validate image components
        if component.type == .image && component.imageName == nil && component.url == nil {
            return "Image component missing 'imageName' or 'url'"
        }

        // Validate progress view
        if component.type == .progressView {
            if let progress = component.progress, (progress < 0 || progress > 1) {
                return "ProgressView progress must be between 0 and 1"
            }
        }

        return nil
    }
}

// MARK: - Version Management

struct SDUIVersionManager {
    static let supportedVersions: Set<Int> = [1, 2, 3, 4, 5]
    static let currentVersion = 5

    /// Checks if a screen version is supported
    static func isVersionSupported(_ version: Int) -> Bool {
        return supportedVersions.contains(version)
    }

    /// Gets the appropriate renderer for a given version
    static func getCompatibilityMode(for version: Int) -> String {
        switch version {
        case 1: return "Basic components only"
        case 2: return "Added images and conditionals"
        case 3: return "Form inputs and styling"
        case 4: return "Full component library"
        case 5: return "Complete core components with enhanced validation"
        default: return "Unsupported version"
        }
    }
}