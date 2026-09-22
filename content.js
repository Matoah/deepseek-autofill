/**
 * 从URL中获取query参数值
 * @param {string} paramName - 参数名
 * @returns {string|null} - 参数值
 */
function getQueryParam(paramName) {
  const url = new URL(window.location.href);
  return url.searchParams.get(paramName);
}

/**
 * 从URL中获取query参数值（带缓存）
 * SPA（如DeepSeek）加载后会把URL中的查询参数清掉，
 * 首次读到时缓存到sessionStorage，后续URL参数消失时从缓存读取
 * @param {string} paramName - 参数名
 * @returns {string|null} - 参数值
 */
function getQueryParamCached(paramName) {
  const cacheKey = "autofill_cached_" + paramName;
  const fromUrl = getQueryParam(paramName);
  if (fromUrl) {
    // 新的参数值进入（重新带参打开），清除上一次的已发送标记
    if (sessionStorage.getItem(cacheKey) !== fromUrl) {
      sessionStorage.removeItem("autofill_sent_" + paramName);
    }
    sessionStorage.setItem(cacheKey, fromUrl);
    return fromUrl;
  }
  return sessionStorage.getItem(cacheKey);
}

/**
 * 等待元素出现
 * @param {string} selector - CSS选择器
 * @param {number} timeout - 超时时间（毫秒）
 * @returns {Promise<Element>} - 元素
 */
function waitForElement(selector, timeout = 10000) {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();

    function check() {
      const element = document.querySelector(selector);
      if (element) {
        resolve(element);
        return;
      }

      if (Date.now() - startTime > timeout) {
        reject(new Error(`元素 ${selector} 未在 ${timeout}ms 内找到`));
        return;
      }

      setTimeout(check, 100);
    }

    check();
  });
}

function searchSendButton(timeout = 10000) {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();
    let warnedFileInput = false;
    let warnedContainer = false;
    let warnedButton = false;
    let lastClass = null;

    function check() {
      const fileInput = document.querySelector("input[type='file']");
      if (!fileInput) {
        if (!warnedFileInput) {
          warnedFileInput = true;
          console.warn("[autofill] 未找到 input[type='file']，继续轮询...");
        }
      } else {
        // 查找type为file的元素后的div元素，在其中查找role为button的子元素
        let container = fileInput.nextElementSibling;
        while (container && container.tagName !== "DIV") {
          container = container.nextElementSibling;
        }
        if (!container) {
          if (!warnedContainer) {
            warnedContainer = true;
            console.warn(
              "[autofill] fileInput后未找到div兄弟元素，其父元素的子节点为:",
              Array.from(fileInput.parentNode.children).map(
                (el) => `<${el.tagName.toLowerCase()} class="${el.className}">`,
              ),
            );
          }
        } else {
          const button = container.querySelector("[role='button']");
          if (!button) {
            if (!warnedButton) {
              warnedButton = true;
              console.warn(
                "[autofill] 容器div内未找到 [role='button']，容器innerHTML前300字符:",
                container.innerHTML.substring(0, 300),
              );
            }
          } else {
            // class有变化时打印，观察禁用态何时移除
            if (button.className !== lastClass) {
              lastClass = button.className;
              console.log("[autofill] 发送按钮class:", button.className || "(空)");
            }
            // 监听其class，等ds-button--disabled不存在（按钮启用）后再返回
            if (!button.classList.contains("ds-button--disabled")) {
              console.log("[autofill] 按钮已启用，class:", button.className);
              resolve(button);
              return;
            }
          }
        }
      }

      if (Date.now() - startTime > timeout) {
        reject(new Error("发送按钮未找到或未启用"));
        return;
      }

      setTimeout(check, 100);
    }

    check();
  });
}

