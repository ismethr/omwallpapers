import AppKit
import CryptoKit
import ImageIO

struct PixelDimensions: Equatable {
    let width: Int
    let height: Int
    var formatted: String { "\(width) × \(height)" }
}

struct WallpaperPreview {
    let image: NSImage
    let dimensions: PixelDimensions?
}

actor ImageCache {
    static let shared = ImageCache()
    private var pending: [String: Task<URL, Error>] = [:]
    private let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OmWallpapers/Images", isDirectory: true)

    func localURL(for wallpaper: Wallpaper) async throws -> URL {
        let key = SHA256.hash(data: Data(wallpaper.imageURL.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let target = root.appendingPathComponent(key).appendingPathExtension(URL(fileURLWithPath: wallpaper.path).pathExtension)
        if FileManager.default.fileExists(atPath: target.path) { return target }
        if let task = pending[key] { return try await task.value }
        let task = Task<URL, Error> {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var request = URLRequest(url: wallpaper.imageURL)
            request.timeoutInterval = 90
            let (temporary, response) = try await URLSession.shared.download(for: request)
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  CGImageSourceCreateWithURL(temporary as CFURL, nil) != nil else {
                throw ServiceError(message: "图片无法下载或格式不受支持：\(wallpaper.name)")
            }
            try FileManager.default.moveItem(at: temporary, to: target)
            return target
        }
        pending[key] = task
        defer { pending[key] = nil }
        return try await task.value
    }

    func thumbnail(for wallpaper: Wallpaper) async throws -> WallpaperPreview {
        let url = try await localURL(for: wallpaper)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 760,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { throw ServiceError(message: "无法读取缩略图") }
        return WallpaperPreview(image: NSImage(cgImage: cgImage, size: .zero), dimensions: Self.dimensions(of: source))
    }

    // Read original pixel dimensions, independent of thumbnail size and Retina scale.
    nonisolated static func dimensions(of source: CGImageSource) -> PixelDimensions? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0 else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        // Match the displayed image when EXIF rotates the stored pixels.
        return (5...8).contains(orientation)
            ? PixelDimensions(width: height, height: width)
            : PixelDimensions(width: width, height: height)
    }

}
