# 快问（macOS App 版）

**快问**（英文名 AI Autofill）：把仓库根目录的浏览器扩展（DeepSeek / ChatGPT 自动填充发送）
封装成独立 macOS App：内嵌 WKWebView 打开 AI 平台页面，注入**同一份** `content.js`
完成自动填充与发送，窗口内直接查看 AI 回复。

**不改动扩展任何现有代码**：Xcode 工程通过 `../content.js` 相对路径引用仓库根目录的
content.js（构建时原样拷入 App bundle），填充/发送逻辑与 Chrome / Safari 扩展共用同一份源码。

## 构建

```bash
cd macos-app
./build.sh              # 默认 Release，产物在 macos-app/build/快问.app
./build.sh Debug        # 调试构建
```

也可以用 Xcode 直接打开 `AutofillApp.xcodeproj` 构建。无开发者证书也能构建（ad-hoc 签名）。

## 图标

图标由 [make-icon.swift](make-icon.swift) 矢量绘制：macOS 模板圆角矩形 + 蓝紫渐变（沿飞行方向）+
白色纸飞机（自动"发送"），共 10 个尺寸写入 `Assets.xcassets/AppIcon.appiconset/`。
想调整颜色、角度、大小时改脚本顶部"设计参数"后重新生成并构建：

```bash
swift make-icon.swift && ./build.sh
```

设计稿预览：[icon512@2x.png（1024px）](Assets.xcassets/AppIcon.appiconset/icon512@2x.png)

## 使用

### 首次使用：登录

登录态保存在 App 自己的 WKWebView 数据存储中，**与 Safari / Chrome 不共享**。
无参数启动 App（显示主页），点"打开 DeepSeek / 打开 ChatGPT"，在弹出的窗口中完成登录，
之后跨启动保持登录。

### 发送问题（三种方式）

1. **App 主页手输**：无参数启动 App，选平台、输问题、发送。

2. **命令行参数**（仅进程首次启动时有效；App 已在运行时 `open --args` 不会传入参数）：
   ```bash
   open "macos-app/build/快问.app" --args --platform deepseek --message "你的问题"
   # 支持 --platform=deepseek / -p / -m 等简写；platform 别名：deepseek/ds、chatgpt/gpt/openai
   ```

3. **URL scheme**（推荐，Alfred / 脚本集成用这个，App 是否在运行都有效）：
   ```bash
   open 'aiautofill://send?platform=chatgpt&q=%E4%BD%A0%E5%A5%BD'
   # q 需要 URL 编码（Alfred 的 Open URL action 可自动处理）
   # aiautofill://open?platform=deepseek 表示仅打开平台页面（登录用）
   ```

每次调用新开一个窗口，窗口内自动填充并发送，等待查看 AI 回复即可。

## Alfred 集成

已在本机 Alfred 5 安装「快问」workflow（仓库备份：[alfred/快问/](alfred/快问/)，
可导入包 [alfred/快问.alfredworkflow](alfred/快问.alfredworkflow)，双击即可重装）：

- 呼出 Alfred，输入 `ds` + 空格 + 问题，回车 → 打开快问 App，自动填充并发送给 DeepSeek
  ```text
  ds macmini m4建议升级到macos27吗?
  ```
- `gpt` + 空格 + 问题 → 同上，发送给 ChatGPT

结构：Keyword 输入（`ds` / `gpt`，带参数）→ **Open URL** 动作：

```text
aiautofill://send?platform=ds&q={query}
aiautofill://send?platform=chatgpt&q={query}
```

Open URL 动作默认对 `{query}` 做 URL 编码（`skipqueryencode=0`），中文、空格、
`&`、`#` 等都会被正确转义，正好满足 App 侧 URL scheme 的要求。

不想用 workflow 的话，也可以在 Alfred 设置 → Features → Web Search → Add Custom Search
添加同样的 URL，关键词设为 `ds`，效果相同。

## 与浏览器扩展的关系

| 组件 | App 中的角色 |
| --- | --- |
| `../content.js` | 原样注入 WKWebView（`atDocumentStart`，与扩展 manifest 的 `document_start` 时机一致，赶在 SPA 清掉 `?q=` 之前缓存参数） |
| `AutofillShim.js` | 先于 content.js 注入，为 `browser` / `chrome` 扩展命名空间补空实现（WKWebView 无扩展运行时） |
| `background.js` / `popup/` / `manifest.json` | 不使用（标签监听、开关配置等职责由 App 自身承担） |

两个 AI 平台改版导致选择器失效时，直接修根目录 `content.js` 后重新 `./build.sh`，
Chrome / Safari / App 三端同时生效。

## 常见问题

- **ChatGPT 用 Google 登录被拦**（"此浏览器或应用可能不安全"）：App 默认已伪装 Safari UA，
  仍被拦时可换成你自己 Safari 的 UA：
  ```bash
  defaults write com.matoah.ai-autofill.app CustomUserAgent "Mozilla/5.0 (Macintosh; ...) Safari/..."
  ```
  或改用邮箱验证码登录。
- **调试页面**：App 已开启 WKWebView inspectable，页面内右键 →"检查元素"。
- **清除登录 / 站点数据**：退出 App 后删除 `~/Library/WebKit/com.matoah.ai-autofill.app`，
  重启 App 重新登录。
