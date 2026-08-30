//
//  Theme.swift
//  内置主题 + 十六进制颜色工具
//

import AppKit

public enum ClockThemes {
    public static let all: [ClockTheme] = [classic, warm, gold, graphite, paper, nightPurple]

    public static func theme(_ id: String) -> ClockTheme {
        return all.first(where: { $0.id == id }) ?? all[0]
    }

    /// 经典黑
    public static let classic = ClockTheme(
        id: "classic", name: "经典黑",
        backgroundHex: "#000000",
        cardHex: "#1B1B1D",
        textHex: "#D8D8DA",
        seamHex: "#000000"
    )

    /// 暖白
    public static let warm = ClockTheme(
        id: "warm", name: "暖白",
        backgroundHex: "#E6DECC",
        cardHex: "#F3ECDC",
        textHex: "#574C3E",
        seamHex: "#D6CCB8"
    )

    /// 黑金
    public static let gold = ClockTheme(
        id: "gold", name: "黑金",
        backgroundHex: "#000000",
        cardHex: "#0D0B07",
        textHex: "#E4C267",
        seamHex: "#000000",
        borderHex: "#C9A24B",
        borderWidth: 1.5
    )

    /// 深空灰
    public static let graphite = ClockTheme(
        id: "graphite", name: "深空灰",
        backgroundHex: "#14171C",
        cardHex: "#2A2F38",
        textHex: "#E8ECF2",
        seamHex: "#14171C"
    )

    /// 极简白
    public static let paper = ClockTheme(
        id: "paper", name: "极简白",
        backgroundHex: "#EDEDF0",
        cardHex: "#FFFFFF",
        textHex: "#26262A",
        seamHex: "#D8D8DE"
    )

    /// 暗夜紫
    public static let nightPurple = ClockTheme(
        id: "nightPurple", name: "暗夜紫",
        backgroundHex: "#120D1F",
        cardHex: "#241B3A",
        textHex: "#CDBCFF",
        seamHex: "#120D1F"
    )
}

extension NSColor {
    /// 支持 #RGB / #RRGGBB / #RRGGBBAA
    public convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)

        let r, g, b, a: CGFloat
        switch s.count {
        case 3:
            r = CGFloat((v >> 8) & 0xF) / 15.0
            g = CGFloat((v >> 4) & 0xF) / 15.0
            b = CGFloat(v & 0xF) / 15.0
            a = 1.0
        case 8:
            r = CGFloat((v >> 24) & 0xFF) / 255.0
            g = CGFloat((v >> 16) & 0xFF) / 255.0
            b = CGFloat((v >> 8) & 0xFF) / 255.0
            a = CGFloat(v & 0xFF) / 255.0
        default: // 6 位或异常情况
            r = CGFloat((v >> 16) & 0xFF) / 255.0
            g = CGFloat((v >> 8) & 0xFF) / 255.0
            b = CGFloat(v & 0xFF) / 255.0
            a = 1.0
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
