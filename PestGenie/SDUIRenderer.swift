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
    /// Core Data persistence controller for data operations
    let persistenceController: PersistenceController

    /// Returns a new context with the current job set to the provided job.
    /// This helps avoid state mutation inside SwiftUI view builder closures.
    func withCurrentJob(_ job: Job?) -> SDUIContext {
        SDUIContext(
            jobs: jobs,
            routeViewModel: routeViewModel,
            actions: actions,
            currentJob: job,
            persistenceController: persistenceController
        )
    }
}

/// Primary entry point for rendering a screen. Given a `SDUIScreen` and a
/// context, produces a view. If the version specified in the screen is not
/// supported, returns a fallback view (static UI). The current implementation
/// supports version 1.
struct SDUIScreenRenderer {
    static func render(screen: SDUIScreen, context: SDUIContext) -> AnyView {
        // Validate version support
        guard SDUIVersionManager.isVersionSupported(screen.version) else {
            return SDUIErrorHandler.createErrorView(
                message: "Version \(screen.version) not supported. \(SDUIVersionManager.getCompatibilityMode(for: screen.version))"
            )
        }

        return render(component: screen.component, context: context)
    }
    /// Recursively renders a component with improved error handling and modular architecture
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        // Validate component configuration
        if let error = SDUIErrorHandler.validateComponent(component) {
            return SDUIErrorHandler.createErrorView(message: error, component: component)
        }

