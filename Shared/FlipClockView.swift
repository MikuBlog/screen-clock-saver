//
//  FlipClockView.swift
//  翻页时钟渲染核心：AppKit 自绘，设置应用预览与系统屏保共用同一份代码。
//
//  架构说明（对齐参考实现 GraceClock 的成熟方案）：
//  - 布局：layoutAll() 用统一的约束求解，固定间距参与求解并被可用空间钳制，
//    任何比例下卡片都完整落在边界内；
//  - 翻页：FlipGroupView 在 draw(_:) 中按时间进度逐帧重绘（cos/sin 翻叶），
//    由 60fps 定时器驱动，不存在两个动画事务之间的跳帧接缝；
//  - 坐标系：使用 isFlipped 的标准 NSView 绘制，SwiftUI 宿主与屏保宿主行为一致，
//    不手写 CALayer 几何，避免宿主坐标系差异。
//

import AppKit

// MARK: - 时钟总视图

public final class FlipClockView: NSView {

    // MARK: 状态

    fileprivate(set) var settings: ClockSettings
    fileprivate var theme: ClockTheme
    private var groups: [String] = []
    private var groupViews: [FlipGroupView] = []
    private let dateLabel = DateLabelView()
    private let analogView = AnalogClockView()
    private var clockTimer: Timer?
    private var animTimer: Timer?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    public var isPaused: Bool = false {
        didSet {
            if isPaused {
                stopClockTimer()
                stopAnimTimer()
            } else {
                startClockTimer()
            }
            analogView.setPaused(isPaused)
        }
    }

    // MARK: 初始化

    public override init(frame frameRect: NSRect) {
        settings = SettingsStore.shared.settings
        theme = ClockThemes.theme(settings.themeID)
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        settings = SettingsStore.shared.settings
        theme = ClockThemes.theme(settings.themeID)
        super.init(coder: coder)
        commonInit()
    }

