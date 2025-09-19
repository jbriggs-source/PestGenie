import SwiftUI

/// Context passed into the renderer. Contains domain data (jobs), environment
/// objects (view model) and an action map for buttons. When rendering a
/// component within a list, `currentJob` is set to the job for which we are
/// rendering. Otherwise it remains nil.
struct SDUIContext {
    let jobs: [Job]
    /// Renamed from `viewModel` to `routeViewModel` to avoid potential name
    /// conflicts with `@EnvironmentObject` properties on SwiftUI views. This
    /// clarifies that the view model pertains to routing logic.
    let routeViewModel: RouteViewModel
    let actions: [String: (Job?) -> Void]
    var currentJob: Job?

    /// Returns a new context with the current job set to the provided job.
    /// This helps avoid state mutation inside SwiftUI view builder closures.
    func withCurrentJob(_ job: Job?) -> SDUIContext {
        var newContext = self
        newContext.currentJob = job
        return newContext
    }
}

/// Primary entry point for rendering a screen. Given a `SDUIScreen` and a
/// context, produces a view. If the version specified in the screen is not
/// supported, returns a fallback view (static UI). The current implementation
/// supports version 1.
struct SDUIScreenRenderer {
    static func render(screen: SDUIScreen, context: SDUIContext) -> AnyView {
        // Allow rendering of versions up to 3; fallback if version exceeds supported range.
        guard screen.version <= 3 else {
            return AnyView(Text("Unsupported version").foregroundColor(.red))
        }
        return render(component: screen.component, context: context)
    }
    /// Recursively renders a component. The return type is `AnyView` because
    /// dynamic type erasure is needed for heterogeneous view trees.
    private static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        switch component.type {
        case .vstack:
            // Vertical stack: render each child in order. Convert spacing from Double? to CGFloat?.
            let children = component.children ?? []
            let spacing: CGFloat? = component.spacing.map { CGFloat($0) }
            var view = AnyView(VStack(alignment: .leading, spacing: spacing) {
                ForEach(children, id: \.id) { child in
                    SDUIScreenRenderer.render(component: child, context: context)
                }
            })
            view = applyStyling(to: view, component: component, job: context.currentJob)
            return view
        case .hstack:
            let children = component.children ?? []
            let spacing: CGFloat? = component.spacing.map { CGFloat($0) }
            var view = AnyView(HStack(alignment: .center, spacing: spacing) {
                ForEach(children, id: \.id) { child in
                    SDUIScreenRenderer.render(component: child, context: context)
                }
            })
            view = applyStyling(to: view, component: component, job: context.currentJob)
            return view
        case .scroll:
            // Scrollable container. Wrap children in a VStack inside a ScrollView.
            let children = component.children ?? []
            let spacing: CGFloat? = component.spacing.map { CGFloat($0) }
            var content = AnyView(VStack(alignment: .leading, spacing: spacing) {
                ForEach(children, id: \.id) { child in
                    SDUIScreenRenderer.render(component: child, context: context)
                }
            })
            var scrollView = AnyView(ScrollView {
                content
            })
            scrollView = applyStyling(to: scrollView, component: component, job: context.currentJob)
            return scrollView
        case .spacer:
            var view = AnyView(Spacer())
            view = applyStyling(to: view, component: component, job: context.currentJob)
            return view
        case .text:
            let str = resolveText(component: component, context: context)
            let colourName = component.foregroundColor ?? component.color
            var textView = Text(str)
                .font(resolveFont(component.font))
                .foregroundColor(resolveColor(colourName, job: context.currentJob))
            if let weightName = component.fontWeight {
                textView = textView.fontWeight(resolveFontWeight(weightName))
            }
            var anyView = AnyView(textView)
            anyView = applyStyling(to: anyView, component: component, job: context.currentJob)
            return anyView
        case .button:
            let labelStr = resolveLabel(component: component, context: context)
            let actionId = component.actionId
            // Build the base button first. Apply a default bordered style so
            // buttons are visually distinct. This can be overridden via
            // additional styling in future schema versions.
            let baseButton = Button(labelStr) {
                if let id = actionId, let action = context.actions[id] {
                    action(context.currentJob)
                }
            }
            .buttonStyle(.bordered)
            // Apply foreground tint if specified. We cannot mutate `baseButton` directly
            // because the result type differs, so wrap into AnyView accordingly.
            let buttonAnyView: AnyView
            if let fg = component.foregroundColor {
                let color = resolveColor(fg, job: context.currentJob)
                buttonAnyView = AnyView(baseButton.tint(color))
            } else {
                buttonAnyView = AnyView(baseButton)
            }
            var anyView = buttonAnyView
            anyView = applyStyling(to: anyView, component: component, job: context.currentJob)
            anyView = applyAnimationAndTransition(to: anyView, component: component)
            return anyView
        case .image:
            var anyView: AnyView
            if let imageName = component.imageName {
                anyView = AnyView(Image(imageName)
                                    .resizable()
                                    .scaledToFit())
            } else if let urlString = component.url, let url = URL(string: urlString) {
                anyView = AnyView(AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure(_):
                        Image(systemName: "photo").resizable().scaledToFit()
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                })
            } else {
                anyView = AnyView(EmptyView())
            }
            anyView = applyStyling(to: anyView, component: component, job: context.currentJob)
            return anyView
        case .textField:
            guard let key = component.valueKey else {
                return AnyView(Text("Missing valueKey"))
            }
            let jobIdString: String = context.currentJob?.id.uuidString ?? "global"
            let contextKey = key + "_" + jobIdString
            let binding = Binding<String>(
                get: { context.routeViewModel.textFieldValues[contextKey] ?? "" },
                set: { newValue in
                    context.routeViewModel.setTextValue(forKey: contextKey, value: newValue)
                }
            )
            let placeholder = component.placeholder ?? ""
            let baseField = TextField(placeholder, text: binding)
            // Apply foreground colour if provided. The resulting view has a different
            // type, so wrap into AnyView.
            let textFieldAnyView: AnyView
            if let fg = component.foregroundColor {
                let color = resolveColor(fg, job: context.currentJob)
                textFieldAnyView = AnyView(baseField.foregroundColor(color))
            } else {
                textFieldAnyView = AnyView(baseField)
            }
            var anyView = textFieldAnyView
            anyView = applyStyling(to: anyView, component: component, job: context.currentJob)
            anyView = applyAnimationAndTransition(to: anyView, component: component)
            return anyView
        case .toggle:
            guard let key = component.valueKey else {
                return AnyView(Text("Missing valueKey"))
            }
            let jobIdString: String = context.currentJob?.id.uuidString ?? "global"
            let contextKey = key + "_" + jobIdString
            let binding = Binding<Bool>(
                get: { context.routeViewModel.toggleValues[contextKey] ?? false },
                set: { newValue in
                    context.routeViewModel.setToggleValue(forKey: contextKey, value: newValue)
                }
            )
            let labelStr = component.label ?? resolveText(component: component, context: context)
            var toggleView = Toggle(isOn: binding) {
                Text(labelStr)
            }
            var anyView = AnyView(toggleView)
            anyView = applyStyling(to: anyView, component: component, job: context.currentJob)
            return anyView
        case .slider:
            guard let key = component.valueKey else {
                return AnyView(Text("Missing valueKey"))
            }
            let jobIdString: String = context.currentJob?.id.uuidString ?? "global"
            let contextKey = key + "_" + jobIdString
            let minValue = component.minValue ?? 0
            let maxValue = component.maxValue ?? 1
            let step = component.step ?? 0.1
            let binding = Binding<Double>(
                get: { context.routeViewModel.sliderValues[contextKey] ?? minValue },
                set: { newValue in
                    context.routeViewModel.setSliderValue(forKey: contextKey, value: newValue)
                }
            )
            let slider = Slider(value: binding, in: minValue...maxValue, step: step)
            var sliderStack: AnyView
            if component.showValue == true {
                sliderStack = AnyView(VStack(alignment: .leading) {
                    slider
                    Text(String(format: "%.2f", binding.wrappedValue))
                })
            } else {
                sliderStack = AnyView(slider)
            }
            sliderStack = applyStyling(to: sliderStack, component: component, job: context.currentJob)
            // Apply animation and transition if defined
            sliderStack = applyAnimationAndTransition(to: sliderStack, component: component)
            return sliderStack
        case .list:
            guard let itemTemplate = component.itemView else {
                return AnyView(Text("List missing item template"))
            }
            var listView = List {
                ForEach(context.jobs) { job in
                    let jobContext = context.withCurrentJob(job)
                    SDUIScreenRenderer.render(component: itemTemplate, context: jobContext)
                }
                .onMove { indices, newOffset in
                    context.routeViewModel.moveJob(from: indices, to: newOffset)
                }
            }
            var anyView = AnyView(listView)
            anyView = applyStyling(to: anyView, component: component, job: context.currentJob)
            anyView = applyAnimationAndTransition(to: anyView, component: component)
            return anyView
        case .conditional:
            if let key = component.conditionKey, let job = context.currentJob {
                if let value = valueForKey(key: key, job: job), !value.isEmpty {
                    let children = component.children ?? []
                    // Convert optional Double spacing to optional CGFloat for VStack.
                    let spacing: CGFloat? = component.spacing.map { CGFloat($0) }
                    var stack = AnyView(VStack(alignment: .leading, spacing: spacing) {
                        ForEach(children, id: \.id) { child in
                            SDUIScreenRenderer.render(component: child, context: context)
                        }
                    })
                    stack = applyStyling(to: stack, component: component, job: context.currentJob)
                    stack = applyAnimationAndTransition(to: stack, component: component)
                    return stack
                }
            }
            return AnyView(EmptyView())
        }
    }
    /// Resolves a string for a text component. If `key` is provided, it pulls
    /// the value from the current job. Otherwise returns the static text.
    private static func resolveText(component: SDUIComponent, context: SDUIContext) -> String {
        if let key = component.key, let job = context.currentJob {
            return valueForKey(key: key, job: job) ?? ""
        } else if let text = component.text {
            return text
        }
        return ""
    }
    /// Resolves a label string for a button. Uses `label` or resolves from key.
    private static func resolveLabel(component: SDUIComponent, context: SDUIContext) -> String {
        if let key = component.key, let job = context.currentJob {
            return valueForKey(key: key, job: job) ?? component.label ?? ""
        }
        return component.label ?? ""
    }
    /// Looks up a field on Job based on a key string. Extend this if new
    /// properties need to be accessible.
    private static func valueForKey(key: String, job: Job) -> String? {
        switch key {
        case "customerName": return job.customerName
        case "address": return job.address
        case "scheduledTime":
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: job.scheduledDate)
        case "status": return job.status.rawValue.capitalized
        case "pinnedNotes": return job.pinnedNotes
        default: return nil
        }
    }
    /// Converts a font identifier string to a SwiftUI `Font`. Defaults to body.
    private static func resolveFont(_ fontName: String?) -> Font {
        guard let name = fontName else { return .body }
        switch name.lowercased() {
        case "headline": return .headline
        case "subheadline": return .subheadline
        case "caption": return .caption
        case "footnote": return .footnote
        default: return .body
        }
    }
    /// Converts a color identifier string to a SwiftUI `Color`. Specially
    /// supports "statusColor", which maps to different colors based on the
    /// job's status.
    private static func resolveColor(_ colorName: String?, job: Job?) -> Color {
        guard let name = colorName else { return .primary }
        let lower = name.lowercased()
        // Special case: map statusColor to job status.
        if lower == "statuscolor", let job = job {
            switch job.status {
            case .pending: return .gray
            case .inProgress: return .blue
            case .completed: return .green
            case .skipped: return .orange
            }
        }
        switch lower {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "gray": return .gray
        case "black": return .black
        case "white": return .white
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        case "pink": return .pink
        case "secondary": return .secondary
        case "primary": return .primary
        default:
            // Try to parse hex colors like #RRGGBB
            if lower.hasPrefix("#"), let hexColor = Color(hexString: lower) {
                return hexColor
            }
            return .primary
        }
    }

    /// Resolves a font weight from a string name. Defaults to `.regular`.
    private static func resolveFontWeight(_ name: String) -> Font.Weight {
        switch name.lowercased() {
        case "bold": return .bold
        case "semibold": return .semibold
        case "light": return .light
        case "medium": return .medium
        case "heavy": return .heavy
        default: return .regular
        }
    }

    /// Applies styling tokens such as padding, background color and corner radius to any view.
    private static func applyStyling(to view: AnyView, component: SDUIComponent, job: Job?) -> AnyView {
        var modified = view
        // Padding
        if let padding = component.padding {
            modified = AnyView(modified.padding(padding))
        }
        // Background and corner radius
        if let bgName = component.backgroundColor {
            let bgColor = resolveColor(bgName, job: job)
            if let radius = component.cornerRadius {
                modified = AnyView(modified
                    .background(RoundedRectangle(cornerRadius: radius).fill(bgColor)))
            } else {
                modified = AnyView(modified.background(bgColor))
            }
        }
        return modified
    }

    /// Applies optional animation and transition hooks to a view based on the component's
    /// `animation` and `transition` definitions. If neither is provided, returns the
    /// original view.
    private static func applyAnimationAndTransition(to view: AnyView, component: SDUIComponent) -> AnyView {
        var modified = view
        // Apply animation if defined
        if let animConfig = component.animation, let animation = resolveAnimation(animConfig) {
            // Attach the animation to the view without a specific value to animate all state
            modified = AnyView(modified.animation(animation))
        }
        // Apply transition if defined. A transition only applies when inserted
        // into or removed from a view hierarchy (e.g. conditional or list updates).
        if let transitionConfig = component.transition {
            let transition = resolveTransition(transitionConfig)
            modified = AnyView(modified.transition(transition))
        }
        return modified
    }

    /// Resolves an `SDUIAnimation` into a SwiftUI `Animation` instance. Supports
    /// basic named animations like "easeInOut", "linear", "easeIn", "easeOut",
    /// and "spring". If type is nil, defaults to `.easeInOut`. A duration can
    /// be provided to override the default timing. Spring animations ignore
    /// duration and use a default response/damping configuration.
    private static func resolveAnimation(_ anim: SDUIAnimation) -> Animation? {
        let type = anim.type?.lowercased() ?? "easeinout"
        let duration = anim.duration
        switch type {
        case "linear":
            if let d = duration { return .linear(duration: d) } else { return .linear }
        case "easein":
            if let d = duration { return .easeIn(duration: d) } else { return .easeIn }
        case "easeout":
            if let d = duration { return .easeOut(duration: d) } else { return .easeOut }
        case "easeinout", "easeinout":
            if let d = duration { return .easeInOut(duration: d) } else { return .easeInOut }
        case "spring":
            return .spring(response: duration ?? 0.3, dampingFraction: 0.75)
        default:
            return nil
        }
    }

    /// Resolves an `SDUITransition` into a SwiftUI `AnyTransition`. Supports
    /// common transitions like "slide", "opacity", "scale", "move". Defaults
    /// to `.identity` when unknown or nil.
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

// MARK: - Color Extension

extension Color {
    /// Creates a Color from a hex string like "#RRGGBB" or "#RRGGBBAA". Returns nil if parsing fails.
    init?(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard let int = Int(hex, radix: 16) else {
            return nil
        }
        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
            a = Double(int & 0xFF) / 255.0
        default:
            return nil
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}