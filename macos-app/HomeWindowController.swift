import AppKit
import WebKit

/// 无参数启动时的主页：WKWebView 加载本地 Home.html（现代卡片式 UI，跟随系统深浅色）。
/// 页面通过 window.webkit.messageHandlers.bridge 与 Swift 通信：
///   submit     {platform, message}  -> onSubmit
///   openPlatform {platform}         -> onOpenPlatform（首次登录用）
final class HomeWindowController: NSWindowController {
    var onSubmit: ((AutofillRequest) -> Void)?
    var onOpenPlatform: ((Platform) -> Void)?

    private var webView: WKWebView?

    /// WKUserContentController.add(_:) 会强引用 handler，
    /// 用独立小对象弱转发回 controller，避免 webView -> contentController -> controller -> window -> webView 的循环
    private final class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
        weak var controller: HomeWindowController?
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            controller?.handle(message: message)
        }
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "快问"
        // 内容延伸到标题栏下，页面背景自绘，视觉上无标题栏边界
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // 主题偏好（light/dark/auto，默认 auto）持久化在 UserDefaults，
        // 注入到页面供 <head> 预置脚本在首帧前应用，避免闪错主题
        let themePref = UserDefaults.standard.string(forKey: Self.themeKey) ?? "auto"
        let initiallyDark = Self.isDark(pref: themePref)
        window.backgroundColor = Self.background(for: initiallyDark)
        window.minSize = NSSize(width: 540, height: 440)
        // WKWebView 会吞掉标题栏区域的鼠标事件，叠加一个原生透明条
        // 作为拖拽区（起始 x 避开左侧交通灯），恢复标题栏拖动窗口的能力
        window.isMovableByWindowBackground = true

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let userContent = configuration.userContentController
        let handler = ScriptMessageHandler()
        userContent.add(handler, name: "bridge")
        userContent.addUserScript(
            WKUserScript(
                source: "window.__themePref = \(Self.quote(themePref));",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 620, height: 520), configuration: configuration)
        webView.underPageBackgroundColor = Self.background(for: initiallyDark)
        self.webView = webView

        super.init(window: window)
        handler.controller = self

        guard let url = Bundle.main.url(forResource: "Home", withExtension: "html") else {
            fatalError("无法加载 Home.html，请检查工程对该文件的资源引用")
        }
        webView.navigationDelegate = self
        window.contentView = webView
        window.center()

        // 标题栏拖拽区覆盖标题栏空白（起始 x 避开左侧交通灯，
        // 右侧留 56pt 给右上角的设置按钮），不拦截网页内容
        let dragArea = TitlebarDragView()
        dragArea.translatesAutoresizingMaskIntoConstraints = false
        webView.addSubview(dragArea)
        NSLayoutConstraint.activate([
            dragArea.topAnchor.constraint(equalTo: webView.topAnchor),
            dragArea.leadingAnchor.constraint(equalTo: webView.leadingAnchor, constant: 84),
            dragArea.trailingAnchor.constraint(equalTo: webView.trailingAnchor, constant: -56),
            dragArea.heightAnchor.constraint(equalToConstant: 40),
        ])

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 标题栏拖拽区：fullSizeContentView 下 WKWebView 会吞掉标题栏区域的鼠标事件，
    /// 叠加原生透明条，mouseDown 直接交给窗口执行拖动（performDrag 不依赖
    /// isMovableByWindowBackground 对"视图是否处理事件"的判定，行为最确定）
    private final class TitlebarDragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    // MARK: - 主题

    private static let themeKey = "HomeTheme"

    /// 深色 = 显式深色，或跟随系统且系统为深色
    private static func isDark(pref: String) -> Bool {
        if pref == "dark" { return true }
        if pref == "light" { return false }
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// 与 Home.html 背景渐变的中段色保持一致，避免窗口缩放/滚动时的底色闪变
    private static func background(for dark: Bool) -> NSColor {
        dark
            ? NSColor(srgbRed: 0.10, green: 0.082, blue: 0.247, alpha: 1)
            : NSColor(srgbRed: 0.937, green: 0.918, blue: 0.976, alpha: 1)
    }

    /// JSON 风格引号包裹（偏好值是固定三选一的内部字符串）
    private static func quote(_ raw: String) -> String {
        "\"" + raw.replacingOccurrences(of: "\"", with: "") + "\""
    }

    // MARK: - 页面消息

    private func handle(message: WKScriptMessage) {
        // WKScriptMessage.name 恒为处理器注册名 "bridge"，
        // 语义消息名由页面放在 body["name"] 里
        guard let body = message.body as? [String: Any],
              let name = body["name"] as? String else { return }
        let platform = (body["platform"] as? String).flatMap(Platform.parse)

        switch name {
        case "submit":
            guard let platform else { return }
            let text = (body["message"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            window?.orderOut(nil)
            onSubmit?(AutofillRequest(platform: platform, message: text))
        case "openPlatform":
            guard let platform else { return }
            onOpenPlatform?(platform)
        case "setTheme":
            // 页面主题选择，持久化后重启仍生效
            if let value = body["value"] as? String,
               ["light", "dark", "auto"].contains(value) {
                UserDefaults.standard.set(value, forKey: Self.themeKey)
            }
        case "themeApplied":
            // 页面实际深浅态变化，同步窗口底色避免缩放闪色
            if let dark = body["dark"] as? Bool {
                window?.backgroundColor = Self.background(for: dark)
                webView?.underPageBackgroundColor = Self.background(for: dark)
            }
        default:
            break
        }
    }
}

extension HomeWindowController: WKNavigationDelegate {
    /// 加载完成后聚焦输入框（WKWebView 不一定执行页面 autofocus）
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("window.__focusInput && __focusInput()")
    }
}
