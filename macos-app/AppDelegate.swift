import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 每个请求一个独立窗口，各自持有 WKWebView；窗口关闭时移出数组释放
    private var requestWindows: [RequestWindowController] = []
    private var homeWindow: HomeWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.makeMainMenu()

        // 处理 aiautofill:// URL scheme。App 已在运行时，open 命令也会把事件投递到
        // 这里，因此 URL scheme 是重复调用最可靠的方式；命令行参数只在进程首次启动时可见
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let request = AutofillRequest.parse(Array(CommandLine.arguments.dropFirst())) {
            open(request: request)
            return
        }
        // 无参数启动（Dock / Finder 双击）：稍等片刻再显示主页，
        // 避免通过 URL scheme 拉起 App 时主页窗口闪现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.requestWindows.isEmpty else { return }
            self.showHome()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showHome()
        }
        return true
    }

    // MARK: - 外部入口

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            NSLog("[快问] 收到无法解析的 URL 事件")
            showHome()
            return
        }
        if let request = AutofillRequest.parse(url) {
            open(request: request)
        } else {
            NSLog("[快问] URL 不含有效的 platform 参数: %@", urlString)
            showHome()
        }
    }

    func open(request: AutofillRequest) {
        let controller = RequestWindowController(request: request)
        controller.onClose = { [weak self, weak controller] in
            guard let self, let controller else { return }
            self.requestWindows.removeAll { $0 === controller }
        }
        requestWindows.append(controller)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        activateApp()
    }

    func openPlatformForLogin(_ platform: Platform) {
        open(request: AutofillRequest(platform: platform, message: nil))
    }

    func showHome() {
        if homeWindow == nil {
            let home = HomeWindowController()
            home.onSubmit = { [weak self] request in
                self?.open(request: request)
            }
            home.onOpenPlatform = { [weak self] platform in
                self?.openPlatformForLogin(platform)
            }
            homeWindow = home
        }
        homeWindow?.showWindow(nil)
        homeWindow?.window?.makeKeyAndOrderFront(nil)
        activateApp()
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - 主菜单

    private static func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "快问")
        appMenu.addItem(withTitle: "关于快问", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出快问", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        // undo:/redo:/cut:/copy:/paste: 转发给响应链（文本框、WKWebView 均实现），
        // 用字符串形式避免编译器符号问题
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: Selector(("copy:")), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "全部前置", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        return mainMenu
    }
}