async function autoSendQuestionInDeepseek(queryValue) {
  console.log("[autofill] Deepseek流程开始，queryValue:", queryValue);

  // 1. 等待textarea加载完成
  const textarea = await waitForElement("textarea");
  console.log("[autofill] 找到textarea，class:", textarea.className);

  if (textarea) {
    // React受控组件：直接修改value属性不会更新其内部state，
    // 需通过原生value setter赋值后再触发input事件，发送按钮才会启用
    const nativeSetValue = Object.getOwnPropertyDescriptor(
      HTMLTextAreaElement.prototype,
      "value",
    ).set;
    nativeSetValue.call(textarea, queryValue);
    textarea.dispatchEvent(new Event("input", { bubbles: true }));
    textarea.dispatchEvent(new Event("change", { bubbles: true }));
    console.log("[autofill] 已通过原生setter赋值并触发input/change事件，textarea.value:", textarea.value);
  }

  // 2. 等待发送按钮启用（ds-button--disabled不存在）后触发点击事件（向上冒泡）
  const button = await searchSendButton();

  if (button) {
    console.log(
      "[autofill] 准备派发click事件，按钮outerHTML:",
      button.outerHTML.substring(0, 300),
    );
    button.dispatchEvent(
      new MouseEvent("click", {
        view: window,
        bubbles: true,
        cancelable: true,
      }),
    );
    console.log("[autofill] click事件已派发");

    // 1秒后检查点击效果：发送成功时textarea通常被清空、按钮回到禁用态
    setTimeout(() => {
      console.log(
        "[autofill] 点击1秒后状态 - textarea.value:",
        JSON.stringify(textarea.value),
        "；按钮class:",
        button.className,
        "；按钮是否还在DOM中:",
        document.contains(button),
      );
    }, 1000);
  } else {
    console.warn("未找到符合条件的按钮");
  }
}

async function autoSendQuestionInChatGPT(queryValue) {
  console.log("[autofill] ChatGPT流程开始，queryValue:", queryValue);

  // 1. 等待输入框加载完成（ProseMirror富文本编辑器，contenteditable div）
  const editor = await waitForElement(
    "#prompt-textarea, div[contenteditable='true']",
  );
  console.log("[autofill] 找到输入框，id:", editor.id, "，class:", editor.className);

  // 2. 聚焦输入框并把光标移到末尾
  editor.focus();
  const range = document.createRange();
  range.selectNodeContents(editor);
  range.collapse(false);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);

  // 3. 通过execCommand插入文本。
  // ChatGPT输入框是ProseMirror编辑器，直接改innerText只改DOM不产生input事件，
  // 编辑器内部state不更新、发送按钮不会启用；execCommand('insertText')走浏览器
  // 原生输入管线，触发beforeinput/input事件，与真实键入一致。
  // 先selectAll再插入，覆盖ChatGPT恢复的草稿或原生?q=预填，保证内容就是q
  document.execCommand("selectAll", false, null);
  const inserted = document.execCommand("insertText", false, queryValue);
  console.log(
    "[autofill] execCommand insertText返回:",
    inserted,
    "，当前输入框文本:",
    JSON.stringify(editor.textContent),
  );

  // 4. 等待发送按钮出现并启用后点击。输入框有内容时才会渲染send-button
  // （为空时该位置是语音按钮），按钮出现也意味着编辑器state已更新
  const button = await waitForElement(
    "button[data-testid='send-button']:not([disabled])",
  );
  console.log(
    "[autofill] 发送按钮已启用，outerHTML:",
    button.outerHTML.substring(0, 300),
  );
  button.click();
  console.log("[autofill] 已点击发送按钮");

  // 5. 1秒后检查发送效果：成功时输入框会被清空；未清空则派发Enter键兜底
  await new Promise((resolve) => setTimeout(resolve, 1000));
  if (!editor.textContent.trim()) {
    console.log("[autofill] 发送成功，输入框已清空");
    return;
  }
  console.warn(
    "[autofill] 点击后输入框未清空，派发Enter键兜底，剩余文本:",
    JSON.stringify(editor.textContent),
  );
  editor.dispatchEvent(
    new KeyboardEvent("keydown", {
      key: "Enter",
      code: "Enter",
      bubbles: true,
      cancelable: true,
    }),
  );
  await new Promise((resolve) => setTimeout(resolve, 1000));
  console.log(
    "[autofill] Enter兜底后输入框文本:",
    JSON.stringify(editor.textContent),
  );
}

