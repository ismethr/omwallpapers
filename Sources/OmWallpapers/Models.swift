import Foundation

struct ThemeSource: Codable, Identifiable, Hashable {
    var repository: String
    var id: String { repository.lowercased() }
    var name: String {
        repository.split(separator: "/").last.map(String.init)?
            .replacingOccurrences(of: "omarchy-", with: "")
            .replacingOccurrences(of: "-theme", with: "")
            .replacingOccurrences(of: "-", with: " ").capitalized ?? repository
    }
    static let seeds = [ThemeSource(repository: "dhh/omarchy-jade-horse-theme"), ThemeSource(repository: "omacom/omarchy")]

    static func parse(_ input: String) -> ThemeSource? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("https://") {
            guard let url = URL(string: value), url.host?.lowercased() == "github.com",
                  url.query == nil, url.fragment == nil else { return nil }
            value = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if value.hasSuffix(".git") { value.removeLast(4) }
        guard value.range(of: #"^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil,
              !value.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else { return nil }
        return ThemeSource(repository: value)
    }
}

struct Wallpaper: Codable, Identifiable, Hashable {
    var repository: String
    var path: String
    var revision: String
    var id: String { "\(repository.lowercased())/\(path)" }
    var name: String { URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ") }
    var theme: String {
        let parts = path.split(separator: "/")
        if let index = parts.firstIndex(of: "themes"), index + 1 < parts.count {
            return String(parts[index + 1]).replacingOccurrences(of: "-", with: " ").capitalized
        }
        return ThemeSource(repository: repository).name
    }
    var sourceURL: URL { URL(string: "https://github.com/\(repository)")! }
    var imageURL: URL {
        let encoded = path.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "?#%")))! }.joined(separator: "/")
        return URL(string: "https://raw.githubusercontent.com/\(repository)/\(revision)/\(encoded)")!
    }
    static func isBackground(_ path: String) -> Bool {
        let parts = path.lowercased().split(separator: "/")
        return parts.contains("backgrounds") && ["jpg", "jpeg", "png", "heic", "webp"].contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }
}

struct LibrarySnapshot: Codable {
    var sources: [ThemeSource] = ThemeSource.seeds
    var wallpapers: [Wallpaper] = []
    var favorites: Set<String> = []
    var synced: [String: Date] = [:]
    var currentID: String?
}
