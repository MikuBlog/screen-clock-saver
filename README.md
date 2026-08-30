# 翻页时钟 ScreenClock（macOS Flip Clock Screensaver）

参考 [Fliqlo 不能用了，我用 Vibe Coding 做了一个更强大的 Mac 屏保软件](https://cloud.tencent.com/developer/article/2713315)（Grace Clock）实现的 macOS 翻页时钟屏保，包含**系统屏保（.saver）**和**带实时预览的设置应用（.app）**两部分。

- 最低系统：**macOS 14 Sonoma**，已在 **macOS 26 Tahoe** 上验证，支持该版本及以上
- 通用二进制：**Apple Silicon + Intel**（arm64 / x86_64）
- 纯 Swift + SwiftUI + Core Animation，无第三方依赖、不联网、不采集数据

## 功能清单

### 时钟
- 三种时钟样式：**翻页数字**（经典 flip）、**极简指针**（12 根刻度、无数字）、**经典指针**（阿拉伯数字表盘 + 红色秒针）；指针款支持秒针平滑扫秒 / 逐秒跳动
- 12 / 24 小时制切换
- 可选显示秒
- 12 小时制下显示 AM / PM 小卡片
- 日期显示（年/月/日，可选是否带周几），支持左上 / 右上 / 左下 / 右下四个角位置与边距微调
- 10 种数字字体：系统等宽、系统圆角、系统衬线、Helvetica Neue、Avenir Next、Futura、DIN Alternate、Menlo、Courier New、Georgia（均为 macOS 自带字体；非等宽字体自动附加等宽数字，秒数跳动不左右抖动）
- 五档数字字重（极细 / 纤细 / 常规 / 中等 / 偏粗）

### 外观
- 6 套内置主题：**经典黑、暖白、黑金、深空灰、极简白、暗夜紫**
- 整体尺寸（50%–100%）
- 亮度（5%–100%，夜间调暗）
- 卡片圆角（0–120pt）
- 卡片间距（0–200pt）
- 阴影强度（0–100%）
- 翻页动画速度（0.2–1.5s）与中央转轴开关
- 卡片分割线开关（可移除水平中缝与两位数字之间的竖线，得到纯净卡片）
- 卡片底板开关（关闭后隐藏全部卡片底色/阴影，只保留数字；此时自动改为直切换字，避免无承托面的翻页叠影）
- 真实的两段式 3D 翻页动画（上半页先落下、下半页再翻下）

### 布局
- 自动 / 横向 / 纵向三种排列，自动模式按屏幕方向选择
- 适配横屏、竖屏、21:9 带鱼屏；预览区默认按「当前屏幕」真实分辨率比例显示（所见即所得），也可切换 16:9 / 21:9 / 4:3 / 9:16
- 开启日期后，时钟自动为日期所在角预留安全区，数字不会压住日期

### 多显示器
- 所有显示器同时显示（每块屏幕独立渲染，避免外接屏黑屏）
- 仅主显示器显示，其余屏幕纯黑

### 其他
- 设置应用内一键安装 / 更新屏保、全屏预览、跳转系统屏保设置
- 所有修改自动保存并**热同步**给正在运行的屏保，无需重装
- 配置导入 / 导出 / 恢复默认
- 配置仅保存在本机：`~/Library/Application Support/ScreenClockSaver/settings.json`

## 项目结构

```
screen-clock-saver/
├── ScreenClock.xcodeproj/        # Xcode 工程（双 Target）
├── Shared/                       # 两个 Target 共享的核心代码
│   ├── ClockSettings.swift       # 配置模型（向前兼容解码）
│   ├── Theme.swift               # 内置主题 + 十六进制颜色
│   ├── SettingsStore.swift       # 共享 JSON 持久化
│   ├── FlipClockView.swift       # 翻页时钟渲染引擎（AppKit + CALayer）
│   └── AnalogClockView.swift     # 指针式表盘（Core Graphics 绘制）
├── Saver/                        # 屏保 Target（ScreenClock.saver）
│   ├── ScreenClockSaverView.swift
│   └── Info.plist
├── Studio/                       # 设置应用 Target（ScreenClockStudio.app）
│   ├── StudioApp.swift / AppModel.swift
│   ├── ContentView.swift         # 总览/时钟/外观/布局/显示器/隐私/关于
│   ├── ClockPreview.swift        # 实时预览（直接复用屏保渲染引擎）
│   ├── SaverInstaller.swift
│   └── Info.plist
├── Scripts/
│   ├── gen_project.py            # 生成 project.pbxproj
│   └── build.sh                  # 免 xcodebuild 的命令行构建脚本
└── build/dist/                   # 构建产物
    ├── ScreenClock.saver
    ├── ScreenClockStudio.app
    └── 翻页时钟.dmg
```

## 构建

### 方式一：Xcode（推荐日常开发）

打开 `ScreenClock.xcodeproj`，选择 Scheme **ScreenClockStudio**，⌘R 运行设置应用；Product > Archive 可出发布包。工程包含两个 Target：

| Target | 产物 | 类型 |
|---|---|---|
| ScreenClockSaver | ScreenClock.saver | `com.apple.product-type.bundle`（wrapper=saver），链接 ScreenSaver.framework |
| ScreenClockStudio | ScreenClockStudio.app | 标准 SwiftUI App，依赖并内嵌 .saver |

> 若 Xcode 提示未同意许可协议，终端执行一次 `sudo xcodebuild -license accept`。

### 方式二：命令行脚本

```bash
./Scripts/build.sh
```

脚本直接调用工具链 `swiftc`（不依赖 xcodebuild、无需 sudo），交叉编译 arm64/x86_64 后用 `lipo` 合成通用二进制，组装 .saver / .app 并 ad-hoc 签名，最后用 `hdiutil` 打出 `build/dist/翻页时钟.dmg`。

## 安装与使用

1. 打开 `ScreenClockStudio.app`（或挂载 DMG 拖入「应用程序」）
2. 在「外观」等面板中调整样式，预览区实时同步
3. 「总览」页点击**安装屏保**，在弹出的系统设置中选择「翻页时钟」
4. 也可以直接双击 `ScreenClock.saver` 安装
5. 系统设置 → 屏幕保护程序中设定启动时间 / 触发角即可

> 本机为 ad-hoc 签名；首次打开若被 Gatekeeper 拦截，右键 → 打开，或「系统设置 → 隐私与安全性」中允许。正式对外分发时替换为开发者 ID 签名并公证即可。

## 常见问题

- **改了样式 / 重装后屏保还是旧样子？** 两层原因，应用已自动处理：
  1. 屏保宿主（`legacyScreenSaver` / `ScreenSaverEngine`）会缓存已加载的 .saver，覆盖安装不会自动重载；「重新安装 / 更新」会自动结束这些宿主进程，下次触发即加载新版本，也可随时点「刷新运行中的屏保」。
  2. 屏保运行在沙盒宿主内，`~` 会被重定向到容器目录；配置读取额外用 `getpwuid` 解析真实用户主目录（宿主拥有 `/` 只读例外），因此设置应用写入的 `settings.json` 能被正确读取。
- **改样式不需要重装**：配置自动保存，正在运行的屏保每 0.25s 检测文件变化并热更新；只有更新程序版本时才需要重新安装。
- 若曾把旧副本放到 `/Library/Screen Savers`（所有用户级），它可能优先生效，总览页会给出提示，删除旧副本即可。

## 技术要点

- **双 Target 共享渲染**：设置应用（SwiftUI 宿主）与系统屏保共用同一个 AppKit 自绘视图 `FlipClockView`。配置写入 `~/Library/Application Support/ScreenClockSaver/settings.json`；由于屏保宿主是沙盒进程、主目录被重定向，`SettingsStore` 同时检查「进程主目录」与 `getpwuid` 得到的真实主目录，按 mtime 取最新，每 0.25s 热更新。
- **翻页动画（drawRect 逐帧方案）**：不使用 CALayer 3D 事务，而是在 `draw(_:)` 中按统一时间进度逐帧重绘——静态层「上新下旧」，翻叶以 `cos/sin` 纵向压缩并叠加明暗渐变，60fps 驱动、动画结束自动停表，因此不存在两段事务之间的跳帧接缝；布局由统一线性约束求解（固定间距被可用空间钳制），任何比例下卡片都完整落在边界内。
- **清晰度**：直接走 AppKit 绘制与窗口 backingScale，Retina 下不发虚。
- **多显示器**：系统为每块屏幕实例化一个 `ScreenSaverView`，各自独立布局；「仅主屏」策略下副屏保持纯黑。
