//
//  AppModel.swift
//  设置应用的全局状态：配置编辑、防抖持久化、导入导出
//

import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: ClockSettings {
        didSet { scheduleSave() }
    }
    @Published var installed: Bool = SaverInstaller.isInstalled
    @Published var busyMessage: String?

    private var saveTask: Task<Void, Never>?

    init() {
        settings = SettingsStore.shared.settings
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = settings
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
            SettingsStore.shared.save(snapshot)
            _ = self
        }
    }

    func saveNow() {
        SettingsStore.shared.save(settings)
    }

    func resetToDefault() {
        settings = ClockSettings()
        saveNow()
    }

    func refreshInstallState() {
        installed = SaverInstaller.isInstalled
    }

    func installSaver() throws {
        // 先把最新样式同步到共享配置，避免“装了新包但屏保读到旧样式”
        saveNow()
        try SaverInstaller.install()
        refreshInstallState()
    }

    /// 不重装、仅让正在运行的屏保/预览释放旧 bundle 与旧配置缓存
    func refreshRunningSaver() -> [String] {
        saveNow()
        return SaverInstaller.terminateSaverHosts()
    }

    func exportSettings() throws {
        let panel = NSSavePanel()
        panel.title = "导出配置"
        panel.nameFieldStringValue = "ScreenClock-settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data = try SettingsStore.shared.exportData()
        try data.write(to: url, options: .atomic)
    }

    func importSettings() throws {
        let panel = NSOpenPanel()
        panel.title = "导入配置"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data = try Data(contentsOf: url)
        settings = try SettingsStore.shared.importData(data)
        saveNow()
    }
}
