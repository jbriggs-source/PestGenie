import SwiftUI

// MARK: - Component-Specific Renderers

/// Protocol for component-specific renderers
protocol SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView
}

// MARK: - Layout Renderers

struct SDUIStackRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let children = component.children ?? []
        let spacing: CGFloat? = component.spacing.map { CGFloat($0) }

        let stack: AnyView
        switch component.type {
        case .vstack:
            stack = AnyView(VStack(alignment: .leading, spacing: spacing) {
                ForEach(children, id: \.id) { child in
                    SDUIScreenRenderer.render(component: child, context: context)
                }
            })
        case .hstack:
            stack = AnyView(HStack(alignment: .center, spacing: spacing) {
                ForEach(children, id: \.id) { child in
                    SDUIScreenRenderer.render(component: child, context: context)
                }
            })
        default:
            stack = AnyView(EmptyView())
        }

        return SDUIStyleApplicator.apply(styling: component, to: stack, job: context.currentJob)
    }
}

struct SDUIGridRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let children = component.children ?? []
        let columns = component.columns ?? 2
        let gridItems = Array(repeating: GridItem(.flexible()), count: columns)

        let grid = AnyView(LazyVGrid(columns: gridItems, spacing: component.spacing.map { CGFloat($0) }) {
            ForEach(children, id: \.id) { child in
                SDUIScreenRenderer.render(component: child, context: context)
            }
        })

        return SDUIStyleApplicator.apply(styling: component, to: grid, job: context.currentJob)
    }
}

struct SDUIScrollRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let children = component.children ?? []
        let spacing: CGFloat? = component.spacing.map { CGFloat($0) }

        let content = AnyView(VStack(alignment: .leading, spacing: spacing) {
            ForEach(children, id: \.id) { child in
                SDUIScreenRenderer.render(component: child, context: context)
            }
        })

        let scrollView = AnyView(ScrollView {
            content
        })

        return SDUIStyleApplicator.apply(styling: component, to: scrollView, job: context.currentJob)
    }
}

// MARK: - Content Renderers

struct SDUITextRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let text = SDUIDataResolver.resolveText(component: component, context: context)
        let colorName = component.foregroundColor ?? component.color

        var textView = Text(text)
            .font(SDUIStyleResolver.resolveFont(component.font))
            .foregroundColor(SDUIStyleResolver.resolveColor(colorName, job: context.currentJob))

        if let weightName = component.fontWeight {
            textView = textView.fontWeight(SDUIStyleResolver.resolveFontWeight(weightName))
        }

        let styledView = SDUIStyleApplicator.apply(styling: component, to: AnyView(textView), job: context.currentJob)
        return SDUIAnimationApplicator.apply(animation: component, to: styledView)
    }
}

struct SDUIButtonRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let labelStr = SDUIDataResolver.resolveLabel(component: component, context: context)
        let actionId = component.actionId

        let baseButton = Button(labelStr) {
            if let id = actionId, let action = context.actions[id] {
                action(context.currentJob)
            }
        }
        .buttonStyle(.bordered)

        let buttonView: AnyView
        if let fg = component.foregroundColor {
            let color = SDUIStyleResolver.resolveColor(fg, job: context.currentJob)
            buttonView = AnyView(baseButton.tint(color))
        } else {
            buttonView = AnyView(baseButton)
        }

        let styledView = SDUIStyleApplicator.apply(styling: component, to: buttonView, job: context.currentJob)
        return SDUIAnimationApplicator.apply(animation: component, to: styledView)
    }
}

// MARK: - Form Input Renderers

