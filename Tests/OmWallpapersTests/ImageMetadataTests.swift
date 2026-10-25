import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import OmWallpapers

struct ImageMetadataTests {
    @Test func originalPixelDimensionsRespectOrientation() throws {
        let context = try #require(CGContext(data: nil, width: 2048, height: 1152,
                                            bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let image = try #require(context.makeImage())
        for (orientation, expected) in [(1, PixelDimensions(width: 2048, height: 1152)),
                                        (6, PixelDimensions(width: 1152, height: 2048))] {
            let data = NSMutableData()
            let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
            #expect(CGImageDestinationFinalize(destination))
            let source = try #require(CGImageSourceCreateWithData(data, nil))
            #expect(ImageCache.dimensions(of: source) == expected)
            #expect(ImageCache.dimensions(of: source)?.formatted == expected.formatted)
        }
    }
}
