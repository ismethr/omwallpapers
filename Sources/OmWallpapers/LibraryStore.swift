import AppKit
import Combine
import ServiceManagement

@MainActor
final class LibraryStore: ObservableObject {
    @Published var snapshot = LibrarySnapshot()
    @Published var query = ""
    @Published var selectedTheme = "全部主题"
    @Published var favoritesOnly = false
    @Published var isSyncing = false
    @Published var isApplying = false
    @Published var status = "从 Omarchy，来到你的 Mac。"
    @Published var error: String?
    @Published var allDisplays: Bool { didSet { UserDefaults.standard.set(allDisplays, forKey: "allDisplays") } }
    @Published var interval: Int { didSet { UserDefaults.standard.set(interval, forKey: "interval"); scheduleRotation() } }
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    private let api = GitHubService()
    private var timer: Timer?
    private var syncTask: Task<Void, Never>?
    private let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OmWallpapers/library.json")

    init() {
        allDisplays = UserDefaults.standard.object(forKey: "allDisplays") as? Bool ?? true
        interval = UserDefaults.standard.integer(forKey: "interval")
        do {
            if FileManager.default.fileExists(atPath: file.path) { snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: file)) }
        } catch { self.error = "本地目录无法读取：\(error.localizedDescription)" }
        scheduleRotation()
        if snapshot.wallpapers.isEmpty { sync(sources: ThemeSource.seeds) }
    }
    var themes: [String] { Array(Set(snapshot.wallpapers.map(\.theme))).sorted() }
    var visible: [Wallpaper] {
        snapshot.wallpapers.filter {
            (selectedTheme == "全部主题" || $0.theme == selectedTheme) &&
            (!favoritesOnly || snapshot.favorites.contains($0.id)) &&
            (query.isEmpty || "\($0.name) \($0.theme) \($0.repository)".localizedCaseInsensitiveContains(query))
        }
    }
    var current: Wallpaper? { snapshot.wallpapers.first { $0.id == snapshot.currentID } }
    func save() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: file, options: .atomic)
        } catch { self.error = "保存失败：\(error.localizedDescription)" }
    }
    func toggleFavorite(_ wallpaper: Wallpaper) {
        if snapshot.favorites.contains(wallpaper.id) { snapshot.favorites.remove(wallpaper.id) }
        else { snapshot.favorites.insert(wallpaper.id) }
        save()
    }
    func addSource(_ input: String) {
        guard let source = ThemeSource.parse(input) else { error = "请输入 GitHub 仓库地址或 owner/repository。"; return }
        if !snapshot.sources.contains(where: { $0.id == source.id }) { snapshot.sources.append(source); save() }
        sync(sources: [source], force: true)
    }
    func discover() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let sources = try await api.communitySources()
            for source in sources where !snapshot.sources.contains(where: { $0.id == source.id }) { snapshot.sources.append(source) }
            save()
            status = "已收录 \(snapshot.sources.count) 个仓库，点击「同步全部」获取壁纸。"
        } catch { self.error = error.localizedDescription }
    }
    func sync(sources: [ThemeSource]? = nil, force: Bool = false) {
        guard !isSyncing else { return }
        let sources = sources ?? snapshot.sources
        isSyncing = true
        error = nil
        syncTask = Task {
            defer { isSyncing = false; syncTask = nil }
            var failures: [String] = []
            for (index, source) in sources.enumerated() {
                if Task.isCancelled { status = "已暂停同步，可稍后继续。"; return }
                if !force, let date = snapshot.synced[source.id], Date().timeIntervalSince(date) < 86400 { continue }
                status = "同步 \(index + 1)/\(sources.count) · \(source.name)"
                do {
                    let wallpapers = try await api.wallpapers(in: source)
                    try Task.checkCancellation()
                    snapshot.wallpapers.removeAll { $0.repository.lowercased() == source.id }
                    snapshot.wallpapers.append(contentsOf: wallpapers)
                    snapshot.synced[source.id] = Date()
                    save()
                } catch is CancellationError { status = "已暂停同步。"; return }
                catch {
                    failures.append("\(source.repository)：\(error.localizedDescription)")
                    if error.localizedDescription.contains("限制请求") { break }
                }
            }
            status = "\(snapshot.wallpapers.count) 张壁纸 · \(snapshot.synced.count)/\(snapshot.sources.count) 个仓库已同步"
            if !failures.isEmpty { error = failures.joined(separator: "\n") }
        }
    }
    func cancelSync() { syncTask?.cancel() }
    func apply(_ wallpaper: Wallpaper) async {
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }
        do {
            let url = try await ImageCache.shared.localURL(for: wallpaper)
            let screens = allDisplays ? NSScreen.screens : Array(NSScreen.main.map { [$0] } ?? [])
            guard !screens.isEmpty else { throw ServiceError(message: "没有找到可用显示器") }
            for screen in screens {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, .allowClipping: true])
            }
            snapshot.currentID = wallpaper.id
            save()
            status = "已设置 · \(wallpaper.name)"
        } catch { self.error = error.localizedDescription }
    }
    func randomize() async {
        let pool = visible.filter { $0.id != snapshot.currentID }
        if let wallpaper = pool.randomElement() ?? visible.first { await apply(wallpaper) }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { status = "请在系统设置 → 通用 → 登录项中允许 OmWallpapers。" }
        } catch { self.error = "登录启动设置失败：\(error.localizedDescription)"; launchAtLogin = SMAppService.mainApp.status == .enabled }
    }
    private func scheduleRotation() {
        timer?.invalidate()
        guard interval > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Double(interval), repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.randomize() }
        }
    }
}
