// WKWebView 注入环境没有浏览器扩展运行时（chrome / browser 命名空间）。
// content.js 尾部会注册 ext.runtime.onMessage 以支持 popup 手动触发，
// 这里补一套空实现，让脚本可以原样运行而不抛 ReferenceError。
// 注意：本文件必须先于 content.js 注入（RequestWindowController 按顺序 addUserScript）。
if (typeof browser === "undefined" && typeof chrome === "undefined") {
  const noop = function () {};
  const stub = {
    runtime: {
      onMessage: { addListener: noop },
      onInstalled: { addListener: noop },
      sendMessage: noop,
    },
    storage: {
      local: {
        get: function (_keys, callback) {
          if (callback) callback({});
        },
        set: function (_items, callback) {
          if (callback) callback();
        },
      },
    },
    tabs: {
      onUpdated: { addListener: noop },
      sendMessage: function (_tabId, _message, callback) {
        if (callback) callback();
      },
    },
  };
  globalThis.chrome = stub;
  globalThis.browser = stub;
}
