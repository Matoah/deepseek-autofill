import AppKit

// 入口：手工启动 NSApplication（不用 storyboard / @main，
// 方便完全掌控命令行参数解析与 URL scheme 的 Apple Event 处理）
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
