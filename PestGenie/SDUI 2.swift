import Foundation

/// Top level object describing a screen returned from the server. Contains a
/// version field for compatibility and a root component to render.
struct SDUIScreen: Codable {
    let version: Int
    let component: SDUIComponent
}

/// Enumerates the kinds of components supported by the SDUI engine. New types
/// can be added here to extend the renderer.
enum SDUIComponentType: String, Codable {
    case vstack
    case hstack
    case list
    case text
    case button
    case spacer
    case conditional
    // New primitive components
    case image
    case textField
    case toggle
    case slider
    case scroll // vertical scroll view
}

/// Represents a component in the server‑driven UI. A component may have
/// children (for containers) or additional properties such as keys used to
/// resolve data from the job or static text/labels.
///
/// This is defined as a `class` rather than a `struct` to avoid the
/// “infinite size” compile error that arises when a value type recursively
/// references itself through optional and array properties. Classes are
/// reference types, so recursive references remain finite.
class SDUIComponent: Codable, Identifiable {
    /// Every component has a stable, non‑optional identifier. If the server
    /// does not provide one, a UUID is automatically generated. Having a
    /// non‑optional `id` avoids duplicate `nil` IDs when rendering with ForEach.
    var id: String
    let type: SDUIComponentType
    let key: String?
    let text: String?
    let label: String?
    let actionId: String?
    let font: String?
    let color: String?
    // Array of child components for container types (e.g. vstack, hstack, scroll).
    let children: [SDUIComponent]?
    // Template used for list rows. Only applicable when `type` is `.list`.
    let itemView: SDUIComponent?
    // Key used for conditional rendering. Children render only if the job's
    // property identified by this key has a non‑empty string value.
    let conditionKey: String?
    // MARK: - Styling tokens
    /// Optional padding to apply around the content. A single numeric value
    /// applies uniform padding. Defaults to nil, meaning no extra padding.
    let padding: Double?
    /// Spacing between children in stacks. Applies to VStack/HStack.
    let spacing: Double?
    /// Text or content colour. For buttons, images and text fields this
    /// overrides the default tint.
    let foregroundColor: String?
    /// Background colour. If specified with `cornerRadius` a rounded
    /// rectangle is drawn behind the component.
    let backgroundColor: String?
    /// Corner radius for the background shape. Used in conjunction with
    /// `backgroundColor`.
    let cornerRadius: Double?
    /// Font weight: e.g. "bold", "semibold". Only applicable to text.
    let fontWeight: String?
    // MARK: - Additional primitive properties
    /// Local asset name for image components.
    let imageName: String?
    /// Remote URL for image components. If both imageName and url are set,
    /// imageName takes precedence.
    let url: String?
    /// Key used to bind the value of inputs (text field, toggle, slider) into
    /// the view model's dictionaries. This should be unique within the scope
    /// of the screen.
    let valueKey: String?
    /// Placeholder text for inputs.
    let placeholder: String?
    /// Minimum value for sliders.
    let minValue: Double?
    /// Maximum value for sliders.
    let maxValue: Double?
    /// Step increment for sliders.
    let step: Double?
    /// Whether to display the numeric value of the slider alongside the control.
    let showValue: Bool?
    // MARK: - Animation and transitions
    /// Optional animation definition to apply to the component's appearance.
    let animation: SDUIAnimation?
    /// Optional transition definition to apply when the component appears/disappears.
    let transition: SDUITransition?

    enum CodingKeys: String, CodingKey {
        case id, type, key, text, label, actionId, font, color, children, itemView, conditionKey,
             padding, spacing, foregroundColor, backgroundColor, cornerRadius, fontWeight,
             imageName, url, valueKey, placeholder, minValue, maxValue, step, showValue,
             animation, transition
    }

    /// Memberwise initializer. If `id` is nil, a UUID will be generated.
    init(id: String? = nil,
         type: SDUIComponentType,
         key: String? = nil,
         text: String? = nil,
         label: String? = nil,
         actionId: String? = nil,
         font: String? = nil,
         color: String? = nil,
         children: [SDUIComponent]? = nil,
         itemView: SDUIComponent? = nil,
         conditionKey: String? = nil,
         // Styling tokens
         padding: Double? = nil,
         spacing: Double? = nil,
         foregroundColor: String? = nil,
         backgroundColor: String? = nil,
         cornerRadius: Double? = nil,
         fontWeight: String? = nil,
         // Additional primitive properties
         imageName: String? = nil,
         url: String? = nil,
         valueKey: String? = nil,
         placeholder: String? = nil,
         minValue: Double? = nil,
         maxValue: Double? = nil,
         step: Double? = nil,
         showValue: Bool? = nil,
         animation: SDUIAnimation? = nil,
         transition: SDUITransition? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.type = type
        self.key = key
        self.text = text
        self.label = label
        self.actionId = actionId
        self.font = font
        self.color = color
        self.children = children
        self.itemView = itemView
        self.conditionKey = conditionKey
        self.padding = padding
        self.spacing = spacing
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.fontWeight = fontWeight
        self.imageName = imageName
        self.url = url
        self.valueKey = valueKey
        self.placeholder = placeholder
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.showValue = showValue
        self.animation = animation
        self.transition = transition
    }