// 跳过原因只打印一次，避免MutationObserver高频触发导致刷屏
const skipLogShown = {};
function logSkipOnce(reason) {
  if (!skipLogShown[reason]) {
    skipLogShown[reason] = true;
    console.log("[autofill] 跳过：", reason);
  }
}

/**
 * 主函数 - 执行自动填充
 */
async function autoFillPage() {
  try {
    // 1. 获取query参数值（URL参数被SPA清掉后从sessionStorage缓存读取）
    const queryValue = getQueryParamCached("q");

    if (!queryValue) {
      logSkipOnce("URL无q参数且sessionStorage中无缓存");
      return;
    }

    // 同一个问题（同一标签页会话）只自动发送一次
    if (sessionStorage.getItem("autofill_sent_q") === queryValue) {
      logSkipOnce("该问题已发送过（sessionStorage中有autofill_sent_q标记），如需重测请在页面控制台执行sessionStorage.clear()");
      return;
    }

    // 防重入：MutationObserver可能在发送流程进行中重复触发
    if (autoFillPage.running) {
      logSkipOnce("上一次发送流程仍在进行中");
      return;
    }
    autoFillPage.running = true;

    console.log("[autofill] autoFillPage触发，URL:", window.location.href, "，q参数:", queryValue);

    try {
      // 判断当前页面是否为Deepseek
      if (window.location.hostname === "chat.deepseek.com") {
        await autoSendQuestionInDeepseek(queryValue);
      } else if (window.location.hostname === "chatgpt.com") {
        await autoSendQuestionInChatGPT(queryValue);
      } else {
        console.warn("当前页面不是Deepseek或ChatGPT");
        return;
      }
      // 发送流程走完，标记已发送并清除缓存
      sessionStorage.setItem("autofill_sent_q", queryValue);
      sessionStorage.removeItem("autofill_cached_q");
      console.log("[autofill] 流程完成，已标记发送");
    } finally {
      autoFillPage.running = false;
    }
  } catch (error) {
    console.error("自动填充失败:", error);
  }
}

/**
 * 监听页面状态变化
 */
function observePageChanges() {
  // 监听URL变化
  let lastUrl = location.href;
  new MutationObserver(() => {
    const url = location.href;
    if (url !== lastUrl) {
      lastUrl = url;
      // URL变化后重新执行
      setTimeout(autoFillPage, 500);
    }
  }).observe(document, { subtree: true, childList: true });

  // 监听DOM变化（针对动态加载的页面）
  const observer = new MutationObserver((mutations) => {
    // 检查是否添加了新的textarea或按钮
    for (const mutation of mutations) {
      if (mutation.addedNodes.length) {
        autoFillPage();
        break;
      }
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });
}

/**
 * 初始化
 */
function init() {
  // 检查当前URL是否符合条件
  if (
    window.location.hostname === "chat.deepseek.com" ||
    window.location.hostname === "chatgpt.com"
  ) {
    // content script在document_start阶段注入，等待DOM就绪后再执行填充和监听
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", () => {
        autoFillPage(); // waitForElement内部会轮询等待目标元素出现
        observePageChanges();
      });
    } else {
      autoFillPage();
      observePageChanges();
    }
  }
}

// Safari 的扩展API以 browser 命名空间为主（16.4 起也提供 chrome），
// Chrome/Edge 只有 chrome。统一取可用的那个，保持双浏览器兼容
const ext = typeof browser !== "undefined" ? browser : chrome;

// 监听来自popup或background的消息
ext.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "executeAutoFill") {
    console.log("[autofill] 收到executeAutoFill消息");
    autoFillPage();
    sendResponse({ success: true });
  }
  return true;
});

// 脚本注入即执行：立即快照URL中的q参数到sessionStorage。
// 本扩展以document_start注入，早于页面自身脚本运行，
// 可赶在SPA用history.replaceState清掉查询参数之前把q保存下来
console.log(
  "[autofill] content script已加载，readyState:",
  document.readyState,
  "，URL:",
  window.location.href,
);
getQueryParamCached("q");

// 初始化
init();
