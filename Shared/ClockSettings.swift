//
//  ClockSettings.swift
//  ScreenClock —— 设置应用与屏保共享的配置模型
//

import Foundation
import CoreGraphics

// MARK: - 布局方向

public enum LayoutMode: String, Codable, CaseIterable, Identifiable {
    case automatic
    case horizontal
    case vertical

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .automatic: return "自动（按屏幕方向）"
        case .horizontal: return "横向排列"
        case .vertical: return "纵向排列"
        }
    }
    public var iconName: String {
        switch self {
        case .automatic: return "arrow.left.and.right"
        case .horizontal: return "rectangle.split.2x1"
        case .vertical: return "rectangle.split.1x2"
        }
    }
}

// MARK: - 多显示器策略

public enum DisplayMode: String, Codable, CaseIterable, Identifiable {
    case allDisplays
    case mainOnly

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .allDisplays: return "所有显示器同时显示"
        case .mainOnly: return "仅主显示器显示（其余屏幕纯黑）"
        }
    }
    public var detail: String {
        switch self {
        case .allDisplays: return "每块屏幕独立渲染翻页时钟，避免外接显示器黑屏。"
        case .mainOnly: return "外接显示器 / 副屏保持纯黑，只在主屏幕显示时钟。"
        }
    }
}

// MARK: - 日期位置

public enum DatePosition: String, Codable, CaseIterable, Identifiable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .topLeading: return "左上角"
        case .topTrailing: return "右上角"
        case .bottomLeading: return "左下角"
        case .bottomTrailing: return "右下角"
        }
    }
}

// MARK: - 日期格式

public enum DateFormatOption: String, Codable, CaseIterable, Identifiable {
    case chinese          // 2026年8月30日
    case chineseWeekday   // 2026年8月30日 周日
    case numeric          // 2026-08-30
    case numericWeekday   // 2026-08-30 周日

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .chinese: return "2026年8月30日"
        case .chineseWeekday: return "2026年8月30日 周日"
        case .numeric: return "2026-08-30"
        case .numericWeekday: return "2026-08-30 周日"
        }
    }
    /// DateFormatter 模板（zh_CN 本地化）
    public var template: String {
        switch self {
        case .chinese: return "yyyy年M月d日"
        case .chineseWeekday: return "yyyy年M月d日 EEE"
        case .numeric: return "yyyy-MM-dd"
        case .numericWeekday: return "yyyy-MM-dd EEE"
        }
    }
}

// MARK: - 字重

public enum ClockFontWeight: String, Codable, CaseIterable, Identifiable {
    case ultraLight
    case light
    case regular
    case medium
    case semibold

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .ultraLight: return "极细"
        case .light: return "纤细"
        case .regular: return "常规"
        case .medium: return "中等"
        case .semibold: return "偏粗"
        }
    }
    /// NSFont.Weight 的 rawValue
    public var weightValue: CGFloat {
        switch self {
        case .ultraLight: return -0.8
        case .light: return -0.4
        case .regular: return 0.0
        case .medium: return 0.23
        case .semibold: return 0.3
        }
    }
}

// MARK: - 主题模型

public struct ClockTheme: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let backgroundHex: String
    public let cardHex: String
    public let textHex: String
    public let seamHex: String
    public let borderHex: String?
    public let borderWidth: CGFloat

    public init(id: String,
                name: String,
                backgroundHex: String,
                cardHex: String,
                textHex: String,
                seamHex: String,
                borderHex: String? = nil,
                borderWidth: CGFloat = 0) {
        self.id = id
        self.name = name
        self.backgroundHex = backgroundHex
        self.cardHex = cardHex
        self.textHex = textHex
        self.seamHex = seamHex
        self.borderHex = borderHex
        self.borderWidth = borderWidth
    }
}

// MARK: - 全部设置

public struct ClockSettings: Codable, Equatable {
    /// 24 小时制（false 为 12 小时制）
    public var use24Hour: Bool
    /// 显示秒
    public var showSeconds: Bool
    /// 12 小时制下显示 AM/PM
    public var showPeriod: Bool

