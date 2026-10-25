import SwiftUI
import AppKit

private enum AppPalette {
    static let background = Color(red: 20 / 255, green: 32 / 255, blue: 27 / 255)
    static let surface = Color(red: 35 / 255, green: 54 / 255, blue: 45 / 255)
    static let text = Color(red: 244 / 255, green: 247 / 255, blue: 245 / 255)
    static let secondary = Color(red: 184 / 255, green: 200 / 255, blue: 190 / 255)
    static let border = Color(red: 110 / 255, green: 139 / 255, blue: 122 / 255)
    static let accent = Color(red: 168 / 255, green: 232 / 255, blue: 197 / 255)
    static let favorite = Color(red: 255 / 255, green: 158 / 255, blue: 190 / 255)
}

@main
struct OmWallpapersApp: App {
    @StateObject private var store = LibraryStore()
    var body: some Scene {
        MenuBarExtra {
            LibraryView(store: store)
        } label: {
            Image(systemName: "mountain.2.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

struct LibraryView: View {
    @ObservedObject var store: LibraryStore
    @State private var showingSources = false
    @State private var sourceInput = ""
    private let accent = AppPalette.accent

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("OM / WALLPAPERS").font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(accent)
                    Text("给桌面，一点新风景。 ").font(.system(size: 23, weight: .semibold))
                }
                Spacer()
                Menu {
                    Toggle("所有显示器", isOn: $store.allDisplays)
                    Toggle("登录时启动", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLogin($0) }))
                    Picker("自动切换", selection: $store.interval) {
                        Text("关闭").tag(0)
                        Text("每 15 分钟").tag(900)
                        Text("每小时").tag(3600)
                        Text("每天（应用运行期间）").tag(86400)
                    }
                    Divider()
                    Button("打开壁纸缓存") {
                        NSWorkspace.shared.open(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OmWallpapers"))
                    }
                    Button("退出 OmWallpapers") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "slider.horizontal.3").font(.title3).padding(8) }
                .menuStyle(.borderlessButton).fixedSize()
            }.padding(22)

            if let current = store.current {
                HStack(spacing: 12) {
                    WallpaperImage(wallpaper: current).frame(width: 64, height: 40).clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("正在使用").font(.system(size: 12, weight: .medium)).foregroundStyle(accent)
                        Text(current.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                }.padding(12).background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 22).padding(.bottom, 16)
            }

            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppPalette.secondary)
                    TextField("", text: $store.query, prompt: Text("搜索壁纸、主题、作者").foregroundColor(AppPalette.secondary)).textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(AppPalette.text)
                }.padding(10).background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(AppPalette.border, lineWidth: 1))
                Button { store.favoritesOnly.toggle() } label: {
                    Image(systemName: store.favoritesOnly ? "heart.fill" : "heart").foregroundStyle(store.favoritesOnly ? accent : AppPalette.secondary).padding(10)
                }.buttonStyle(.plain).background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(AppPalette.border, lineWidth: 1)).help("仅显示收藏")
            }.padding(.horizontal, 22)

            HStack {
                Picker("主题", selection: $store.selectedTheme) {
                    Text("全部主题").tag("全部主题")
                    ForEach(store.themes, id: \.self) { Text($0).tag($0) }
                }.labelsHidden().frame(maxWidth: 250)
                Spacer()
                Text("\(store.visible.count) 张").font(.system(size: 12, design: .monospaced)).foregroundStyle(AppPalette.secondary)
            }.padding(.horizontal, 22).padding(.vertical, 12)

            ScrollView {
                if store.visible.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: store.isSyncing ? "arrow.triangle.2.circlepath" : "photo.on.rectangle.angled").font(.system(size: 34)).foregroundStyle(accent)
                        Text(store.isSyncing ? "正在收集第一片风景…" : "这里还没有壁纸").font(.headline)
                        Text(store.isSyncing ? "正在读取主题仓库，请稍候。" : "调整筛选，或在来源中添加一个主题。")
                            .font(.caption).foregroundStyle(AppPalette.secondary)
                        if !store.isSyncing && store.snapshot.wallpapers.isEmpty {
                            Button("重试同步") { store.sync(force: true) }
                        }
                    }.frame(maxWidth: .infinity).padding(.vertical, 80)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(store.visible) { wallpaper in
                            WallpaperCard(wallpaper: wallpaper, store: store)
                        }
                    }.padding(.horizontal, 22).padding(.bottom, 16)
                }
            }.frame(height: 340)

            if let error = store.error {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    ScrollView { Text(error).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 65)
                    Button { store.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }.padding(12).background(.orange.opacity(0.08)).padding(.horizontal, 22).padding(.bottom, 8)
            }

            Rectangle().fill(AppPalette.border).frame(height: 1)
            HStack {
                Button { showingSources.toggle() } label: { Label("来源", systemImage: "square.stack.3d.up") }.buttonStyle(.plain)
                Spacer()
                if store.isSyncing { ProgressView().controlSize(.small) }
                Button {
                    Task { await store.randomize() }
                } label: {
                    Label(store.isApplying ? "正在设置…" : "换一张", systemImage: "shuffle").fontWeight(.semibold).padding(.horizontal, 15).padding(.vertical, 9)
                }.buttonStyle(.plain).background(accent, in: Capsule()).foregroundStyle(Color(red: 0.07, green: 0.15, blue: 0.12)).disabled(store.visible.isEmpty || store.isApplying)
            }.padding(.horizontal, 22).padding(.top, 14)
            Text(store.status).font(.system(size: 12)).foregroundStyle(AppPalette.secondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.top, 9).padding(.bottom, 16)
        }
        .frame(width: 490)
        .foregroundStyle(AppPalette.text)
        .tint(AppPalette.accent)
        .background(AppPalette.background)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .popover(isPresented: $showingSources) { sourcesView }
    }

    private var sourcesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("壁纸来源").font(.title2.bold())
                Spacer()
                Button("完成") { showingSources = false }
            }
            Text("读取仓库 backgrounds 文件夹中的图片，保留作者与原始来源链接。")
                .font(.caption).foregroundStyle(AppPalette.secondary)
            HStack {
                TextField("https://github.com/作者/主题.git", text: $sourceInput).textFieldStyle(.roundedBorder)
                Button("添加") { store.addSource(sourceInput); sourceInput = "" }.disabled(store.isSyncing || sourceInput.isEmpty)
            }
            HStack {
                Button("发现社区主题") { Task { await store.discover() } }.disabled(store.isSyncing)
                Button("同步全部") { store.sync() }.disabled(store.isSyncing)
                if store.isSyncing { Button("暂停") { store.cancelSync() } }
            }
            Text("\(store.snapshot.sources.count) 个仓库 · \(store.snapshot.synced.count) 个已同步").font(.caption).foregroundStyle(AppPalette.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(store.snapshot.sources) { source in
                        HStack {
                            Image(systemName: store.snapshot.synced[source.id] == nil ? "circle.dashed" : "checkmark.circle.fill").foregroundStyle(AppPalette.secondary)
                            VStack(alignment: .leading) {
                                Text(source.name).font(.system(size: 12, weight: .medium))
                                Link(source.repository, destination: URL(string: "https://github.com/\(source.repository)")!).font(.caption)
                            }
                            Spacer()
                            Button("刷新") { store.sync(sources: [source], force: true) }.disabled(store.isSyncing)
                        }
                    }
                }
            }.frame(height: 240)
            Text("同步可暂停并继续，24 小时内跳过已同步仓库。GitHub 公共接口有限流，失败时保留本地目录；图片按需下载。自动切换遵循当前筛选。")
                .font(.caption).foregroundStyle(AppPalette.secondary)
        }.padding(20).frame(width: 450)
        .foregroundStyle(AppPalette.text).tint(AppPalette.accent)
        .background(AppPalette.background).environment(\.colorScheme, .dark).preferredColorScheme(.dark)
    }
}

