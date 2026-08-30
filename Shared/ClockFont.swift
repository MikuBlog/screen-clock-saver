//
//  ClockFont.swift
//  数字字体族：全部使用 macOS 自带字体，无需额外打包字体文件。
//  非等宽字体统一附加「等宽数字」特性，避免秒数跳动时数字宽度抖动。
//

import AppKit

public enum ClockFontFamily: String, Codable, CaseIterable, Identifiable {
    case sfMono        // 系统等宽（SF Mono）
    case sfRounded     // 系统圆角（SF Rounded）
    case sfSerif       // 系统衬线（New York）
    case helvetica     // Helvetica Neue
    case avenir        // Avenir Next
    case futura        // Futura
    case din           // DIN Alternate
    case menlo         // Menlo（等宽）
    case courier       // Courier New（等宽）
    case georgia       // Georgia（衬线）

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .sfMono: return "系统等宽"
        case .sfRounded: return "系统圆角"
        case .sfSerif: return "系统衬线"
        case .helvetica: return "Helvetica Neue"
        case .avenir: return "Avenir Next"
        case .futura: return "Futura"
        case .din: return "DIN Alternate"
        case .menlo: return "Menlo"
        case .courier: return "Courier New"
        case .georgia: return "Georgia"
        }
    }

    /// 字体本身是否等宽（等宽字体不需要再附加等宽数字特性）
    fileprivate var isMonospace: Bool {
        switch self {
        case .sfMono, .menlo, .courier: return true
        default: return false
        }
    }

    /// 系统设计字体（走 NSFont.systemFont(design:)），返回 nil 表示命名字体族
    fileprivate var systemDesign: NSFontDescriptor.SystemDesign? {
        switch self {
        case .sfRounded: return .rounded
        case .sfSerif: return .serif
        default: return nil
        }
    }

    /// 命名字体族名称（用于 NSFontManager / NSFontDescriptor 匹配）
    fileprivate var familyName: String? {
        switch self {
        case .helvetica: return "Helvetica Neue"
        case .avenir: return "Avenir Next"
        case .futura: return "Futura"
        case .din: return "DIN Alternate"
        case .menlo: return "Menlo"
        case .courier: return "Courier New"
        case .georgia: return "Georgia"
        default: return nil
        }
    }

    /// 构造指定字号 / 字重的字体；任何一步匹配失败都回退到系统等宽，保证永不崩版
    public func makeFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let safeSize = max(1, size)

        // 1) 系统等宽
        if self == .sfMono {
            return NSFont.monospacedSystemFont(ofSize: safeSize, weight: weight)
        }

        // 2) 系统设计字体（圆角 / 衬线）
        if let design = systemDesign {
            let systemDescriptor = NSFont.systemFont(ofSize: safeSize, weight: weight).fontDescriptor
            if let designed = systemDescriptor.withDesign(design),
               let base = NSFont(descriptor: designed, size: safeSize) {
                return monospacedDigitsIfNeeded(base)
            }
        }

        // 3) 命名字体族：按字重选择最接近的成员（必须显式传 size，否则会退回 12pt）
        if let familyName {
            let descriptor = NSFontDescriptor(fontAttributes: [
                .family: familyName,
                .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue]
            ])
            if let font = NSFont(descriptor: descriptor, size: safeSize) {
                return monospacedDigitsIfNeeded(font)
            }
            // 再退一步：让字体管理器按族名找任意成员
            if let font = NSFontManager.shared.font(withFamily: familyName,
                                                    traits: [],
                                                    weight: Self.appKitWeight(weight),
                                                    size: safeSize) {
                return monospacedDigitsIfNeeded(font)
            }
        }

        // 4) 最终兜底
        return NSFont.monospacedSystemFont(ofSize: safeSize, weight: weight)
    }

    /// NSFontManager 的 weight 取值范围 0~15（5 为 regular）
    private static func appKitWeight(_ weight: NSFont.Weight) -> Int {
        let v = weight.rawValue
        // NSFont.Weight: ultraLight -0.8 … regular 0 … semibold 0.3
        let mapped = 5 + Int((v / 0.25).rounded())
        return min(15, max(0, mapped))
    }

    private func monospacedDigitsIfNeeded(_ font: NSFont) -> NSFont {
        guard !isMonospace,
              let descriptor = font.fontDescriptor.addingAttributes([
                .featureSettings: [
                    [NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                     NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector]
                ]
              ]) as NSFontDescriptor?,
              let fixed = NSFont(descriptor: descriptor, size: font.pointSize) else { return font }
        return fixed
    }
}
