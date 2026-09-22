import AppKit
import WebKit

/// 一个请求窗口 = 一个 WKWebView。
/// 复用扩展的 content.js：以 atDocumentStart 时机注入（与扩展 manifest 的
/// document_start 一致，保证赶在 SPA 清掉 ?q= 之前把参数缓存进 sessionStorage），
/// 填充、等按钮启用、点击发送、防重发的逻辑全部原样生效
final class RequestWindowController: NSWindowController {
    var onClose: (() -> Void)?
    private var webView: WKWebView?

    /// WKWebView 默认 UA 不含 Safari 标识，Google 登录可能拦截嵌入式 WebView，
    /// 默认伪装成 Safari；可用以下命令覆盖：
    /// defaults write com.matoah.ai-autofill.app CustomUserAgent "..."
    private static let defaultUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/620.1.16 (KHTML, like Gecko) Version/18.4 Safari/620.1.16"

    init(request: AutofillRequest) {
        let configuration = WKWebViewConfiguration()
        // 默认（磁盘持久化）数据存储：登录态在本 App 内跨启动保留。
        // 注意与 Safari / Chrome 不共享 cookie，首次需在 App 内登录
        configuration.websiteDataStore = .default()

        let userContent = WKUserContentController()
        // 顺序敏感：先注入 shim（补齐 browser/chrome 扩展 API 的空实现），
        // 再注入根目录的 content.js 原文
        for resourceName in ["AutofillShim", "content"] {
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "js"),
                  let source = try? String(contentsOf: url, encoding: .utf8) else {
                // content.js 由 Xcode 工程以 ../content.js 相对路径引用仓库根目录同名文件，
                // 加载失败通常是根目录文件被移动或工程引用损坏
                fatalError("无法加载注入脚本 \(resourceName).js，请检查工程对该文件的资源引用")
            }
            userContent.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
        }
        configuration.userContentController = userContent

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1100, height: 780), configuration: configuration)
        webView.customUserAgent = UserDefaults.standard.string(forKey: "CustomUserAgent") ?? Self.defaultUserAgent
        if #available(macOS 13.3, *) {
            // 页面内右键可"检查元素"，方便站点改版后排查选择器
            webView.isInspectable = true
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = request.platform.displayName
            + (request.message.map { " — " + String($0.prefix(48)) } ?? "")
        window.minSize = NSSize(width: 520, height: 420)
        window.contentView = webView
        window.center()

        super.init(window: window)
        self.webView = webView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        let targetURL = request.platform.url(query: request.message)
        NSLog("[快问] 打开窗口：%@ -> %@", request.platform.displayName, targetURL.absoluteString)
        webView.load(URLRequest(url: targetURL))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: notification.object)
        webView = nil
        onClose?()
    }
}