    /// Custom decoding to assign a UUID if the id is missing in the payload.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Attempt to decode an ID from the payload; generate one if absent.
        let decodedId = try container.decodeIfPresent(String.self, forKey: .id)
        self.id = decodedId ?? UUID().uuidString
        self.type = try container.decode(SDUIComponentType.self, forKey: .type)
        self.key = try container.decodeIfPresent(String.self, forKey: .key)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.label = try container.decodeIfPresent(String.self, forKey: .label)
        self.actionId = try container.decodeIfPresent(String.self, forKey: .actionId)
        self.font = try container.decodeIfPresent(String.self, forKey: .font)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
        self.children = try container.decodeIfPresent([SDUIComponent].self, forKey: .children)
        self.itemView = try container.decodeIfPresent(SDUIComponent.self, forKey: .itemView)
        self.conditionKey = try container.decodeIfPresent(String.self, forKey: .conditionKey)
        self.padding = try container.decodeIfPresent(Double.self, forKey: .padding)
        self.spacing = try container.decodeIfPresent(Double.self, forKey: .spacing)
        self.foregroundColor = try container.decodeIfPresent(String.self, forKey: .foregroundColor)
        self.backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        self.cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius)
        self.fontWeight = try container.decodeIfPresent(String.self, forKey: .fontWeight)
        self.imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.valueKey = try container.decodeIfPresent(String.self, forKey: .valueKey)
        self.placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        self.minValue = try container.decodeIfPresent(Double.self, forKey: .minValue)
        self.maxValue = try container.decodeIfPresent(Double.self, forKey: .maxValue)
        self.step = try container.decodeIfPresent(Double.self, forKey: .step)
        self.showValue = try container.decodeIfPresent(Bool.self, forKey: .showValue)
        self.animation = try container.decodeIfPresent(SDUIAnimation.self, forKey: .animation)
        self.transition = try container.decodeIfPresent(SDUITransition.self, forKey: .transition)
    }

    /// Custom encoding to ensure all properties, including the generated id,
    /// are persisted. With automatic synthesis, the missing id would be
    /// encoded as nil if it came from a generated UUID, which could lead to
    /// inconsistent IDs when re‑encoding.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(key, forKey: .key)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(actionId, forKey: .actionId)
        try container.encodeIfPresent(font, forKey: .font)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(children, forKey: .children)
        try container.encodeIfPresent(itemView, forKey: .itemView)
        try container.encodeIfPresent(conditionKey, forKey: .conditionKey)
        try container.encodeIfPresent(padding, forKey: .padding)
        try container.encodeIfPresent(spacing, forKey: .spacing)
        try container.encodeIfPresent(foregroundColor, forKey: .foregroundColor)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(cornerRadius, forKey: .cornerRadius)
        try container.encodeIfPresent(fontWeight, forKey: .fontWeight)
        try container.encodeIfPresent(imageName, forKey: .imageName)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(valueKey, forKey: .valueKey)
        try container.encodeIfPresent(placeholder, forKey: .placeholder)
        try container.encodeIfPresent(minValue, forKey: .minValue)
        try container.encodeIfPresent(maxValue, forKey: .maxValue)
        try container.encodeIfPresent(step, forKey: .step)
        try container.encodeIfPresent(showValue, forKey: .showValue)
        try container.encodeIfPresent(animation, forKey: .animation)
        try container.encodeIfPresent(transition, forKey: .transition)
    }
}

/// Represents an animation configuration for a component. Each animation may
/// specify a type (e.g. "easeInOut", "linear", "spring") and a duration in
/// seconds. Additional parameters could be added in future versions.
struct SDUIAnimation: Codable {
    let type: String?
    let duration: Double?
}

/// Represents a transition configuration. The `type` can be any of SwiftUI's
/// built‑in transition identifiers ("slide", "opacity", "scale", etc.).
struct SDUITransition: Codable {
    let type: String?
}