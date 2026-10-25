import Foundation

struct ServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

actor GitHubService {
    struct Tree: Decodable {
        struct Entry: Decodable { let path: String; let type: String }
        let sha: String
        let truncated: Bool
        let tree: [Entry]
    }
    private func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("OmWallpapers/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 40
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ServiceError(message: "服务器没有返回有效响应") }
        guard response.statusCode == 200 else {
            if response.statusCode == 403 || response.statusCode == 429 {
                let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Double.init).map { Date(timeIntervalSince1970: $0).formatted(date: .omitted, time: .shortened) }
                throw ServiceError(message: "GitHub 暂时限制请求。\(reset.map { "请在 \($0) 后重试。" } ?? "请稍后重试。")已同步的壁纸仍可使用。")
            }
            throw ServiceError(message: "请求失败（HTTP \(response.statusCode)）：\(url.host ?? "")")
        }
        return data
    }
    func wallpapers(in source: ThemeSource) async throws -> [Wallpaper] {
        let url = URL(string: "https://api.github.com/repos/\(source.repository)/git/trees/HEAD?recursive=1")!
        let tree = try JSONDecoder().decode(Tree.self, from: await data(from: url))
        guard !tree.truncated else { throw ServiceError(message: "仓库目录过大，GitHub 返回了不完整的目录：\(source.repository)") }
        return tree.tree.filter { $0.type == "blob" && Wallpaper.isBackground($0.path) }
            .map { Wallpaper(repository: source.repository, path: $0.path, revision: tree.sha) }
            .sorted { $0.path < $1.path }
    }
    func communitySources() async throws -> [ThemeSource] {
        let html = String(decoding: try await data(from: URL(string: "https://omarchy.org/themes/")!), as: UTF8.self)
        let regex = try NSRegularExpression(pattern: #"href=["']https://github\.com/([A-Za-z0-9_-]+/[A-Za-z0-9_.-]+)/?["']"#)
        let sources = regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match -> ThemeSource? in
            guard let range = Range(match.range(at: 1), in: html) else { return nil }
            return ThemeSource.parse(String(html[range]))
        }.filter { $0.id != "omacom/omarchy" && $0.id != "basecamp/omarchy" }
        guard !sources.isEmpty else { throw ServiceError(message: "没有找到社区主题，目录格式可能发生了变化。你仍可手动添加仓库。") }
        return Array(Set(sources)).sorted { $0.name < $1.name }
    }
}
