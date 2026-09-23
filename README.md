# AI 平台数据自动发送器

自动从 URL 参数中提取值，填充到 DeepSeek / ChatGPT / 千问页面表单并发送，主要对接 Alfred。

访问 `chat.deepseek.com/?q=你的问题` 时，插件会自动把 `q` 参数的值填入输入框并点击发送。
同时兼容 **Chrome** 与 **Safari**。

## Chrome 使用

1. 打开 `chrome://extensions`，开启右上角「开发者模式」
2. 「加载已解压的扩展程序」选择本目录

## Safari 使用

Safari 无法直接加载扩展文件夹，需要先用 Apple 官方工具把扩展包装成一个 macOS 应用。

### 环境要求

- Xcode（含 `safari-web-extension-converter`）
- Safari **16.4+**（依赖 MV3 service worker 与 `document_start` 内容脚本注入）
- 本仓库的 `safari/` 目录（Xcode 工程，已生成并修好，直接用即可）

### 构建并运行

方式一：命令行（ad-hoc 签名，本机调试用）

```bash
./safari/build-safari.sh
```

方式二：Xcode（推荐，可配置正式签名）

1. 用 Xcode 打开 `safari/AI Autofill/AI Autofill.xcodeproj`
2. 在两个 target 的 Signing & Capabilities 里选择你的开发者账号（免费 Apple ID 即可）
3. Cmd+R 运行，会自动启动应用并引导打开 Safari

### 在 Safari 中启用

1. 运行应用后，打开 Safari → 设置 → 扩展，勾选「AI Autofill」
2. 在扩展详情中授予 `chat.deepseek.com`、`chatgpt.com`、`www.qianwen.com` 的网站访问权限
3. ad-hoc 构建属于"未签名扩展"，需先开启：Safari → 设置 → 高级 →
   勾选「显示针对网页开发者的功能」，然后菜单栏 开发 → 「允许未签名扩展」
   （用 Xcode + 开发者账号构建则不需要此步）

### 源码修改后生效

Xcode 工程直接引用仓库根目录的 `manifest.json` / `content.js` / `background.js` / `popup/`
（未复制副本）。改完源码后重新构建运行，或在 Xcode 中再次 Cmd+R 即可生效。

> ⚠️ 不要随意重新执行 `safari-web-extension-converter` 重新生成工程：
> 生成的工程有两处问题（把 `safari/` 自身当作资源递归打包、app 与扩展的
> bundle ID 大小写不一致导致构建失败），当前 pbxproj 已手工修复，重新生成会丢失修复。

## 两浏览器的兼容实现

- 三个 JS 文件统一通过 `const ext = typeof browser !== "undefined" ? browser : chrome`
  取扩展 API（Safari 以 `browser` 命名空间为主，Chrome 只有 `chrome`）
- `background.js` 中 `tabs.sendMessage` 使用回调式而非 promise 式，兼容各版本 Safari

## 已知限制

- manifest 未配置图标，Safari 中显示默认拼图图标（不影响功能）