    public override var isOpaque: Bool { true }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(hex: theme.backgroundHex).cgColor
        groups = computeGroups(Date())
        rebuildGroupViews()
        addSubview(analogView)
        addSubview(dateLabel)
        applyColors()
        needsLayout = true
        startClockTimer()
    }

    deinit {
        clockTimer?.invalidate()
        animTimer?.invalidate()
    }

    // MARK: 布局触发（SwiftUI / Auto Layout 改尺寸时兜底）

    public override func layout() {
        super.layout()
        layoutAll()
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutAll()
    }

    public override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        layoutAll()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsLayout = true
        groupViews.forEach { $0.needsDisplay = true }
    }

    // MARK: 配置热更新

    public func apply(_ newSettings: ClockSettings) {
        let structureChanged =
            newSettings.showSeconds != settings.showSeconds ||
            newSettings.use24Hour != settings.use24Hour ||
            newSettings.showPeriod != settings.showPeriod

        settings = newSettings
        theme = ClockThemes.theme(newSettings.themeID)
        applyColors()

        // 数字 / 指针样式切换
        let analogOn = newSettings.clockKind.isAnalog
        groupViews.forEach { $0.isHidden = analogOn }
        analogView.isHidden = !analogOn
        analogView.configure(newSettings, theme: theme)
        analogView.setPaused(isPaused)

        groups = computeGroups(Date())
        if structureChanged || groups.count != groupViews.count {
            rebuildGroupViews()
        }
        needsLayout = true
        layoutAll()
        // 配置变化时直接定位到稳定态，不保留半截动画
        for (i, view) in groupViews.enumerated() where i < groups.count {
            view.snap(to: groups[i])
        }
        updateDateLabel()
    }

    private func applyColors() {
        layer?.backgroundColor = NSColor(hex: theme.backgroundHex).cgColor
        let brightness = max(0.05, min(1.0, settings.brightness))
        groupViews.forEach { $0.layer?.opacity = Float(brightness) }
        dateLabel.layer?.opacity = Float(brightness)
        analogView.layer?.opacity = Float(brightness)
    }

    // MARK: 计时

    private func startClockTimer() {
        stopClockTimer()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        clockTimer = t
        tick()
    }

    private func stopClockTimer() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    private func tick() {
        if SettingsStore.shared.reloadIfChanged() {
            apply(SettingsStore.shared.settings)
            return
        }
        updateDateLabel()
        // 指针表盘由自身定时器驱动，无需驱动翻页组
        if settings.clockKind.isAnalog { return }
        let latest = computeGroups(Date())
        guard latest != groups else { return }
        groups = latest
        if latest.count == groupViews.count {
            for (index, view) in groupViews.enumerated() {
                view.setValue(latest[index], animated: true)
            }
        } else {
            rebuildGroupViews()
            needsLayout = true
            layoutAll()
        }
    }

    /// 翻页动画期间以 60fps 驱动重绘，无动画时自动停表
    fileprivate func ensureAnimTimer() {
        guard animTimer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            var anyAnimating = false
            for view in self.groupViews where view.isAnimating {
                view.needsDisplay = true
                anyAnimating = true
            }
            if !anyAnimating { self.stopAnimTimer() }
        }
        RunLoop.main.add(t, forMode: .common)
        animTimer = t
    }

    private func stopAnimTimer() {
        animTimer?.invalidate()
        animTimer = nil
    }

    // MARK: 时间分组

    private func computeGroups(_ date: Date) -> [String] {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        var hour = c.hour ?? 0
        var result: [String] = []

        if settings.use24Hour {
            result.append(String(format: "%02d", hour))
        } else {
            hour = hour % 12
            if hour == 0 { hour = 12 }
            result.append(String(format: "%02d", hour))
        }
        result.append(String(format: "%02d", c.minute ?? 0))
        if settings.showSeconds {
            result.append(String(format: "%02d", c.second ?? 0))
        }
        if !settings.use24Hour && settings.showPeriod {
            result.append((c.hour ?? 0) >= 12 ? "PM" : "AM")
        }
        return result
    }

    private static func isLetterCard(_ text: String) -> Bool {
        text.unicodeScalars.contains { !CharacterSet.decimalDigits.contains($0) }
    }

    /// 字母卡片相对数字卡片的尺寸系数
    private func widthFactor(letter: Bool) -> CGFloat { letter ? 0.52 : 1.0 }
    private func heightFactor(letter: Bool) -> CGFloat { letter ? 0.42 : 1.0 }

    // MARK: 组视图管理

    private func rebuildGroupViews() {
        groupViews.forEach { $0.removeFromSuperview() }
        groupViews = groups.map { text in
            let v = FlipGroupView(host: self)
            v.snap(to: text)
            addSubview(v)
            return v
        }
        applyColors()
    }

    // MARK: 布局求解

    private func layoutAll() {
        guard bounds.width > 2, bounds.height > 2, !groupViews.isEmpty else { return }

        let letterFlags = groups.map { Self.isLetterCard($0) }
        let scaleValue = CGFloat(max(0.4, min(1.0, settings.scale)))
        let rawGap = max(0, CGFloat(settings.cardGap))

        // 指针式：表盘为居中正方形，不参与翻页卡片布局
        if settings.clockKind.isAnalog {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            var stage = bounds
            // 日期压到表盘时，在日期对侧让出安全区
            if settings.showDate, let df = dateFrame() {
                let d0 = min(bounds.width, bounds.height) * 0.94 * scaleValue
                let dial0 = CGRect(x: bounds.midX - d0 / 2, y: bounds.midY - d0 / 2,
                                   width: d0, height: d0)
                if dial0.insetBy(dx: -8, dy: -8).intersects(df) {
                    let dateFontSize = computedDateFontSize()
                    let band = CGFloat(settings.dateMargin) * scaleValue + dateFontSize * 1.6
                    stage = settings.datePosition.isTop
                        ? CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height - band)
                        : CGRect(x: bounds.minX, y: bounds.minY + band, width: bounds.width, height: bounds.height - band)
                }
            }
            let diameter = min(stage.width, stage.height) * 0.94 * scaleValue
            analogView.frame = CGRect(x: stage.midX - diameter / 2,
                                      y: stage.midY - diameter / 2,
                                      width: diameter, height: diameter)
            CATransaction.commit()
            analogView.needsDisplay = true
            updateDateLabel()
            return
        }

        let horizontal: Bool
        switch settings.layoutMode {
        case .horizontal: horizontal = true
        case .vertical: horizontal = false
        case .automatic: horizontal = bounds.width >= bounds.height
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 第一遍：始终以整块区域居中，保证视觉居中
        var clockFrame = placeGroups(in: bounds, horizontal: horizontal,
                                     letterFlags: letterFlags, scale: scaleValue, rawGap: rawGap)

        // 第二遍：只有当时钟真的会压到角落的日期时，才在日期所在边让出安全区重新布局
        if settings.showDate, let df = dateFrame() {
            if clockFrame.insetBy(dx: -8, dy: -8).intersects(df) {
                let dateFontSize = computedDateFontSize()
                let band = CGFloat(settings.dateMargin) * scaleValue + dateFontSize * 1.6
                let container: CGRect
                switch settings.datePosition {
                case .topLeading, .topCenter, .topTrailing:
                    container = CGRect(x: bounds.minX, y: bounds.minY,
                                       width: bounds.width, height: bounds.height - band)
                case .bottomLeading, .bottomCenter, .bottomTrailing:
                    container = CGRect(x: bounds.minX, y: bounds.minY + band,
                                       width: bounds.width, height: bounds.height - band)
                }
                clockFrame = placeGroups(in: container, horizontal: horizontal,
                                         letterFlags: letterFlags, scale: scaleValue, rawGap: rawGap)
            }
        }

        CATransaction.commit()
        groupViews.forEach { $0.needsDisplay = true }
        updateDateLabel()
    }

    /// 在给定容器内求解并摆放全部卡片组，返回卡片组整体外接矩形
    @discardableResult
    private func placeGroups(in container: CGRect,
                             horizontal: Bool,
                             letterFlags: [Bool],
                             scale scaleValue: CGFloat,
                             rawGap: CGFloat) -> CGRect {
        let n = groupViews.count
        var union: CGRect = .null

        if horizontal {
            let targetW = container.width * 0.94
            let targetH = container.height * 0.92
            // 固定间距被可用宽度钳制，保证间距不参与溢出
            let gap = min(rawGap, n > 1 ? max(0, (targetW - 2) / CGFloat(n - 1)) : 0)
            let sumFactor = letterFlags.reduce(CGFloat(0)) { $0 + widthFactor(letter: $1) }
            // 数字卡为正方形：卡片高 h，数字卡宽 h，字母卡宽 0.52h
            var cardH = min(targetH, (targetW - gap * CGFloat(n - 1)) / sumFactor)
            cardH *= scaleValue
            let totalW = letterFlags.enumerated().reduce(CGFloat(0)) { $0 + widthFactor(letter: $1.element) * cardH }
                + gap * CGFloat(n - 1)
            var x = container.minX + (container.width - totalW) / 2
            let y = container.minY + (container.height - cardH) / 2
            for (i, view) in groupViews.enumerated() {
                let w = widthFactor(letter: letterFlags[i]) * cardH
                view.frame = CGRect(x: x, y: y, width: w, height: cardH)
                union = union == .null ? view.frame : union.union(view.frame)
                x += w + gap
            }
        } else {
            let targetW = container.width * 0.86
            let targetH = container.height * 0.94
            let gap = min(rawGap, n > 1 ? max(0, (targetH - 2) / CGFloat(n - 1)) : 0)
            let sumHFactor = letterFlags.reduce(CGFloat(0)) { $0 + heightFactor(letter: $1) }
            // 数字卡为正方形：卡片宽 w、高 w；字母卡宽 w、高 0.42w
            var cardW = min(targetW, (targetH - gap * CGFloat(n - 1)) / sumHFactor)
            cardW *= scaleValue
            let totalH = letterFlags.enumerated().reduce(CGFloat(0)) { $0 + heightFactor(letter: $1.element) * cardW }
                + gap * CGFloat(n - 1)
            // 标准 y-up 坐标：第一组在最上方，自上而下堆叠
            var yTop = container.minY + (container.height + totalH) / 2
            let x = container.minX + (container.width - cardW) / 2
            for (i, view) in groupViews.enumerated() {
                let h = heightFactor(letter: letterFlags[i]) * cardW
                yTop -= h
                view.frame = CGRect(x: x, y: yTop, width: cardW, height: h)
                union = union == .null ? view.frame : union.union(view.frame)
                yTop -= gap
            }
        }
        return union
    }

    // MARK: 日期标签

    private func dateString(_ date: Date) -> String {
        Self.dateFormatter.locale = Locale(identifier: settings.dateFormat.isEnglish ? "en_US_POSIX" : "zh_CN")
        Self.dateFormatter.dateFormat = settings.dateFormat.template
        return Self.dateFormatter.string(from: date)
    }

    /// 日期字号：随屏幕尺寸自适应，再乘用户字号倍率与整体尺寸
    private func computedDateFontSize() -> CGFloat {
        let scaleValue = CGFloat(max(0.4, min(1.0, settings.scale)))
        let base = max(13, min(bounds.width, bounds.height) * 0.032)
        return base * CGFloat(max(0.3, min(2.5, settings.dateFontScale))) * scaleValue
    }

    private func makeDateFont() -> NSFont {
        settings.fontFamily.makeFont(size: computedDateFontSize(),
                                     weight: NSFont.Weight(rawValue: settings.dateFontWeight.weightValue))
    }

    /// 日期文字属性（含可调字符间距，单位为字号倍数）
    private func dateTextAttributes(font: NSFont) -> [NSAttributedString.Key: Any] {
        let kern = font.pointSize * CGFloat(max(0, settings.dateLetterSpacing))
        return [.font: font, .kern: kern]
    }

    /// 计算日期标签在当前 bounds 内的目标 frame（布局避让与实际摆放共用，保证口径一致）
    private func dateFrame() -> CGRect? {
        guard bounds.width > 2, bounds.height > 2, settings.showDate else { return nil }
        let font = makeDateFont()
        let text = dateString(Date())
        let padX: CGFloat = 6
        let padY: CGFloat = 3
        let attrs = dateTextAttributes(font: font)
        let kern = font.pointSize * CGFloat(max(0, settings.dateLetterSpacing))
        let textSize = (text as NSString).size(withAttributes: attrs)
        // size 会把最后一个字符后的 kern 也算入，居中时扣除，保证视觉居中
        let w = ceil(textSize.width - kern + padX * 2)
        let h = ceil(textSize.height + padY * 2)
        let margin = CGFloat(settings.dateMargin)
            * CGFloat(max(0.4, min(1.0, settings.scale)))
        switch settings.datePosition {
        case .topLeading:
            return CGRect(x: bounds.minX + margin, y: bounds.maxY - margin - h, width: w, height: h)
        case .topCenter:
            return CGRect(x: bounds.midX - w / 2, y: bounds.maxY - margin - h, width: w, height: h)
        case .topTrailing:
            return CGRect(x: bounds.maxX - margin - w, y: bounds.maxY - margin - h, width: w, height: h)
        case .bottomLeading:
            return CGRect(x: bounds.minX + margin, y: bounds.minY + margin, width: w, height: h)
        case .bottomCenter:
            return CGRect(x: bounds.midX - w / 2, y: bounds.minY + margin, width: w, height: h)
        case .bottomTrailing:
            return CGRect(x: bounds.maxX - margin - w, y: bounds.minY + margin, width: w, height: h)
        }
    }

    fileprivate func updateDateLabel() {
        guard let frame = dateFrame() else {
            dateLabel.isHidden = true
            return
        }
        let fontSize = computedDateFontSize()
        let font = makeDateFont()
        let text = dateString(Date())
        let color = NSColor(hex: theme.textHex).withAlphaComponent(0.62)
        let kern = fontSize * CGFloat(max(0, settings.dateLetterSpacing))
        dateLabel.update(text: text, font: font, color: color, kern: kern)
        dateLabel.padding = CGSize(width: 6, height: 3)
        dateLabel.frame = frame
        dateLabel.isHidden = false
    }

    // MARK: 调试 / 测试

    /// 强制把指定组翻到目标文本，用于验证翻页动画
    func debugForceFlip(index: Int = 0, to text: String) {
        guard groupViews.indices.contains(index) else { return }
        groupViews[index].setValue(text, animated: true)
    }
}