struct WallpaperCard: View {
    let wallpaper: Wallpaper
    @ObservedObject var store: LibraryStore
    @State private var hovered = false
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button { Task { await store.apply(wallpaper) } } label: {
                WallpaperImage(wallpaper: wallpaper)
                    .frame(height: 122).frame(maxWidth: .infinity).clipped()
                    .overlay(alignment: .bottomLeading) {
                        if hovered { Label("设为壁纸", systemImage: "desktopcomputer").font(.caption.bold()).padding(8).foregroundStyle(.white).background(.black.opacity(0.85), in: Capsule()).padding(8) }
                    }
                    .overlay(alignment: .topTrailing) {
                        if store.snapshot.currentID == wallpaper.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white, .green).padding(9) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).disabled(store.isApplying).help("点击设为桌面壁纸")
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(wallpaper.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(wallpaper.theme).font(.system(size: 12)).foregroundStyle(AppPalette.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Button { store.toggleFavorite(wallpaper) } label: {
                    Image(systemName: store.snapshot.favorites.contains(wallpaper.id) ? "heart.fill" : "heart").foregroundStyle(store.snapshot.favorites.contains(wallpaper.id) ? AppPalette.favorite : AppPalette.secondary)
                }.buttonStyle(.plain).help("收藏壁纸")
            }
        }.foregroundStyle(AppPalette.text).onHover { hovered = $0 }
        .contextMenu {
            Button("设为壁纸") { Task { await store.apply(wallpaper) } }.disabled(store.isApplying)
            Button("查看原始仓库与许可") { NSWorkspace.shared.open(wallpaper.sourceURL) }
            Button("在 Finder 中显示") {
                Task {
                    do { let url = try await ImageCache.shared.localURL(for: wallpaper); NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    catch { store.error = error.localizedDescription }
                }
            }
        }
    }
}

struct WallpaperImage: View {
    let wallpaper: Wallpaper
    @State private var image: NSImage?
    @State private var failed = false
    @State private var attempt = 0
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppPalette.surface
                if let image {
                    Image(nsImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else if failed {
                    Button { attempt += 1 } label: { Label("重试图片", systemImage: "arrow.clockwise").font(.caption) }.buttonStyle(.plain)
                } else { ProgressView().controlSize(.small) }
            }
        }
        .task(id: "\(wallpaper.imageURL)-\(attempt)") {
            failed = false
            do { image = try await ImageCache.shared.thumbnail(for: wallpaper) }
            catch { failed = true }
        }
    }
}
