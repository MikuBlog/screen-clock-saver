//
//  SaverInstaller.swift
//  把内置的 ScreenClock.saver 安装到当前用户的屏保目录，并拉起系统设置
//

import AppKit

enum SaverInstaller {
    static let saverFileName = "ScreenClock.saver"

    /// App 包内自带的屏保（Copy Files 阶段嵌入）
    static var embeddedSaverURL: URL? {
        Bundle.main.url(forResource: "ScreenClock", withExtension: "saver")
    }

    /// 当前用户安装目录
    static var installedSaverURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers/\(saverFileName)")
    }

    /// 系统级（所有用户）安装目录，若存在同名旧版本会优先生效，需要提示
    static var systemSaverURL: URL {
        URL(fileURLWithPath: "/Library/Screen Savers/\(saverFileName)")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installedSaverURL.path)
    }

    /// 系统级目录存在同名屏保（可能是旧版本，会覆盖用户目录的选择）
    static var hasSystemLevelCopy: Bool {
        FileManager.default.fileExists(atPath: systemSaverURL.path)
    }

    enum InstallError: LocalizedError {
        case embeddedMissing
        case engineMissing
        var errorDescription: String? {
            switch self {
            case .embeddedMissing:
                return "应用包内未找到 ScreenClock.saver，请使用完整构建的应用。"
            case .engineMissing:
                return "当前系统未找到 ScreenSaverEngine，可改为在系统设置中预览屏保。"
            }
        }
    }

    /// 复制覆盖安装
    static func install() throws {
        guard let source = embeddedSaverURL else { throw InstallError.embeddedMissing }
        let destination = installedSaverURL
        let fm = FileManager.default
        try? fm.removeItem(at: destination)
        try fm.createDirectory(at: destination.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        try fm.copyItem(at: source, to: destination)
        // macOS 会把已加载的 .saver 缓存在屏保宿主进程里，覆盖文件后不会自动重载，
        // 表现为“重装后仍是旧屏保”。结束这些宿主，下次预览/触发时会加载新 bundle。
        terminateSaverHosts()
    }

    /// 结束正在运行的屏保宿主（全屏引擎 + 系统设置里的预览桥接进程）。
    /// 二者都会在下次触发/回到设置页时自动重启，属于安全操作。
    @discardableResult
    static func terminateSaverHosts() -> [String] {
        // ScreenSaverEngine：全屏预览/真正运行的屏保；legacyScreenSaver：系统设置预览桥
        let hosts = ["ScreenSaverEngine", "legacyScreenSaver"]
        var terminated: [String] = []
        for name in hosts {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = [name]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 { terminated.append(name) }
            } catch {
                // 进程不存在等情况直接忽略
            }
        }
        return terminated
    }

    /// 打开 .saver，系统会自动弹出屏幕保护程序设置并询问使用
    static func openInSystemSettings() {
        if isInstalled {
            NSWorkspace.shared.open(installedSaverURL)
        } else if let source = embeddedSaverURL {
            NSWorkspace.shared.open(source)
        }
    }

    /// 在 Finder 中定位已安装的屏保
    static func revealInstalled() {
        guard isInstalled else { return }
        NSWorkspace.shared.activateFileViewerSelecting([installedSaverURL])
    }

    /// ScreenSaverEngine 位置：新版 macOS 在 CoreServices，旧版在 ScreenSaver.framework
    static var engineURL: URL? {
        let candidates = [
            "/System/Library/CoreServices/ScreenSaverEngine.app",
            "/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app"
        ]
        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// 直接调用 ScreenSaverEngine 全屏预览
    static func previewFullScreen() throws {
        guard let engine = engineURL else {
            throw InstallError.engineMissing
        }
        let target = isInstalled ? installedSaverURL : embeddedSaverURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        if let target {
            configuration.arguments = [target.path]
        }
        NSWorkspace.shared.openApplication(at: engine, configuration: configuration)
    }
}
