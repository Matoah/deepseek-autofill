import AppKit

/// 无参数启动时的主页：可手输问题发送，也可仅打开平台页面完成首次登录
final class HomeWindowController: NSWindowController {
    var onSubmit: ((AutofillRequest) -> Void)?
    var onOpenPlatform: ((Platform) -> Void)?

    private let platformControl = NSSegmentedControl()
    private let messageField = NSTextField()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "快问"
        super.init(window: window)
        // buildContentView 里的按钮 target 是 self，须在 super.init 之后构建
        window.contentView = buildContentView()
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildContentView() -> NSView {
        let title = NSTextField(labelWithString: "快问")
        title.font = NSFont.boldSystemFont(ofSize: 16)

        let hint = NSTextField(
            wrappingLabelWithString:
                "输入问题并选择平台后发送，发送窗口内可直接查看 AI 回复。\n"
                + "首次使用请先用下方按钮打开对应平台完成登录（登录态保存在本 App 内，与 Safari / Chrome 不共享）。"
        )
        hint.textColor = .secondaryLabelColor
        hint.font = NSFont.systemFont(ofSize: 12)

        platformControl.trackingMode = .selectOne
        platformControl.segmentCount = Platform.allCases.count
        for (index, platform) in Platform.allCases.enumerated() {
            platformControl.setLabel(platform.displayName, forSegment: index)
        }
        platformControl.selectedSegment = 0

        messageField.placeholderString = "输入要发送给 AI 的问题…"
        messageField.bezelStyle = .roundedBezel
        messageField.translatesAutoresizingMaskIntoConstraints = false
        messageField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let sendButton = NSButton(title: "发送", target: self, action: #selector(submit))
        sendButton.bezelColor = .controlAccentColor
        sendButton.keyEquivalent = "\r"
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setContentHuggingPriority(.required, for: .horizontal)
        sendButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        let inputRow = NSStackView(views: [messageField, sendButton])
        inputRow.orientation = .horizontal
        inputRow.spacing = 8

        let loginTitle = NSTextField(labelWithString: "仅打开平台页面（首次登录用）")
        loginTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)

        let deepseekButton = NSButton(title: "打开 DeepSeek", target: self, action: #selector(openDeepseek))
        let chatgptButton = NSButton(title: "打开 ChatGPT", target: self, action: #selector(openChatGPT))
        let loginRow = NSStackView(views: [deepseekButton, chatgptButton])
        loginRow.orientation = .horizontal
        loginRow.spacing = 8

        let usage = NSTextField(
            wrappingLabelWithString:
                "命令行：open \"快问.app\" --args --platform deepseek --message \"问题\"\n"
                + "URL scheme：aiautofill://send?platform=chatgpt&q=URL编码后的问题\n"
                + "App 运行中重复调用请使用 URL scheme（open --args 不会把参数传给已运行的实例）"
        )
        usage.textColor = .tertiaryLabelColor
        usage.font = .monospacedSystemFont(ofSize: 10, weight: .regular)

        let stack = NSStackView(views: [title, hint, platformControl, inputRow, loginTitle, loginRow, usage])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 440))
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        return content
    }

    // MARK: - 动作

    @objc private func submit() {
        let index = platformControl.selectedSegment
        guard index >= 0, index < Platform.allCases.count else { return }
        let platform = Platform.allCases[index]
        let message = messageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            NSSound.beep()
            return
        }
        window?.orderOut(nil)
        onSubmit?(AutofillRequest(platform: platform, message: message))
    }

    @objc private func openDeepseek() {
        onOpenPlatform?(.deepseek)
    }

    @objc private func openChatGPT() {
        onOpenPlatform?(.chatgpt)
    }
}
