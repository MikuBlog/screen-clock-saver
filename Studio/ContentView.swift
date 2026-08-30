//
//  ContentView.swift
//  设置应用主界面：总览 / 时钟 / 外观 / 布局 / 显示器 / 隐私与数据 / 关于
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 侧边栏分区

enum SettingsSection: String, CaseIterable, Identifiable {
    case overview, clock, appearance, layout, displays, privacy, about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "总览"
        case .clock: return "时钟"
        case .appearance: return "外观"
        case .layout: return "布局"
        case .displays: return "显示器"
        case .privacy: return "隐私与数据"
        case .about: return "关于"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .clock: return "clock"
        case .appearance: return "paintbrush"
        case .layout: return "rectangle.3.group"
        case .displays: return "display.2"
        case .privacy: return "hand.raised"
        case .about: return "info.circle"
        }
    }
}

struct ContentView: View {
    @State private var selection: SettingsSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .navigationTitle("翻页时钟")
        } detail: {
            switch selection ?? .overview {
            case .overview: OverviewView()
            case .clock: ClockSectionView()
            case .appearance: AppearanceView()
            case .layout: LayoutView()
            case .displays: DisplaysView()
            case .privacy: PrivacyView()
            case .about: AboutView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - 通用控件

struct SliderRow: View {
    let title: String
    let valueText: String
    let range: ClosedRange<Double>
    @Binding var value: Double
    var step: Double? = nil

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 13))
                .frame(width: 84, alignment: .leading)
            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
            Text(valueText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }
}

struct CardGroup<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label(title, systemImage: "slider.horizontal.3")
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
        }
    }
}

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }
}

// MARK: - 总览

