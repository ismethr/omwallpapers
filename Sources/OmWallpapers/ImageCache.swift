import AppKit
import CryptoKit
import ImageIO

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

    func thumbnail(for wallpaper: Wallpaper) async throws -> NSImage {
        let url = try await localURL(for: wallpaper)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 760,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { throw ServiceError(message: "无法读取缩略图") }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}
