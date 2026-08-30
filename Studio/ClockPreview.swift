//
//  ClockPreview.swift
//  设置应用中的实时预览：直接复用屏保的 FlipClockView，所见即所得
//

import SwiftUI
import AppKit

struct ClockPreview: NSViewRepresentable {
    let settings: ClockSettings

    func makeNSView(context: Context) -> FlipClockView {
        FlipClockView()
    }

    func updateNSView(_ nsView: FlipClockView, context: Context) {
        nsView.apply(settings)
    }
}

enum PreviewRatio: String, CaseIterable, Identifiable {
    case currentScreen
    case wide169
    case ultra219
    case standard43
    case vertical916

    var id: String { rawValue }

    /// 主屏物理像素尺寸（点尺寸 × 缩放系数）
    static func mainScreenPixelSize() -> (width: Int, height: Int) {
        guard let screen = NSScreen.main else { return (0, 0) }
        let scale = screen.backingScaleFactor
        return (Int((screen.frame.width * scale).rounded()),
                Int((screen.frame.height * scale).rounded()))
    }

    var label: String {
        switch self {
        case .currentScreen:
            let (w, h) = Self.mainScreenPixelSize()
            return w > 0 ? "当前屏幕 \(w)×\(h)" : "当前屏幕"
        case .wide169: return "16:9 宽屏"
        case .ultra219: return "21:9 带鱼屏"
        case .standard43: return "4:3 标准"
        case .vertical916: return "9:16 竖屏"
        }
    }
    var aspect: CGFloat {
        switch self {
        case .currentScreen:
            guard let screen = NSScreen.main, screen.frame.height > 0 else {
                return 16.0 / 9.0
            }
            return screen.frame.width / screen.frame.height
        case .wide169: return 16.0 / 9.0
        case .ultra219: return 21.0 / 9.0
        case .standard43: return 4.0 / 3.0
        case .vertical916: return 9.0 / 16.0
        }
    }
}

struct PreviewStage: View {
    @EnvironmentObject var model: AppModel
    @State private var ratio: PreviewRatio = .currentScreen

    /// 预览的虚拟画布尺寸（pt）。
    /// 关键：必须用接近真实显示器的点尺寸来布局，再整体缩放进预览框——
    /// 否则卡片间距 / 圆角 / 日期边距等固定磅值会在小画布上被相对放大，
    /// 导致预览布局与真机屏保不一致。
    private func virtualSize(for item: PreviewRatio) -> CGSize {
        if item == .currentScreen,
           let screen = NSScreen.main, screen.frame.height > 0 {
            // 与屏保实际运行时的 bounds 完全一致
            return screen.frame.size
        }
        // 预设比例统一以 1200pt 高为虚拟显示器
        let height: CGFloat = 1200
        return CGSize(width: height * item.aspect, height: height)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("时钟预览", systemImage: "display")
                    .font(.headline)
                Spacer()
                Picker("显示器比例", selection: $ratio) {
                    ForEach(PreviewRatio.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            GeometryReader { geo in
                let virtual = virtualSize(for: ratio)
                let scale = min(geo.size.width / virtual.width,
                                geo.size.height / virtual.height)
                // 缩放后的实际占位
                let shown = CGSize(width: virtual.width * scale,
                                   height: virtual.height * scale)
                // 以真实屏幕点尺寸布局，再等比缩小，保证与真机 1:1 同构
                ClockPreview(settings: model.settings)
                    .frame(width: virtual.width, height: virtual.height)
                    .scaleEffect(scale)
                    .frame(width: shown.width, height: shown.height)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 320)
        }
    }
}