// MARK: - 日期标签

final class DateLabelView: NSView {
    private var text: String = ""
    private var drawFont: NSFont = .systemFont(ofSize: 16)
    private var drawColor: NSColor = .white
    private var kern: CGFloat = 0
    var padding: CGSize = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    override var isOpaque: Bool { false }

    func update(text: String, font: NSFont, color: NSColor, kern: CGFloat) {
        let changed = text != self.text
            || font.fontName != drawFont.fontName
            || abs(font.pointSize - drawFont.pointSize) > 0.5
            || abs(kern - self.kern) > 0.01
        self.text = text
        self.drawFont = font
        self.drawColor = color
        self.kern = kern
        if changed { needsDisplay = true }
    }

    private var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byClipping
        return [
            .font: drawFont,
            .foregroundColor: drawColor,
            .paragraphStyle: paragraph,
            .kern: kern
        ]
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty else { return }
        (text as NSString).draw(at: CGPoint(x: padding.width, y: padding.height),
                                withAttributes: attributes)
    }
}

// MARK: - 单个卡片组（时 / 分 / 秒 / AM-PM）

final class FlipGroupView: NSView {

    weak var host: FlipClockView?

    private(set) var value = ""
    private var previousValue: String?
    private var transitionStart: TimeInterval?
    private var transitionDuration: TimeInterval = 0