struct SDUIInputRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        switch component.type {
        case .textField:
            return renderTextField(component: component, context: context)
        case .toggle:
            return renderToggle(component: component, context: context)
        case .slider:
            return renderSlider(component: component, context: context)
        case .picker:
            return renderPicker(component: component, context: context)
        case .datePicker:
            return renderDatePicker(component: component, context: context)
        case .stepper:
            return renderStepper(component: component, context: context)
        case .segmentedControl:
            return renderSegmentedControl(component: component, context: context)
        default:
            return AnyView(Text("Unsupported input type"))
        }
    }

    private static func renderTextField(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let binding = Binding<String>(
            get: { context.routeViewModel.textFieldValues[contextKey] ?? "" },
            set: { context.routeViewModel.setTextValue(forKey: contextKey, value: $0) }
        )

        let placeholder = component.placeholder ?? ""
        let baseField = TextField(placeholder, text: binding)

        let fieldView: AnyView
        if let fg = component.foregroundColor {
            let color = SDUIStyleResolver.resolveColor(fg, job: context.currentJob)
            fieldView = AnyView(baseField.foregroundColor(color))
        } else {
            fieldView = AnyView(baseField)
        }

        let styledView = SDUIStyleApplicator.apply(styling: component, to: fieldView, job: context.currentJob)
        return SDUIAnimationApplicator.apply(animation: component, to: styledView)
    }

    private static func renderToggle(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let binding = Binding<Bool>(
            get: { context.routeViewModel.toggleValues[contextKey] ?? false },
            set: { context.routeViewModel.setToggleValue(forKey: contextKey, value: $0) }
        )

        let labelStr = component.label ?? SDUIDataResolver.resolveText(component: component, context: context)
        let toggleView = Toggle(isOn: binding) {
            Text(labelStr)
        }

        return SDUIStyleApplicator.apply(styling: component, to: AnyView(toggleView), job: context.currentJob)
    }

    private static func renderSlider(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let minValue = component.minValue ?? 0
        let maxValue = component.maxValue ?? 1
        let step = component.step ?? 0.1

        let binding = Binding<Double>(
            get: { context.routeViewModel.sliderValues[contextKey] ?? minValue },
            set: { context.routeViewModel.setSliderValue(forKey: contextKey, value: $0) }
        )

        let slider = Slider(value: binding, in: minValue...maxValue, step: step)

        let sliderStack: AnyView
        if component.showValue == true {
            sliderStack = AnyView(VStack(alignment: .leading) {
                slider
                Text(String(format: "%.2f", binding.wrappedValue))
            })
        } else {
            sliderStack = AnyView(slider)
        }

        let styledView = SDUIStyleApplicator.apply(styling: component, to: sliderStack, job: context.currentJob)
        return SDUIAnimationApplicator.apply(animation: component, to: styledView)
    }

    private static func renderPicker(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let options = component.options ?? []
        let binding = Binding<String>(
            get: { context.routeViewModel.pickerValues[contextKey] ?? (options.first?.value ?? "") },
            set: { context.routeViewModel.setPickerValue(forKey: contextKey, value: $0) }
        )

        let label = component.label ?? "Select"
        let pickerView = AnyView(Picker(label, selection: binding) {
            ForEach(options) { option in
                Text(option.text).tag(option.value)
            }
        })

        return SDUIStyleApplicator.apply(styling: component, to: pickerView, job: context.currentJob)
    }

    private static func renderDatePicker(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let binding = Binding<Date>(
            get: { context.routeViewModel.datePickerValues[contextKey] ?? Date() },
            set: { context.routeViewModel.setDatePickerValue(forKey: contextKey, value: $0) }
        )

        let label = component.label ?? "Select Date"
        let datePickerView = AnyView(DatePicker(label, selection: binding, displayedComponents: .date))

        return SDUIStyleApplicator.apply(styling: component, to: datePickerView, job: context.currentJob)
    }

    private static func renderStepper(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let minValue = component.minValue ?? 0
        let maxValue = component.maxValue ?? 100
        let step = component.step ?? 1

        let binding = Binding<Double>(
            get: { context.routeViewModel.stepperValues[contextKey] ?? minValue },
            set: { context.routeViewModel.setStepperValue(forKey: contextKey, value: $0) }
        )

        let label = component.label ?? "Value"
        let stepperView = AnyView(Stepper("\\(label): \\(Int(binding.wrappedValue))", value: binding, in: minValue...maxValue, step: step))

        return SDUIStyleApplicator.apply(styling: component, to: stepperView, job: context.currentJob)
    }

    private static func renderSegmentedControl(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let options = component.options ?? []
        let binding = Binding<Int>(
            get: { context.routeViewModel.segmentedValues[contextKey] ?? 0 },
            set: { context.routeViewModel.setSegmentedValue(forKey: contextKey, value: $0) }
        )

        let segmentedView = AnyView(Picker("", selection: binding) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Text(option.text).tag(index)
            }
        }.pickerStyle(.segmented))

        return SDUIStyleApplicator.apply(styling: component, to: segmentedView, job: context.currentJob)
    }
}