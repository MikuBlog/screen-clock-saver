//
//  ScreenClockSaverView.swift
//  系统屏保入口：ScreenSaverEngine 会在每块显示器上实例化本视图
//

import ScreenSaver

@objc(ScreenClockSaverView)
final class ScreenClockSaverView: ScreenSaverView {

    private let clockView = FlipClockView()
    private var optionsWindow: NSWindow?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        animationTimeInterval = 1.0
        clockView.frame = bounds
        clockView.autoresizingMask = [.width, .height]
        addSubview(clockView)
    }

    override func layout() {
        super.layout()
        clockView.frame = bounds
        evaluateDisplayPolicy()
    }

    override func startAnimation() {
        super.startAnimation()
        // 每次启动重新读取配置，保证设置应用的修改立即生效
        clockView.apply(SettingsStore.shared.settings)
        evaluateDisplayPolicy()
        clockView.isPaused = false
    }

    override func stopAnimation() {
        clockView.isPaused = true
        super.stopAnimation()
    }

    /// 多显示器策略：仅主屏时，副屏纯黑
    private func evaluateDisplayPolicy() {
        let settings = SettingsStore.shared.settings
        guard settings.displayMode == .mainOnly else {
            clockView.isHidden = false
            return
        }
        if let screen = window?.screen, let primary = NSScreen.screens.first, screen != primary {
            clockView.isHidden = true
        } else {
            clockView.isHidden = false
        }
    }

    // 系统屏保选项里的“屏幕保护程序选项”面板
    override var configureSheet: NSWindow? {
        if optionsWindow == nil {
            optionsWindow = makeOptionsWindow()
        }
        return optionsWindow
    }

    private func makeOptionsWindow() -> NSWindow {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 170),
            styleMask: [.titled],
            backing: .buffered,
            defer: false)
        win.title = "翻页时钟"
        win.isReleasedWhenClosed = false

        let hint = NSTextField(labelWithString: "主题、亮度、翻页动画等全部样式\n请在「翻页时钟」设置应用中调整")
        hint.alignment = .center
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 0

        let openButton = NSButton(title: "打开设置应用", target: self, action: #selector(openStudioApp))
        let closeButton = NSButton(title: "关闭", target: self, action: #selector(closeOptions))
        bezel(openButton, keyEquivalent: "\r")
        bezel(closeButton, keyEquivalent: "\u{1b}")

        let buttonRow = NSStackView(views: [closeButton, openButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        let stack = NSStackView(views: [hint, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 22
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        win.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: win.contentView!.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: win.contentView!.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: win.contentView!.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: win.contentView!.trailingAnchor, constant: -16)
        ])
        return win
    }

    private func bezel(_ button: NSButton, keyEquivalent: String) {
        button.bezelStyle = .rounded
        button.keyEquivalent = keyEquivalent
        button.setButtonType(.momentaryPushIn)
    }

    @objc private func openStudioApp() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let candidates = [
            URL(fileURLWithPath: "/Applications/ScreenClockStudio.app"),
            URL(fileURLWithPath: "/Applications/翻页时钟.app"),
            home.appendingPathComponent("Applications/ScreenClockStudio.app"),
            home.appendingPathComponent("Applications/翻页时钟.app")
        ]
        if let app = candidates.first(where: { fm.fileExists(atPath: $0.path) }) {
            NSWorkspace.shared.open(app)
        } else {
            let alert = NSAlert()
            alert.messageText = "未找到设置应用"
            alert.informativeText = "请先安装「翻页时钟」设置应用（ScreenClockStudio.app），可在其中调整全部样式并安装屏保。"
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }

    @objc private func closeOptions() {
        optionsWindow?.sheetParent?.endSheet(optionsWindow!)
        optionsWindow?.close()
    }

    // 使用 Core Animation 自绘，不使用默认 draw 循环
    override func draw(_ rect: NSRect) {}
}