    init(host: FlipClockView) {
        self.host = host
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contentsFormat = .RGBA16Float
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 不可用") }

    override var isOpaque: Bool { false }

    // MARK: 值更新

    func setValue(_ newValue: String, animated: Bool) {
        guard newValue != value else { return }
        // 没有卡片底板时，翻页半页没有承托面，动画会变成数字叠影，直接切换更干净
        let plateVisible = host?.settings.showCardBackground ?? true
        let enabled = host?.settings.flipEnabled == true && plateVisible
        let duration = (enabled && animated) ? max(0, host?.settings.flipDuration ?? 0) : 0
        if duration > 0 {
            previousValue = value
            value = newValue
            transitionStart = ProcessInfo.processInfo.systemUptime
            transitionDuration = duration
            host?.ensureAnimTimer()
        } else {
            snap(to: newValue)
        }
        needsDisplay = true
    }

    func snap(to newValue: String) {
        value = newValue
        previousValue = nil
        transitionStart = nil
        transitionDuration = 0
        needsDisplay = true
    }

    var isAnimating: Bool {
        guard let start = transitionStart, transitionDuration > 0 else { return false }
        return ProcessInfo.processInfo.systemUptime - start < transitionDuration
    }

    private var isLetter: Bool {
        value.unicodeScalars.contains { !CharacterSet.decimalDigits.contains($0) }
    }

    // MARK: 绘制

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 2, bounds.height > 2 else { return }
        // 每帧先清空整个 bounds：翻叶曾用直角矩形补色，避免圆角外的像素残留
        NSGraphicsContext.current?.cgContext.clear(bounds)
        drawCardSurface()

        if let old = previousValue,
           let start = transitionStart,
           transitionDuration > 0 {
            let p = CGFloat(min(1, max(0,
                (ProcessInfo.processInfo.systemUptime - start) / transitionDuration)))
            if p < 1 {
                drawTransition(from: old, to: value, progress: p)
                drawSeam()
                return
            } else {
                previousValue = nil
                transitionStart = nil
            }
        }
        drawText(value, clippedTo: nil, flapScale: nil, drawFlapSurface: false)
        drawSeam()
    }

