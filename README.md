# OmWallpapers

原生 macOS 菜单栏壁纸应用。把 Omarchy 主题仓库中的 `backgrounds/` 收集到 Mac 上，像 Unsplash Wallpapers 一样从状态栏浏览并切换桌面。

## 下载

前往 [Releases](https://github.com/ismethr/omwallpapers/releases) 下载预览版。
当前 `OmWallpapers-0.1.0-macos-x86_64.zip` 为 Intel 构建，要求 macOS 14+。
Apple Silicon 用户可从源码本机构建；本次未提供原生 Apple Silicon 二进制。

下载后解压，把 `OmWallpapers.app` 拖入「应用程序」。当前采用 ad-hoc 签名，尚未经过 Apple 公证；如系统拦截，可在系统设置「隐私与安全性」中允许打开。

## 界面

采用明确的浅色正文与深绿背景，辅助文字、搜索框和控件边界单独配色。正文对背景对比度约 15.5:1，辅助文字对卡片约 7.4:1；列表标题、主题名和状态文字加大字号。

## 运行

需要 macOS 14 或更新版本，以及支持 Swift 6 的 Xcode Command Line Tools。

```sh
./scripts/build-app.sh
open dist/OmWallpapers.app
```

构建产物是当前 Mac 架构的 `.app`，采用本地 ad-hoc 签名。可以将它拖入「应用程序」后使用。对外分发还需要 Developer ID 签名、公证，以及按目标机型制作 Intel / Apple Silicon 或 Universal 构建。登录启动应在应用放入固定位置后启用。

应用只显示在菜单栏，图标是山峰。打开后点击图片设为壁纸，右键可以查看原始仓库或在 Finder 显示下载的图片。首次打开会同步目录，不会自动更换壁纸。

## 功能

- 默认同步 `dhh/omarchy-jade-horse-theme` 和 `omacom/omarchy` 的内置主题壁纸。
- 「来源 → 发现社区主题」读取 https://omarchy.org/themes/ 的 GitHub 仓库链接；「同步全部」读取已收录仓库里的壁纸。
- 支持粘贴 GitHub HTTPS 仓库地址（包含 `.git` 也可以）或 `owner/repository`。
- 搜索壁纸、主题或作者；按主题筛选；收藏；随机更换。
- 所有显示器一起换，或只换主显示器。
- 每 15 分钟、每小时、每天自动切换，按当前筛选与收藏条件选择。
- 登录启动；本地目录和收藏持久化；已下载图片离线可用。
- 图片使用 Git commit 固定版本，仓库更新后重新下载对应版本，收藏保持有效。

## 同步范围与限制

“全部”指已收录的仓库，初始种子加上官方社区目录及手动来源；不保证覆盖整个 GitHub 上所有主题。社区目录可能变更，仓库也可能删除或不包含 `backgrounds/`。

每个仓库使用一次 GitHub Git Trees API 请求，读取任意层级 `backgrounds/` 下的 JPG、PNG、HEIC、WebP 图片；不会执行仓库中的脚本。使用公共未登录 API，GitHub 通常限制每 IP 每小时 60 次请求（以响应为准）。遇到限流会停止，并显示服务端提供的重试时间；下次同步会跳过 24 小时内已成功同步的仓库，逐步完成大目录。单个来源的「刷新」会强制重新同步。下载图片不占 Git Trees API 配额。

图片按需下载，显示缩略图前会缓存原图，磁盘占用随浏览增加。目录、收藏和原图保存在 `~/Library/Application Support/OmWallpapers/`。图像支持由当前 macOS 的 ImageIO 决定，失败可点击重试。

自动切换需要应用持续运行；系统休眠期间不会唤醒机器。macOS 的其他 Spaces、动态壁纸和独立管理的桌面可能需要在对应空间中重新设置；不设置锁屏图片。随机切换遵循当前搜索、主题和收藏筛选。

壁纸从原始仓库按需下载，不随应用分发；使用与传播须遵循各仓库及图像作者许可。每张卡片右键可查看来源。

## 开发与验证

```sh
swift build
./scripts/test.sh
```

如构建环境限制默认模块缓存目录写入，可使用：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache" \
./scripts/test.sh
```

项目采用 SwiftUI `MenuBarExtra`、AppKit `NSWorkspace.setDesktopImageURL`、ServiceManagement 登录项和 ImageIO 缩略图，不依赖第三方包。

## 本次验证（2026-10-25）

- Debug / Release 编译通过，`.app` 的 plist 与 ad-hoc 签名校验通过。
- 实际启动成功，持久化目录中有 101 张壁纸（Jade Horse 3 张、内置主题 98 张），未设置当前壁纸。
- 官方社区网页解析到约 219 个仓库链接，目录会随上游更新变化。
- 4 项 Swift Testing 测试通过：仓库输入校验、图片范围筛选、特殊字符 URL 和 commit 固定、版本更新后的收藏与持久化。
- 设置桌面、多显示器、自动轮换和登录启动尚未完成交互验收；当前为预览版。
