// Safari 的扩展API以 browser 命名空间为主（16.4 起也提供 chrome），
// Chrome/Edge 只有 chrome。统一取可用的那个，保持双浏览器兼容
const ext = typeof browser !== "undefined" ? browser : chrome;

// 监听标签页更新
ext.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (
        changeInfo.status === 'complete' &&
        tab.url &&
        tab.url.includes('chat.deepseek.com')
    ) {
        // 可以在这里执行一些后台逻辑
        console.log('目标页面已加载完成:', tab.url);

        // 如果需要，可以发送消息给content script
        // 用回调式而非promise式：部分Safari版本的扩展API不返回promise
        ext.tabs.sendMessage(tabId, {
            action: 'pageLoaded',
            url: tab.url
        }, () => {
            // content script可能还没加载，忽略错误
        });
    }
});

// 监听扩展安装
ext.runtime.onInstalled.addListener(() => {
    console.log('扩展已安装');

    // 设置默认配置
    ext.storage.local.set({
        autoFillEnabled: true,
        targetWebsite: 'chat.deepseek.com',
        queryParamName: 'q'
    });
});

// 监听来自popup的消息
ext.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'getStatus') {
        ext.storage.local.get(['autoFillEnabled'], (result) => {
            sendResponse({ enabled: result.autoFillEnabled });
        });
        return true;
    }

    if (request.action === 'toggleAutoFill') {
        ext.storage.local.set({ autoFillEnabled: request.enabled });
        sendResponse({ success: true });
    }
});