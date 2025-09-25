import Foundation
import SwiftUI

/// Simplified performance optimizer for basic functionality
@MainActor
final class ProfilePerformanceOptimizer: ObservableObject {

    // MARK: - Basic Cache

    private let imageCache = NSCache<NSString, UIImage>()

    init() {
        setupImageCache()
    }

    // MARK: - Cache Management

    private func setupImageCache() {
        imageCache.countLimit = 50  // Max 50 images
        imageCache.totalCostLimit = 100 * 1024 * 1024  // 100MB limit
    }

    func cacheImage(_ image: UIImage, forKey key: String) {
        imageCache.setObject(image, forKey: key as NSString)
    }

    func getCachedImage(forKey key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }

    func clearImageCache() {
        imageCache.removeAllObjects()
    }
}