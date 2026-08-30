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
                let size = fittedSize(container: geo.size, aspect: ratio.aspect)
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.12))
                    ClockPreview(settings: model.settings)
                        .frame(width: size.width, height: size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                        )
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 320)
        }
    }

    private func fittedSize(container: CGSize, aspect: CGFloat) -> CGSize {
        let width = min(container.width, container.height * aspect)
        return CGSize(width: width, height: width / aspect)
    }
}
