import Foundation
import SwiftUI
import os.log

/// Manages bundle size optimization through on-demand resources and lazy loading
final class BundleOptimizer {
    static let shared = BundleOptimizer()

    private let logger = Logger(subsystem: "com.pestgenie.bundle", category: "optimization")

    // On-demand resource tags
    enum ResourceTag: String, CaseIterable {
        case sampleData = "sample-data"
        case tutorialAssets = "tutorial-assets"
        case advancedFeatures = "advanced-features"
        case reportingTools = "reporting-tools"
        case offlineMapData = "offline-maps"

        var downloadPriority: Double {
            switch self {
            case .sampleData: return 0.1
            case .tutorialAssets: return 0.3
            case .advancedFeatures: return 0.5
            case .reportingTools: return 0.7
            case .offlineMapData: return 0.9
            }
        }
    }

    private var downloadedResources: Set<ResourceTag> = []
    private var downloadTasks: [ResourceTag: Task<Void, Error>] = [:]

    private init() {
        // Check what resources are already available
        checkAvailableResources()
    }

    // MARK: - Resource Management

    func downloadResource(_ tag: ResourceTag) async throws {
        guard !downloadedResources.contains(tag) else {
            logger.info("Resource \(tag.rawValue) already downloaded")
            return
        }

        // Cancel existing download task if running
        downloadTasks[tag]?.cancel()

        let task = Task {
            logger.info("Starting download for resource: \(tag.rawValue)")

            let request = NSBundleResourceRequest(tags: [tag.rawValue])
            request.loadingPriority = tag.downloadPriority

            do {
                try await request.beginAccessingResources()
                await MainActor.run {
                    downloadedResources.insert(tag)
                    logger.info("Successfully downloaded resource: \(tag.rawValue)")
                }
            } catch {
                logger.error("Failed to download resource \(tag.rawValue): \(error.localizedDescription)")
                throw error
            }
        }

        downloadTasks[tag] = task
        try await task.value
    }

    func downloadResourceIfNeeded(_ tag: ResourceTag) async {
        guard !downloadedResources.contains(tag) else { return }

        do {
            try await downloadResource(tag)
        } catch {
            logger.error("Failed to download resource \(tag.rawValue): \(error.localizedDescription)")
        }
    }

    func isResourceAvailable(_ tag: ResourceTag) -> Bool {
        return downloadedResources.contains(tag)
    }

    func releaseResource(_ tag: ResourceTag) {
        guard downloadedResources.contains(tag) else { return }

        let request = NSBundleResourceRequest(tags: [tag.rawValue])
        request.endAccessingResources()

        downloadedResources.remove(tag)
        logger.info("Released resource: \(tag.rawValue)")
    }

    private func checkAvailableResources() {
        for tag in ResourceTag.allCases {
            let request = NSBundleResourceRequest(tags: [tag.rawValue])
            request.conditionallyBeginAccessingResources { available in
                if available {
                    self.downloadedResources.insert(tag)
                    self.logger.info("Resource \(tag.rawValue) is available")
                }
            }
        }
    }

    // MARK: - Bundle Analysis

    func analyzeBundleSize() -> BundleAnalysis {
        let mainBundle = Bundle.main
        let bundleURL = mainBundle.bundleURL
        let bundleSize = directorySize(at: bundleURL)

        var analysis = BundleAnalysis(totalSize: bundleSize)

        // Analyze specific directories
        if let frameworksURL = mainBundle.privateFrameworksURL {
            analysis.frameworksSize = directorySize(at: frameworksURL)
        }

        // Analyze resources
        let resourcesURL = bundleURL.appendingPathComponent("Resources")
        if FileManager.default.fileExists(atPath: resourcesURL.path) {
            analysis.resourcesSize = directorySize(at: resourcesURL)
        }

        return analysis
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                logger.error("Error calculating size for \(fileURL.path): \(error.localizedDescription)")
            }
        }

        return totalSize
    }

    // MARK: - Cleanup

    func performCleanup() {
        // Release unused resources when memory pressure is high
        let lowPriorityResources: [ResourceTag] = [.sampleData, .tutorialAssets]

        for resource in lowPriorityResources {
            if downloadedResources.contains(resource) {
                releaseResource(resource)
            }
        }
    }
}

// MARK: - Bundle Analysis

struct BundleAnalysis {
    let totalSize: Int64
    var frameworksSize: Int64 = 0
    var resourcesSize: Int64 = 0
    var executableSize: Int64 = 0

    var totalSizeMB: Double {
        Double(totalSize) / 1024 / 1024
    }