    /// 当前主题 ID
    public var themeID: String

    /// 整体尺寸 0.5 ~ 1.0
    public var scale: Double
    /// 亮度 0.05 ~ 1.0
    public var brightness: Double
    /// 卡片圆角（pt）
    public var cornerRadius: Double
    /// 卡片间距（pt）
    public var cardGap: Double
    /// 阴影强度 0 ~ 1
    public var shadowIntensity: Double

    /// 翻页动画 + 中央转轴
    public var flipEnabled: Bool
    /// 卡片分割线（水平中缝 + 两位数字之间的竖线）
    public var showCardSeams: Bool
    /// 卡片底板（关闭后只保留数字，背景纯净）
    public var showCardBackground: Bool
    /// 单次翻页时长（秒）
    public var flipDuration: Double
    /// 字体族
    public var fontFamily: ClockFontFamily
    /// 字重
    public var fontWeight: ClockFontWeight

    /// 显示日期
    public var showDate: Bool
    /// 日期位置
    public var datePosition: DatePosition
    /// 日期格式
    public var dateFormat: DateFormatOption
    /// 日期距屏幕边缘的边距（pt）
    public var dateMargin: Double

    /// 布局方向
    public var layoutMode: LayoutMode
    /// 多显示器策略
    public var displayMode: DisplayMode

    public init() {
        use24Hour = true
        showSeconds = false
        showPeriod = true
        themeID = "classic"
        scale = 1.0
        brightness = 0.88
        cornerRadius = 50
        cardGap = 65
        shadowIntensity = 0.35
        flipEnabled = true
        showCardSeams = true
        showCardBackground = true
        flipDuration = 0.6
        fontFamily = .sfMono
        fontWeight = .light
        showDate = false
        datePosition = .topTrailing
        dateFormat = .chineseWeekday
        dateMargin = 70
        layoutMode = .automatic
        displayMode = .allDisplays
    }

    // 向前兼容：缺少字段时使用默认值，避免旧配置导致解析失败
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let v = try? c.decode(Bool.self, forKey: .use24Hour) { use24Hour = v }
        if let v = try? c.decode(Bool.self, forKey: .showSeconds) { showSeconds = v }
        if let v = try? c.decode(Bool.self, forKey: .showPeriod) { showPeriod = v }
        if let v = try? c.decode(String.self, forKey: .themeID) { themeID = v }
        if let v = try? c.decode(Double.self, forKey: .scale) { scale = v }
        if let v = try? c.decode(Double.self, forKey: .brightness) { brightness = v }
        if let v = try? c.decode(Double.self, forKey: .cornerRadius) { cornerRadius = v }
        if let v = try? c.decode(Double.self, forKey: .cardGap) { cardGap = v }
        if let v = try? c.decode(Double.self, forKey: .shadowIntensity) { shadowIntensity = v }
        if let v = try? c.decode(Bool.self, forKey: .flipEnabled) { flipEnabled = v }
        if let v = try? c.decode(Bool.self, forKey: .showCardSeams) { showCardSeams = v }
        if let v = try? c.decode(Bool.self, forKey: .showCardBackground) { showCardBackground = v }
        if let v = try? c.decode(Double.self, forKey: .flipDuration) { flipDuration = v }
        if let v = try? c.decode(ClockFontFamily.self, forKey: .fontFamily) { fontFamily = v }
        if let v = try? c.decode(ClockFontWeight.self, forKey: .fontWeight) { fontWeight = v }
        if let v = try? c.decode(Bool.self, forKey: .showDate) { showDate = v }
        if let v = try? c.decode(DatePosition.self, forKey: .datePosition) { datePosition = v }
        if let v = try? c.decode(DateFormatOption.self, forKey: .dateFormat) { dateFormat = v }
        if let v = try? c.decode(Double.self, forKey: .dateMargin) { dateMargin = v }
        if let v = try? c.decode(LayoutMode.self, forKey: .layoutMode) { layoutMode = v }
        if let v = try? c.decode(DisplayMode.self, forKey: .displayMode) { displayMode = v }
    }
}
