import Testing
import Foundation
@testable import OmWallpapers

struct ModelsTests {
    @Test func testRepositoryInputs() {
        #expect(ThemeSource.parse(" https://github.com/dhh/omarchy-jade-horse-theme.git ")?.repository == "dhh/omarchy-jade-horse-theme")
        #expect(ThemeSource.parse("dhh/omarchy-jade-horse-theme")?.id == "dhh/omarchy-jade-horse-theme")
        for invalid in ["https://github.com.evil.test/dhh/theme", "https://github.com/dhh/theme/tree/main", "https://github.com/dhh/theme?token=secret", "../theme", "file:///tmp/theme", "https://example.com/a/b"] {
            #expect(ThemeSource.parse(invalid) == nil, "\(invalid)")
        }
    }
    @Test func testOnlyBackgroundImagesAreCollected() {
        for path in ["backgrounds/horse.png", "themes/tokyo-night/backgrounds/night.JPG", "backgrounds/nested/mountain.heic"] {
            #expect(Wallpaper.isBackground(path), "\(path)")
        }
        for path in ["preview.png", "not-backgrounds/foo.jpg", "backgrounds/README.md", "icons/icon.png"] {
            #expect(!Wallpaper.isBackground(path), "\(path)")
        }
    }
    @Test func testThemeNameAndImmutableURL() {
        let wallpaper = Wallpaper(repository: "omacom/omarchy", path: "themes/tokyo-night/backgrounds/01 night#100%.png", revision: "abcdef")
        #expect(wallpaper.theme == "Tokyo Night")
        #expect(wallpaper.imageURL.absoluteString == "https://raw.githubusercontent.com/omacom/omarchy/abcdef/themes/tokyo-night/backgrounds/01%20night%23100%25.png")
        #expect(wallpaper.imageURL.fragment == nil)
        #expect(wallpaper.imageURL.query == nil)
    }
    @Test func testIdentitySurvivesRevisionUpdate() throws {
        let old = Wallpaper(repository: "dhh/theme", path: "backgrounds/a.png", revision: "old")
        let new = Wallpaper(repository: "dhh/theme", path: "backgrounds/a.png", revision: "new")
        #expect(old.id == new.id)
        #expect(old.imageURL != new.imageURL)
        var library = LibrarySnapshot()
        library.wallpapers = [old]
        library.favorites = [old.id]
        library.currentID = old.id
        library.synced = ["dhh/theme": Date(timeIntervalSince1970: 1234)]
        let decoded = try JSONDecoder().decode(LibrarySnapshot.self, from: JSONEncoder().encode(library))
        #expect(decoded.favorites == [new.id])
        #expect(decoded.currentID == new.id)
        #expect(decoded.synced == library.synced)
    }
}