        // Delegate to appropriate specialized renderer
        switch component.type {
        // Layout components
        case .vstack, .hstack:
            return SDUIStackRenderer.render(component: component, context: context)
        case .scroll:
            return SDUIScrollRenderer.render(component: component, context: context)
        case .grid:
            return SDUIGridRenderer.render(component: component, context: context)
        // Basic UI elements
        case .spacer:
            let view = AnyView(Spacer())
            return SDUIStyleApplicator.apply(styling: component, to: view, job: context.currentJob)
        case .text:
            return SDUITextRenderer.render(component: component, context: context)
        case .button:
            return SDUIButtonRenderer.render(component: component, context: context)
        case .divider:
            let view: AnyView
            if let color = component.foregroundColor {
                view = AnyView(Divider().background(SDUIStyleResolver.resolveColor(color, job: context.currentJob)))
            } else {
                view = AnyView(Divider())
            }
            return SDUIStyleApplicator.apply(styling: component, to: view, job: context.currentJob)
        case .progressView:
            let progressView: AnyView
            if let progress = component.progress {
                progressView = AnyView(ProgressView(value: progress))
            } else {
                progressView = AnyView(ProgressView())
            }
            return SDUIStyleApplicator.apply(styling: component, to: progressView, job: context.currentJob)
        case .image:
            return renderImage(component: component, context: context)
        // Form input components
        case .textField, .toggle, .slider, .picker, .datePicker, .stepper, .segmentedControl:
            return SDUIInputRenderer.render(component: component, context: context)
        case .list:
            return renderList(component: component, context: context)
        case .conditional:
            return renderConditional(component: component, context: context)

        // Chemical management components
        case .chemicalSelector, .dosageCalculator, .chemicalInventory, .treatmentLogger,
             .epaCompliance, .mixingInstructions, .applicationTracker, .chemicalSearch:
            return SDUIChemicalRenderer.render(component: component, context: context)

        // Weather components
        case .weatherDashboard, .weatherAlert, .weatherForecast, .weatherMetrics,
             .safetyIndicator, .treatmentConditions:
            return SDUIWeatherRenderer.render(component: component, context: context)

        // Equipment management components
        case .equipmentInspector, .equipmentSelector, .qrScanner, .digitalChecklist,
             .maintenanceScheduler, .calibrationTracker:
            // TODO: Re-implement equipment renderers
            return AnyView(Text("Equipment features temporarily disabled"))

        // Advanced placeholder components
        case .section, .tabView, .navigationLink, .alert, .actionSheet:
            return renderAdvancedComponent(component: component, context: context)
        case .forEach, .mapView, .webView, .chart, .gauge:
            return SDUIErrorHandler.createErrorView(
                message: "Component '\(component.type.rawValue)' requires additional implementation",
                component: component
            )
        }
    }

    /// Renders advanced components that need special handling
    private static func renderAdvancedComponent(component: SDUIComponent, context: SDUIContext) -> AnyView {
        switch component.type {
        case .section:
            return renderSection(component: component, context: context)
        case .tabView:
            return renderTabView(component: component, context: context)
        case .navigationLink:
            return renderNavigationLink(component: component, context: context)
        case .alert:
            return renderAlert(component: component, context: context)
        case .actionSheet:
            return renderActionSheet(component: component, context: context)
        default:
            return AnyView(EmptyView())
        }
    }

    private static func renderSection(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let children = component.children ?? []
        let sectionView: AnyView

        if let title = component.title {
            sectionView = AnyView(Section(header: Text(title)) {
                ForEach(children, id: \.id) { child in
                    SDUIScreenRenderer.render(component: child, context: context)
                }
            })
        } else {
            sectionView = AnyView(Section {
                ForEach(children, id: \.id) { child in
                    SDUIScreenRenderer.render(component: child, context: context)
                }
            })
        }

        return SDUIStyleApplicator.apply(styling: component, to: sectionView, job: context.currentJob)
    }

    private static func renderTabView(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let children = component.children ?? []
        let tabView = AnyView(TabView {
            ForEach(children, id: \.id) { child in
                SDUIScreenRenderer.render(component: child, context: context)
            }
        })

        return SDUIStyleApplicator.apply(styling: component, to: tabView, job: context.currentJob)
    }

    private static func renderNavigationLink(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let destination = component.destination else {
            return SDUIErrorHandler.createErrorView(message: "NavigationLink missing destination", component: component)
        }

        let label = component.label ?? "Navigate"
        let navLink = AnyView(NavigationLink(destination: Text("Screen: \(destination)")) {
            Text(label)
        })

        return SDUIStyleApplicator.apply(styling: component, to: navLink, job: context.currentJob)
    }

    private static func renderAlert(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.isPresented else {
            return SDUIErrorHandler.createErrorView(message: "Alert missing isPresented key", component: component)
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let binding = Binding<Bool>(
            get: { context.routeViewModel.presentationStates[contextKey] ?? false },
            set: { context.routeViewModel.setPresentationState(forKey: contextKey, value: $0) }
        )

        let title = component.title ?? "Alert"
        let message = component.message ?? ""

        return AnyView(EmptyView().alert(title, isPresented: binding) {
            Button("OK") { }
        } message: {
            Text(message)
        })
    }

    private static func renderActionSheet(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.isPresented else {
            return SDUIErrorHandler.createErrorView(message: "ActionSheet missing isPresented key", component: component)
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let binding = Binding<Bool>(
            get: { context.routeViewModel.presentationStates[contextKey] ?? false },
            set: { context.routeViewModel.setPresentationState(forKey: contextKey, value: $0) }
        )

        let title = component.title ?? "Actions"

        return AnyView(EmptyView().confirmationDialog(title, isPresented: binding) {
            Button("Option 1") { }
            Button("Option 2") { }
            Button("Cancel", role: .cancel) { }
        })
    }

    private static func renderImage(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let imageView: AnyView
        if let imageName = component.imageName {
            imageView = AnyView(Image(imageName)
                                .resizable()
                                .scaledToFit())
        } else if let urlString = component.url, let url = URL(string: urlString) {
            imageView = AnyView(AsyncImage(url: url) { phase in
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
            imageView = AnyView(EmptyView())
        }
        return SDUIStyleApplicator.apply(styling: component, to: imageView, job: context.currentJob)
    }

    private static func renderList(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let itemTemplate = component.itemView else {
            return SDUIErrorHandler.createErrorView(message: "List missing item template", component: component)
        }

        let listView = List {
            ForEach(context.jobs) { job in
                let jobContext = context.withCurrentJob(job)
                SDUIScreenRenderer.render(component: itemTemplate, context: jobContext)
            }
            .onMove { indices, newOffset in
                context.routeViewModel.moveJob(from: indices, to: newOffset)
            }
        }

        let styledView = SDUIStyleApplicator.apply(styling: component, to: AnyView(listView), job: context.currentJob)
        return SDUIAnimationApplicator.apply(animation: component, to: styledView)
    }

    private static func renderConditional(component: SDUIComponent, context: SDUIContext) -> AnyView {
        if let key = component.conditionKey, let job = context.currentJob {
            if let value = SDUIDataResolver.valueForKey(key: key, job: job), !value.isEmpty {
                let children = component.children ?? []
                let spacing: CGFloat? = component.spacing.map { CGFloat($0) }
                let stack = AnyView(VStack(alignment: .leading, spacing: spacing) {
                    ForEach(children, id: \.id) { child in
                        SDUIScreenRenderer.render(component: child, context: context)
                    }
                })
                let styledView = SDUIStyleApplicator.apply(styling: component, to: stack, job: context.currentJob)
                return SDUIAnimationApplicator.apply(animation: component, to: styledView)
            }
        }
        return AnyView(EmptyView())
    }
    // Note: All utility functions moved to modular architecture files:
    // - SDUIDataResolver: Data binding and resolution
    // - SDUIStyleResolver: Font, color, and style resolution
    // - SDUIStyleApplicator: Comprehensive styling application
    // - SDUIAnimationApplicator: Animation and transition handling
    // - SDUIErrorHandler: Error management and validation
    // - SDUIVersionManager: Version compatibility management
    // - Component-specific renderers: Modular rendering logic
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