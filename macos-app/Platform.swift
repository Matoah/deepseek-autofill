import Foundation

enum Platform: String, CaseIterable {
    case deepseek
    case chatgpt
    case qianwen

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .chatgpt: return "ChatGPT"
        case .qianwen: return "千问"
        }
    }

    var baseURL: URL {
        switch self {
        case .deepseek: return URL(string: "https://chat.deepseek.com/")!
        case .chatgpt: return URL(string: "https://chatgpt.com/")!
        case .qianwen: return URL(string: "https://www.qianwen.com/chat")!
        }
    }

    /// 目标地址。带 query 时附加 ?q= 参数：content.js 会在 document_start
    /// 阶段把它缓存进 sessionStorage，再驱动页面填充与发送。
    /// 千问比较特殊：页面原生支持 ?q= 自动发送（未登录的匿名会话也可发送），
    /// content.js 仅在原生发送未生效时才走脚本兜底
    func url(query: String?) -> URL {
        guard let query, !query.isEmpty else {
            return baseURL
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url!
    }

    static func parse(_ raw: String) -> Platform? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "deepseek", "ds", "deep":
            return .deepseek
        case "chatgpt", "gpt", "openai":
            return .chatgpt
        case "qianwen", "qwen", "qw":
            return .qianwen
        default:
            return nil
        }
    }
}

/// 一次自动发送请求：平台 + 用户消息（message 为 nil 表示仅打开平台页面，用于登录）
struct AutofillRequest {
    let platform: Platform
    let message: String?

    /// 解析命令行参数：--platform/-p X、--message/-m/--msg/-q X、--platform=X 形式，
    /// 也接受完整的 aiautofill:// URL 作为单个参数
    static func parse(_ arguments: [String]) -> AutofillRequest? {
        var values: [String: String] = [:]

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            let lower = arg.lowercased()

            if lower.hasPrefix("aiautofill:"), let url = URL(string: arg), let request = parse(url) {
                return request
            }

            var name: String?
            var value: String?
            let messageFlags = ["--message", "--msg", "-m", "-q"]
            if lower == "--platform" || lower == "-p" {
                name = "platform"
                value = index + 1 < arguments.count ? arguments[index + 1] : nil
                index += 2
            } else if lower.hasPrefix("--platform=") {
                name = "platform"
                value = String(arg.dropFirst("--platform=".count))
                index += 1
            } else if messageFlags.contains(lower) {
                name = "message"
                value = index + 1 < arguments.count ? arguments[index + 1] : nil
                index += 2
            } else if lower.hasPrefix("--message=") || lower.hasPrefix("--msg=") {
                name = "message"
                value = arg.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                    .dropFirst().first.map(String.init)
                index += 1
            } else {
                index += 1
            }

            if let name, let value {
                values[name] = value
            }
        }

        guard let platform = values["platform"].flatMap(Platform.parse) else {
            return nil
        }
        let message = values["message"]
        return AutofillRequest(platform: platform, message: (message?.isEmpty == true) ? nil : message)
    }

    /// 解析 aiautofill://send?platform=deepseek&q=... （Alfred / 脚本经 open 调用）
    static func parse(_ url: URL) -> AutofillRequest? {
        guard url.scheme?.lowercased() == "aiautofill",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let host = components.host?.lowercased()
        guard host == nil || host == "send" || host == "open" else {
            return nil
        }

        let items = components.queryItems ?? []
        func firstValue(_ names: String...) -> String? {
            for name in names {
                if let item = items.first(where: { $0.name == name }) {
                    return item.value
                }
            }
            return nil
        }

        guard let platform = firstValue("platform", "p").flatMap(Platform.parse) else {
            return nil
        }
        // host 为 open 时仅打开平台页面（登录用），忽略消息
        let message = host == "open" ? nil : firstValue("q", "message", "msg")
        return AutofillRequest(platform: platform, message: (message?.isEmpty == true) ? nil : message)
    }
}