struct OverviewView: View {
    @EnvironmentObject var model: AppModel
    @State private var errorText: String?
    @State private var infoText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("总览").font(.largeTitle.bold())

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: model.installed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(model.installed ? .green : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.installed ? "屏保已安装" : "尚未安装屏保")
                                .font(.headline)
                            Text(model.installed
                                 ? "路径：~/Library/Screen Savers/ScreenClock.saver"
                                 : "点击下方按钮，把翻页时钟安装为系统屏幕保护程序。")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        Button(model.installed ? "重新安装 / 更新" : "安装屏保") {
                            run {
                                try model.installSaver()
                                infoText = "已完成安装，并结束了持有旧版本的屏保进程；重新选择或触发屏保即为最新版本。"
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("全屏预览") { run { try SaverInstaller.previewFullScreen() } }
                        Button("刷新运行中的屏保") {
                            let killed = model.refreshRunningSaver()
                            infoText = killed.isEmpty
                                ? "当前没有正在运行的屏保进程；下次触发时会读取最新样式。"
                                : "已结束 \(killed.count) 个运行中的屏保进程，重新预览即为最新样式。"
                        }
                        Button("打开系统屏保设置") { SaverInstaller.openInSystemSettings() }
                        Button("在 Finder 中显示") { SaverInstaller.revealInstalled() }
                            .disabled(!model.installed)
                    }
                    if let infoText {
                        Label(infoText, systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if SaverInstaller.hasSystemLevelCopy {
                        Label("检测到 /Library/Screen Savers 下还有一份所有用户级别的同名屏保，它可能优先生效导致更新无效，建议在 Finder 中删除旧副本。",
                              systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))

                CardGroup(title: "使用步骤") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. 在左侧「时钟 / 外观 / 布局」中调整样式，预览区实时同步并自动保存。")
                        Text("2. 首次使用点击「安装屏保」，在弹出的系统设置中选择「翻页时钟」。")
                        Text("3. 改样式不需要重装：正在运行的屏保会自动热更新；若系统设置预览仍显示旧样式，点「刷新运行中的屏保」。")
                        Text("4. 只有更新程序版本时才需要「重新安装 / 更新」，安装会自动结束持有旧版本的系统进程。")
                        Text("5. 可设置触发时间或使用「触发角」，闲置时自动显示翻页时钟。")
                    }
                    .font(.system(size: 13))
                }

                CardGroup(title: "系统要求") {
                    Text("支持 macOS 14 Sonoma 及以上系统（已适配 macOS 26 Tahoe），兼容横屏、竖屏、带鱼屏与多显示器。")
                        .font(.system(size: 13))
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .alert("操作失败", isPresented: .constant(errorText != nil)) {
            Button("好") { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
        .onAppear { model.refreshInstallState() }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
            model.refreshInstallState()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - 时钟

// MARK: - 字体样式选择（每项用自身字体渲染示例数字）

struct FontFamilyPicker: View {
    @Binding var selection: ClockFontFamily
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(ClockFontFamily.allCases) { family in
                Button {
                    selection = family
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("01:23")
                                .font(Font(family.makeFont(size: 17, weight: .regular)))
                            Text(family.label)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if selection == family {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selection == family
                                  ? Color.accentColor.opacity(0.14)
                                  : Color.gray.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selection == family ? Color.accentColor : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ClockSectionView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("时钟").font(.largeTitle.bold())
                PreviewStage()

                Form {
                    Section("时钟样式") {
                        Picker("样式", selection: $model.settings.clockKind) {
                            ForEach(ClockKind.allCases) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                        if model.settings.clockKind.isAnalog {
                            Toggle("显示秒针", isOn: $model.settings.showSeconds)
                            Toggle("秒针平滑扫秒（关闭则逐秒跳动）",
                                   isOn: $model.settings.smoothSecondHand)
                                .disabled(!model.settings.showSeconds)
                        }
                    }
                    Section("时间制式") {
                        Toggle("使用 24 小时制（关闭则为 12 小时制）", isOn: $model.settings.use24Hour)
                            .disabled(model.settings.clockKind.isAnalog)
                        Toggle("12 小时制下显示 AM / PM", isOn: $model.settings.showPeriod)
                            .disabled(model.settings.use24Hour || model.settings.clockKind.isAnalog)
                        if !model.settings.clockKind.isAnalog {
                            Toggle("显示秒", isOn: $model.settings.showSeconds)
                        }
                    }
                    Section("字体样式") {
                        FontFamilyPicker(selection: $model.settings.fontFamily)
                        if model.settings.clockKind.isAnalog {
                            Text("字体用于经典指针款的表盘数字。")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section("数字字重") {
                        Picker("数字字重", selection: $model.settings.fontWeight) {
                            ForEach(ClockFontWeight.allCases) { weight in
                                Text(weight.label).tag(weight)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("日期") {
                        Toggle("显示日期（年 / 月 / 日）", isOn: $model.settings.showDate)
                        Picker("位置", selection: $model.settings.datePosition) {
                            ForEach(DatePosition.allCases) { pos in
                                Text(pos.label).tag(pos)
                            }
                        }
                        .disabled(!model.settings.showDate)
                        Picker("日期格式", selection: $model.settings.dateFormat) {
                            ForEach(DateFormatOption.allCases) { fmt in
                                Text(fmt.label).tag(fmt)
                            }
                        }
                        .disabled(!model.settings.showDate)
                        SliderRow(title: "距屏幕边距",
                                  valueText: String(format: "%.0f pt", model.settings.dateMargin),
                                  range: 20...200,
                                  value: $model.settings.dateMargin)
                            .disabled(!model.settings.showDate)
                        SliderRow(title: "字符间距",
                                  valueText: "\(Int((model.settings.dateLetterSpacing * 100).rounded()))%",
                                  range: 0...0.5,
                                  value: $model.settings.dateLetterSpacing,
                                  step: 0.01)
                            .disabled(!model.settings.showDate)
                    }
                }
                .formStyle(.grouped)
                .frame(minHeight: 560)
            }
            .padding(24)
        }
    }
}

// MARK: - 外观

struct AppearanceView: View {
    @EnvironmentObject var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("外观").font(.largeTitle.bold())
                PreviewStage()

                CardGroup(title: "主题") {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(ClockThemes.all) { theme in
                            ThemeCard(theme: theme,
                                      selected: model.settings.themeID == theme.id) {
                                model.settings.themeID = theme.id
                            }
                        }
                    }
                }

                CardGroup(title: "视觉参数") {
                    SliderRow(title: "尺寸",
                              valueText: percent(model.settings.scale),
                              range: 0.5...1.0,
                              value: $model.settings.scale)
                    SliderRow(title: "亮度",
                              valueText: percent(model.settings.brightness),
                              range: 0.05...1.0,
                              value: $model.settings.brightness)
                    let analog = model.settings.clockKind.isAnalog
                    SliderRow(title: "圆角",
                              valueText: String(format: "%.0f pt", model.settings.cornerRadius),
                              range: 0...120,
                              value: $model.settings.cornerRadius)
                        .disabled(analog)
                    SliderRow(title: "卡片间距",
                              valueText: String(format: "%.0f pt", model.settings.cardGap),
                              range: 0...200,
                              value: $model.settings.cardGap)
                        .disabled(analog)
                    SliderRow(title: "阴影强度",
                              valueText: percent(model.settings.shadowIntensity),
                              range: 0...1.0,
                              value: $model.settings.shadowIntensity)
                        .disabled(analog)
                    SliderRow(title: "翻页速度",
                              valueText: String(format: "%.2f s", model.settings.flipDuration),
                              range: 0.2...1.5,
                              value: $model.settings.flipDuration)
                        .disabled(analog)
                    Toggle("显示翻页动画与中央转轴", isOn: $model.settings.flipEnabled)
                        .disabled(analog)
                    Toggle("显示卡片分割线（中缝与数字间竖线）", isOn: $model.settings.showCardSeams)
                        .disabled(analog)
                    Toggle("显示卡片底板（关闭后仅保留数字）", isOn: $model.settings.showCardBackground)
                        .disabled(analog)
                }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private func percent(_ v: Double) -> String {
        "\(Int((v * 100).rounded()))%"
    }
}

struct ThemeCard: View {
    let theme: ClockTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: theme.backgroundHex))
                    Text("12:34")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: theme.textHex))
                }
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.accentColor : Color.gray.opacity(0.3),
                                lineWidth: selected ? 3 : 1)
                )
                Text(theme.name)
                    .font(.caption)
                    .foregroundStyle(selected ? Color.accentColor : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 布局

struct LayoutView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("布局").font(.largeTitle.bold())
                PreviewStage()

                CardGroup(title: "排列方向") {
                    Picker("方向", selection: $model.settings.layoutMode) {
                        ForEach(LayoutMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .disabled(model.settings.clockKind.isAnalog)
                    Text("自动模式下，横屏显示器左右排列，竖屏显示器上下堆叠；横纵布局与带鱼屏均自动适配。指针表盘始终居中显示。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                CardGroup(title: "间距") {
                    SliderRow(title: "卡片间距",
                              valueText: String(format: "%.0f pt", model.settings.cardGap),
                              range: 0...200,
                              value: $model.settings.cardGap)
                    SliderRow(title: "整体尺寸",
                              valueText: "\(Int((model.settings.scale * 100).rounded()))%",
                              range: 0.5...1.0,
                              value: $model.settings.scale)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

// MARK: - 显示器

struct DisplaysView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("显示器").font(.largeTitle.bold())

                CardGroup(title: "多显示器策略") {
                    Picker("显示策略", selection: $model.settings.displayMode) {
                        ForEach(DisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    Text(model.settings.displayMode.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                CardGroup(title: "说明") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 屏保引擎会为每块显示器独立创建渲染视图，避免双屏黑屏。")
                        Text("• 各屏幕会根据自身分辨率与方向独立计算卡片尺寸。")
                        Text("• 选择「仅主显示器」时，其余屏幕保持纯黑以减少干扰与耗电。")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

// MARK: - 隐私与数据

struct PrivacyView: View {
    @EnvironmentObject var model: AppModel
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("隐私与数据").font(.largeTitle.bold())

                CardGroup(title: "数据存储") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("本应用不联网、不采集任何数据，全部配置仅保存在本机：")
                            .font(.system(size: 13))
                        Text(SettingsStore.shared.fileURL.path)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.12)))
                    }
                }

                CardGroup(title: "配置管理") {
                    HStack {
                        Button("导出配置") { run { try model.exportSettings() } }
                        Button("导入配置") { run { try model.importSettings() } }
                        Button("恢复默认设置", role: .destructive) {
                            model.resetToDefault()
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .alert("操作失败", isPresented: .constant(errorText != nil)) {
            Button("好") { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    private func run(_ action: () throws -> Void) {
        do { try action() } catch { errorText = error.localizedDescription }
    }
}

// MARK: - 关于

struct AboutView: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "clock.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("翻页时钟").font(.system(size: 28, weight: .bold))
            Text("Flip Clock Screen Saver · 版本 1.0.0")
                .foregroundStyle(.secondary)
            Text("一款可高度自定义的 macOS 翻页时钟屏保\n支持主题、亮度、圆角、阴影、翻页速度、横纵布局与多显示器")
                .multilineTextAlignment(.center)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("最低系统要求：macOS 14 Sonoma（适配 macOS 26 及以上）")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
