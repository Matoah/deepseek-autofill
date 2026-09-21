document.addEventListener('DOMContentLoaded', function() {
    const toggleSwitch = document.getElementById('toggleSwitch');
    const statusText = document.getElementById('statusText');
    const targetSiteInput = document.getElementById('targetSite');
    const paramNameInput = document.getElementById('paramName');
    const saveBtn = document.getElementById('saveBtn');
    const testBtn = document.getElementById('testBtn');

    // 加载设置
    chrome.storage.local.get(
        ['autoFillEnabled', 'targetWebsite', 'queryParamName'],
        function(result) {
            toggleSwitch.checked = result.autoFillEnabled !== false;
            updateStatusText(result.autoFillEnabled);

            if (result.targetWebsite) {
                targetSiteInput.value = result.targetWebsite;
            }

            if (result.queryParamName) {
                paramNameInput.value = result.queryParamName;
            }
        }
    );

    // 更新状态文字
    function updateStatusText(enabled) {
        statusText.textContent = enabled ? '已启用' : '已禁用';
        statusText.style.color = enabled ? '#34a853' : '#ea4335';
    }

    // 切换开关
    toggleSwitch.addEventListener('change', function() {
        const enabled = this.checked;
        updateStatusText(enabled);

        chrome.runtime.sendMessage({
            action: 'toggleAutoFill',
            enabled: enabled
        });
    });

    // 保存配置
    saveBtn.addEventListener('click', function() {
        const config = {
            targetWebsite: targetSiteInput.value.trim(),
            queryParamName: paramNameInput.value.trim()
        };

        chrome.storage.local.set(config, function() {
            // 显示保存成功提示
            const originalText = saveBtn.textContent;
            saveBtn.textContent = '✓ 已保存';
            saveBtn.style.backgroundColor = '#34a853';

            setTimeout(() => {
                saveBtn.textContent = originalText;
                saveBtn.style.backgroundColor = '#1a73e8';
            }, 1500);
        });
    });

    // 手动测试
    testBtn.addEventListener('click', function() {
        chrome.tabs.query({ active: true, currentWindow: true }, function(tabs) {
            const currentTab = tabs[0];

            if (currentTab.url.includes('chat.deepseek.com')) {
                // 发送消息给content script执行填充
                chrome.tabs.sendMessage(currentTab.id, {
                    action: 'executeAutoFill'
                }, function(response) {
                    if (response && response.success) {
                        alert('测试指令已发送');
                    } else {
                        alert('请刷新页面后重试');
                    }
                });
            } else {
                alert('请先打开 chat.deepseek.com 页面');
            }
        });
    });
});