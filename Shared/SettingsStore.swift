//
//  SettingsStore.swift
//  设置应用与屏保之间共享配置：
//  写入 ~/Library/Application Support/ScreenClockSaver/settings.json
//
//  关键背景：屏保运行在系统的 legacyScreenSaver / ScreenSaverEngine 沙盒进程内，
//  FileManager.homeDirectoryForCurrentUser 会被重定向到该进程的容器目录，
//  直接按它拼路径永远读不到设置应用写出的配置（表现为“改了样式屏保仍旧”）。
//  系统宿主带有对 "/" 的只读例外，因此这里额外用 getpwuid 解析真实用户主目录，
//  读取时在“进程主目录 / 真实主目录”之间按修改时间挑最新，写入时两边尽力同步。
//

import Foundation

public final class SettingsStore {
    public static let shared = SettingsStore()

    public private(set) var settings: ClockSettings

    private static let relativePath = "Library/Application Support/ScreenClockSaver/settings.json"

    /// 当前生效配置来自哪个文件（用于 mtime 热更新判断）
    private var activeFileURL: URL?
    private var fileModificationDate: Date?

    public let folderURL: URL
    public let fileURL: URL

    private init() {
        let homes = SettingsStore.candidateHomeURLs()
        let primary = homes[0]
        folderURL = primary.appendingPathComponent("Library/Application Support/ScreenClockSaver", isDirectory: true)
        fileURL = folderURL.appendingPathComponent("settings.json")

        let (loaded, url, date) = SettingsStore.loadNewest(
            homes.map { Self.configURL(forHome: $0, relativePath: Self.relativePath) })
        settings = loaded ?? ClockSettings()
        activeFileURL = url
        fileModificationDate = date
    }

    // MARK: - 路径解析

    /// 候选主目录：当前进程主目录 + getpwuid 得到的真实用户主目录（去重）
    static func candidateHomeURLs() -> [URL] {
        var result: [URL] = [FileManager.default.homeDirectoryForCurrentUser]
        if let passwd = getpwuid(getuid()), let cDir = passwd.pointee.pw_dir,
           let realHome = String(utf8String: cDir) {
            let url = URL(fileURLWithPath: realHome, isDirectory: true)
            if !result.contains(url) { result.append(url) }
        }
        return result
    }

    private static func configURL(forHome home: URL, relativePath: String) -> URL {
        home.appendingPathComponent(relativePath)
    }

    private var candidateFileURLs: [URL] {
        SettingsStore.candidateHomeURLs().map { Self.configURL(forHome: $0, relativePath: Self.relativePath) }
    }

    private static func mdate(of url: URL) -> Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return attrs[.modificationDate] as? Date
    }

    /// 在候选文件中挑修改时间最新的一份并解码
    private static func loadNewest(_ urls: [URL]) -> (ClockSettings?, URL?, Date?) {
        var bestURL: URL?
        var bestDate: Date?
        for url in urls {
            guard let date = mdate(of: url) else { continue }
            if bestDate == nil || date > bestDate! { bestDate = date; bestURL = url }
        }
        guard let url = bestURL, let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode(ClockSettings.self, from: data) else {
            return (nil, nil, nil)
        }
        return (loaded, url, bestDate)
    }

    // MARK: - 热更新

    /// 任一候选文件被外部修改时重新加载（设置应用拖动滑块时，正在运行的屏保/预览可热更新）
    @discardableResult
    public func reloadIfChanged() -> Bool {
        var newestURL: URL?
        var newestDate: Date?
        for url in candidateFileURLs {
            guard let date = Self.mdate(of: url) else { continue }
            if newestDate == nil || date > newestDate! { newestDate = date; newestURL = url }
        }
        guard let url = newestURL, let date = newestDate else { return false }
        let unchanged = url == activeFileURL && date == fileModificationDate
        guard !unchanged,
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode(ClockSettings.self, from: data) else { return false }
        activeFileURL = url
        fileModificationDate = date
        settings = loaded
        return true
    }

    // MARK: - 写入

    @discardableResult
    public func save(_ settings: ClockSettings) -> Error? {
        self.settings = settings
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)

            var lastError: Error?
            var savedURL: URL?
            for url in candidateFileURLs {
                do {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true)
                    try data.write(to: url, options: .atomic)
                    if savedURL == nil { savedURL = url }
                } catch {
                    // 沙盒内真实主目录只读等情况：忽略，保证至少一个位置写入成功
                    lastError = error
                }
            }
            guard let url = savedURL else { throw lastError ?? NSError(domain: "SettingsStore", code: 1) }
            activeFileURL = url
            fileModificationDate = Self.mdate(of: url)
            return nil
        } catch {
            return error
        }
    }

    public func resetToDefault() {
        save(ClockSettings())
    }

    /// 导出为 JSON Data
    public func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(settings)
    }

    /// 从 JSON Data 导入，返回导入后的设置
    @discardableResult
    public func importData(_ data: Data) throws -> ClockSettings {
        let loaded = try JSONDecoder().decode(ClockSettings.self, from: data)
        save(loaded)
        settings = loaded
        return loaded
    }
}