    var frameworksSizeMB: Double {
        Double(frameworksSize) / 1024 / 1024
    }

    var resourcesSizeMB: Double {
        Double(resourcesSize) / 1024 / 1024
    }

    var breakdown: String {
        """
        Total Bundle Size: \(String(format: "%.1f", totalSizeMB)) MB
        Frameworks: \(String(format: "%.1f", frameworksSizeMB)) MB
        Resources: \(String(format: "%.1f", resourcesSizeMB)) MB
        """
    }
}

// MARK: - On-Demand Resource Views

struct OnDemandResourceView<Content: View>: View {
    let resourceTag: BundleOptimizer.ResourceTag
    let content: () -> Content

    @State private var isLoading = false
    @State private var isLoaded = false
    @State private var error: Error?

    var body: some View {
        Group {
            if isLoaded {
                content()
            } else if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Button("Load \(resourceTag.rawValue.replacingOccurrences(of: "-", with: " ").capitalized)") {
                    loadResource()
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            if BundleOptimizer.shared.isResourceAvailable(resourceTag) {
                isLoaded = true
            }
        }
        .alert("Error Loading Resource", isPresented: .constant(error != nil)) {
            Button("Retry") {
                loadResource()
            }
            Button("Cancel", role: .cancel) {
                error = nil
            }
        } message: {
            Text(error?.localizedDescription ?? "Unknown error")
        }
    }

    private func loadResource() {
        isLoading = true
        error = nil

        Task {
            do {
                try await BundleOptimizer.shared.downloadResource(resourceTag)
                await MainActor.run {
                    isLoading = false
                    isLoaded = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    self.error = error
                }
            }
        }
    }
}

// MARK: - Lazy Image Loading

struct LazyAsyncImage: View {
    let url: URL?
    let placeholder: () -> AnyView

    @State private var isLoaded = false

    init(url: URL?, @ViewBuilder placeholder: @escaping () -> some View) {
        self.url = url
        self.placeholder = { AnyView(placeholder()) }
    }

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure(_):
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    case .empty:
                        placeholder()
                    @unknown default:
                        placeholder()
                    }
                }
            } else {
                placeholder()
            }
        }
    }
}

// MARK: - Code Splitting Support

/// Helper for implementing code splitting patterns
struct FeatureModuleLoader<Content: View>: View {
    let moduleName: String
    let content: () -> Content

    @State private var isModuleLoaded = false

    var body: some View {
        Group {
            if isModuleLoaded {
                content()
            } else {
                ProgressView("Loading \(moduleName)...")
                    .onAppear {
                        loadModule()
                    }
            }
        }
    }

    private func loadModule() {
        // Simulate module loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isModuleLoaded = true
        }
    }
}

// MARK: - Asset Optimization

enum AssetQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var compressionQuality: CGFloat {
        switch self {
        case .low: return 0.3
        case .medium: return 0.7
        case .high: return 0.9
        }
    }

    var maxDimension: CGFloat {
        switch self {
        case .low: return 480
        case .medium: return 720
        case .high: return 1080
        }
    }
}

struct AdaptiveImageView: View {
    let imageName: String
    let quality: AssetQuality

    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        let effectiveQuality = networkMonitor.shouldLimitDataUsage ? .low : quality
        let imageSuffix = effectiveQuality == .high ? "@2x" : ""
        let finalImageName = "\(imageName)\(imageSuffix)"

        Image(finalImageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

// MARK: - Development Tools

#if DEBUG
struct BundleOptimizerDebugView: View {
    @State private var bundleAnalysis: BundleAnalysis?
    @State private var downloadedResources: Set<BundleOptimizer.ResourceTag> = []

    var body: some View {
        NavigationStack {
            List {
                Section("Bundle Analysis") {
                    if let analysis = bundleAnalysis {
                        Text(analysis.breakdown)
                            .font(.monospaced(.caption)())
                    } else {
                        Button("Analyze Bundle") {
                            bundleAnalysis = BundleOptimizer.shared.analyzeBundleSize()
                        }
                    }
                }

                Section("On-Demand Resources") {
                    ForEach(BundleOptimizer.ResourceTag.allCases, id: \.rawValue) { tag in
                        HStack {
                            Text(tag.rawValue)
                            Spacer()
                            if BundleOptimizer.shared.isResourceAvailable(tag) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Button("Download") {
                                    Task {
                                        try? await BundleOptimizer.shared.downloadResource(tag)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bundle Optimizer")
        }
    }
}
#endif