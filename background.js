// 监听标签页更新
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (
        changeInfo.status === 'complete' &&
        tab.url &&
        tab.url.includes('chat.deepseek.com')
    ) {
        // 可以在这里执行一些后台逻辑
        console.log('目标页面已加载完成:', tab.url);

        // 如果需要，可以发送消息给content script
        chrome.tabs.sendMessage(tabId, {
            action: 'pageLoaded',
            url: tab.url
        }).catch(() => {
            // content script可能还没加载，忽略错误
        });
    }
});

// 监听扩展安装
chrome.runtime.onInstalled.addListener(() => {
    console.log('扩展已安装');

    // 设置默认配置
    chrome.storage.local.set({
        autoFillEnabled: true,
        targetWebsite: 'chat.deepseek.com',
        queryParamName: 'q'
    });
});

// 监听来自popup的消息
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'getStatus') {
        chrome.storage.local.get(['autoFillEnabled'], (result) => {
            sendResponse({ enabled: result.autoFillEnabled });
        });
        return true;
    }

    if (request.action === 'toggleAutoFill') {
        chrome.storage.local.set({ autoFillEnabled: request.enabled });
        sendResponse({ success: true });
    }
});