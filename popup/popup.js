// Safari 的扩展API以 browser 命名空间为主（16.4 起也提供 chrome），
// Chrome/Edge 只有 chrome。统一取可用的那个，保持双浏览器兼容
const ext = typeof browser !== 'undefined' ? browser : chrome;

document.addEventListener('DOMContentLoaded', function() {
    const toggleSwitch = document.getElementById('toggleSwitch');
    const statusText = document.getElementById('statusText');
    const targetSiteInput = document.getElementById('targetSite');
    const paramNameInput = document.getElementById('paramName');
    const saveBtn = document.getElementById('saveBtn');
    const testBtn = document.getElementById('testBtn');

    // 加载设置
    ext.storage.local.get(
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

        ext.runtime.sendMessage({
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

        ext.storage.local.set(config, function() {
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
        ext.tabs.query({ active: true, currentWindow: true }, function(tabs) {
            const currentTab = tabs[0];

            // Safari下未授权站点的tab可能拿不到url，先判空
            if (currentTab.url && currentTab.url.includes('chat.deepseek.com')) {
                // 发送消息给content script执行填充
                ext.tabs.sendMessage(currentTab.id, {
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