    // 卡片底色 / 描边 / 阴影
    private func drawCardSurface() {
        guard let settings = host?.settings, settings.showCardBackground else { return }
        guard let theme = host?.theme else { return }
        let radius = cornerRadius()
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

        let intensity = host?.settings.shadowIntensity ?? 0
        if intensity > 0.001 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(CGFloat(intensity) * 0.9)
            shadow.shadowBlurRadius = 6 + CGFloat(intensity) * 18
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.set()
        }
        NSColor(hex: theme.cardHex).setFill()
        path.fill()

        if let borderHex = theme.borderHex, theme.borderWidth > 0 {
            path.lineWidth = max(1, theme.borderWidth)
            NSColor(hex: borderHex).setStroke()
            path.stroke()
        }
    }

    private func drawSeam() {
        guard let settings = host?.settings,
              settings.flipEnabled, settings.showCardSeams, settings.showCardBackground,
              !isLetter else { return }
        NSColor(hex: host?.theme.seamHex ?? "#000000").withAlphaComponent(0.6).setFill()
        let line = max(1, 1.0 / (window?.backingScaleFactor ?? 2))
        CGRect(x: 0, y: bounds.midY - line / 2, width: bounds.width, height: line).fill()
        // 两位数字之间的竖向分割线
        if value.count == 2 {
            CGRect(x: bounds.midX - line / 2, y: 0, width: line, height: bounds.height).fill()
        }
    }

    private func cornerRadius() -> CGFloat {
        let requested = CGFloat(host?.settings.cornerRadius ?? 0)
        return min(max(0, requested), min(bounds.width, bounds.height) / 2)
    }

    // MARK: 翻页过渡（与参考实现一致的 cos/sin 两段翻叶）

    private func drawTransition(from old: String, to new: String, progress p: CGFloat) {
        let topHalf = CGRect(x: 0, y: bounds.midY, width: bounds.width, height: bounds.height / 2)
        let bottomHalf = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height / 2)

        // 静态背面：上新下旧
        drawText(new, clippedTo: topHalf, flapScale: nil, drawFlapSurface: false)
        drawText(old, clippedTo: bottomHalf, flapScale: nil, drawFlapSurface: false)

        if p < 0.5 {
            // 旧上半页向下合
            let scale = cos(p * .pi)
            drawText(old, clippedTo: topHalf, flapScale: max(0.001, scale), drawFlapSurface: true)
        } else {
            // 新下半页落下
            let scale = sin((p - 0.5) * .pi)
            drawText(new, clippedTo: bottomHalf, flapScale: max(0.001, scale), drawFlapSurface: true)
        }
    }

    /// 绘制文字；可裁剪到某一半、可按翻叶比例绕中轴纵向压缩
    private func drawText(_ text: String,
                          clippedTo clipRect: CGRect?,
                          flapScale: CGFloat?,
                          drawFlapSurface: Bool) {
        guard let theme = host?.theme else { return }
        let attributes = textAttributes(theme: theme)
        let textSize = (text as NSString).size(withAttributes: attributes)

        NSGraphicsContext.saveGraphicsState()
        if let clipRect {
            NSBezierPath(rect: clipRect).addClip()
        }
        if let scale = flapScale, let ctx = NSGraphicsContext.current?.cgContext {
            ctx.translateBy(x: bounds.midX, y: bounds.midY)
            ctx.scaleBy(x: 1, y: scale)
            ctx.translateBy(x: -bounds.midX, y: -bounds.midY)
        }
        if drawFlapSurface, let cardHex = host?.theme.cardHex {
            // 与圆角卡片路径求交，避免翻叶补色溢出到圆角外
            NSBezierPath(roundedRect: bounds, xRadius: cornerRadius(), yRadius: cornerRadius()).addClip()
            NSColor(hex: cardHex).setFill()
            bounds.fill()
        }

        let rect = CGRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2 + bounds.height * 0.015,
            width: textSize.width,
            height: textSize.height)
        (text as NSString).draw(in: rect, withAttributes: attributes)

        if drawFlapSurface, let scale = flapScale {
            let shade = (1 - min(1, max(0, scale))) * 0.38
            NSColor.black.withAlphaComponent(shade).setFill()
            (clipRect ?? bounds).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func textAttributes(theme: ClockTheme) -> [NSAttributedString.Key: Any] {
        let weight = NSFont.Weight(rawValue: host?.settings.fontWeight.weightValue ?? -0.4)
        let fontSize: CGFloat
        if isLetter {
            fontSize = bounds.height * 0.34
        } else {
            let count = max(1, value.count)
            fontSize = min(bounds.height * 0.72,
                           bounds.width / (0.62 * CGFloat(count)))
        }
        let family = host?.settings.fontFamily ?? .sfMono
        let font = family.makeFont(size: max(1, fontSize), weight: weight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        return [
            .font: font,
            .foregroundColor: NSColor(hex: theme.textHex),
            .paragraphStyle: paragraph
        ]
    }
}
