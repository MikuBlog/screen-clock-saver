//
//  AnalogClockView.swift
//  指针式表盘：极简刻度款 / 经典数字款，纯 Core Graphics 绘制
//

import AppKit

public final class AnalogClockView: NSView {

    private var settings = ClockSettings()
    private var theme = ClockThemes.classic
    private var ticker: Timer?
    private var paused = false

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        common()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        common()
    }

    private func common() {
        wantsLayer = true
        layer?.backgroundColor = .clear
        startTicker()
    }

    public override var isOpaque: Bool { false }

    func configure(_ settings: ClockSettings, theme: ClockTheme) {
        self.settings = settings
        self.theme = theme
        needsDisplay = true
    }

    func setPaused(_ paused: Bool) {
        self.paused = paused
        if paused { ticker?.invalidate(); ticker = nil } else { startTicker() }
    }

    deinit { ticker?.invalidate() }

    private func startTicker() {
        guard ticker == nil else { return }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard settings.clockKind.isAnalog, let ctx = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let R = min(bounds.width, bounds.height) / 2
        guard R > 4 else { return }

        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute, .second, .nanosecond], from: Date())
        let nano = Double(c.nanosecond ?? 0) / 1_000_000_000
        let secValue = Double(c.second ?? 0) + (settings.smoothSecondHand ? nano : 0)
        let minValue = Double(c.minute ?? 0) + secValue / 60
        let hourValue = Double((c.hour ?? 0) % 12) + minValue / 60

        let textColor = NSColor(hex: theme.textHex)
        let cardColor = NSColor(hex: theme.cardHex)

        switch settings.clockKind {
        case .analogMinimal:
            drawMinimal(ctx: ctx, center: center, R: R,
                        text: textColor, hour: hourValue, minute: minValue, second: secValue)
        case .analogClassic:
            drawClassic(ctx: ctx, center: center, R: R,
                        text: textColor, card: cardColor,
                        hour: hourValue, minute: minValue, second: secValue)
        case .flipDigital:
            break
        }
    }

    // MARK: - 极简刻度款

    private func drawMinimal(ctx: CGContext, center: CGPoint, R: CGFloat,
                             text: NSColor, hour: Double, minute: Double, second: Double) {
        // 12 根圆角矩形刻度（NSView 为 y 轴向上：12 点在 +y，顺时针递增）
        for i in 0..<12 {
            let a = .pi / 2 - CGFloat(i) * .pi / 6
            let markerW: CGFloat = R * 0.030
            let markerH: CGFloat = R * 0.085
            let ringR = R * 0.88
            let p = CGPoint(x: center.x + cos(a) * ringR, y: center.y + sin(a) * ringR)
            ctx.saveGState()
            ctx.translateBy(x: p.x, y: p.y)
            ctx.rotate(by: a + .pi / 2)
            let rect = CGRect(x: -markerW / 2, y: -markerH / 2, width: markerW, height: markerH)
            let path = CGPath(roundedRect: rect, cornerWidth: markerW / 2, cornerHeight: markerW / 2, transform: nil)
            ctx.addPath(path)
            ctx.setFillColor(text.cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }

        // 时 / 分 针
        drawHand(ctx: ctx, center: center, value: hour, period: 12,
                 length: R * 0.52, width: R * 0.060, color: text, tail: 0)
        drawHand(ctx: ctx, center: center, value: minute, period: 60,
                 length: R * 0.76, width: R * 0.040, color: text, tail: 0)

        // 秒针（细 + 尾部配重）
        if settings.showSeconds {
            drawHand(ctx: ctx, center: center, value: second, period: 60,
                     length: R * 0.82, width: max(1.2, R * 0.012), color: text, tail: R * 0.22)
        }

        // 中心轴帽
        fillCircle(ctx: ctx, center: center, radius: R * 0.055, color: text)
        fillCircle(ctx: ctx, center: center, radius: R * 0.022,
                   color: NSColor(hex: theme.backgroundHex))
    }

    // MARK: - 经典数字款

    private func drawClassic(ctx: CGContext, center: CGPoint, R: CGFloat,
                             text: NSColor, card: NSColor,
                             hour: Double, minute: Double, second: Double) {
        // 表盘底色
        fillCircle(ctx: ctx, center: center, radius: R * 0.985, color: card)

        // 60 个分钟小点（整点位置留给数字）
        for i in 0..<60 where i % 5 != 0 {
            let a = .pi / 2 - CGFloat(i) * .pi / 30
            let p = CGPoint(x: center.x + cos(a) * R * 0.88, y: center.y + sin(a) * R * 0.88)
            fillCircle(ctx: ctx, center: p, radius: max(1, R * 0.008),
                       color: text.withAlphaComponent(0.45))
        }

        // 1–12 阿拉伯数字
        let fontSize = R * 0.135
        let font = settings.fontFamily.makeFont(size: fontSize, weight: .medium)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: text, .paragraphStyle: para
        ]
        let numRingR = R * 0.72
        for i in 1...12 {
            let a = .pi / 2 - CGFloat(i) * .pi / 6
            let p = CGPoint(x: center.x + cos(a) * numRingR, y: center.y + sin(a) * numRingR)
            let s = "\(i)"
            let size = (s as NSString).size(withAttributes: attrs)
            (s as NSString).draw(at: CGPoint(x: p.x - size.width / 2,
                                             y: p.y - size.height / 2),
                                 withAttributes: attrs)
        }

        // 时 / 分 针（白色，略带回旋尾部；长度止于数字内侧）
        drawHand(ctx: ctx, center: center, value: hour, period: 12,
                 length: R * 0.48, width: R * 0.052, color: text, tail: R * 0.08)
        drawHand(ctx: ctx, center: center, value: minute, period: 60,
                 length: R * 0.66, width: R * 0.036, color: text, tail: R * 0.10)

        // 红色秒针 + 尾部圆形配重
        if settings.showSeconds {
            let red = NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1)
            let tail = R * 0.24
            drawHand(ctx: ctx, center: center, value: second, period: 60,
                     length: R * 0.84, width: max(1, R * 0.010), color: red, tail: tail)
            let sa = .pi / 2 - CGFloat(second / 60) * 2 * .pi
            fillCircle(ctx: ctx,
                       center: CGPoint(x: center.x - cos(sa) * tail,
                                       y: center.y - sin(sa) * tail),
                       radius: R * 0.045, color: red)
        }

        // 中心轴帽
        fillCircle(ctx: ctx, center: center, radius: R * 0.060, color: text)
        fillCircle(ctx: ctx, center: center, radius: R * 0.032,
                   color: settings.showSeconds
                    ? NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1)
                    : NSColor(hex: theme.backgroundHex))
    }

    // MARK: - 绘制基元

    /// 以 center 为轴心、按 period 周期换算角度的指针（12 点方向为 0，顺时针）
    private func drawHand(ctx: CGContext, center: CGPoint, value: Double, period: Double,
                          length: CGFloat, width: CGFloat, color: NSColor, tail: CGFloat) {
        // y 轴向上：0 点在正上方，value 增大时顺时针旋转
        let angle = .pi / 2 - CGFloat(value / period) * 2 * .pi
        ctx.saveGState()
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(color.cgColor)
        ctx.move(to: CGPoint(x: center.x - cos(angle) * tail,
                             y: center.y - sin(angle) * tail))
        ctx.addLine(to: CGPoint(x: center.x + cos(angle) * length,
                                y: center.y + sin(angle) * length))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func fillCircle(ctx: CGContext, center: CGPoint, radius: CGFloat, color: NSColor) {
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2))
        ctx.restoreGState()
    }
}
