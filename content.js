// 创建悬浮层
function createFloatLayer() {
    // 先检查是否已经存在悬浮层
    let existingLayer = document.querySelector('.prompt-helper-float');
    if (existingLayer) {
        existingLayer.remove();
    }

    const floatLayer = document.createElement('div');
    floatLayer.className = 'prompt-helper-float';
    floatLayer.setAttribute('data-prompt-helper', 'true');
    
    // 增加穿透属性，避免被网站遮挡
    floatLayer.style.pointerEvents = 'none';
    
    // 创建关闭按钮
    const closeButton = document.createElement('div');
    closeButton.textContent = '×';
    closeButton.style.cssText = `
     position: absolute;
    top: 5px;
    left: 5px;  // 修改这里，从 right 改为 left
    cursor: pointer;
    font-size: 20px;
    color: #666;
    z-index: 100000;
    pointer-events: auto;
    `;
    closeButton.addEventListener('click', () => {
        floatLayer.style.display = 'none';
    });
    
    // 创建关键词输入框
    const keywordInput = document.createElement('input');
    keywordInput.type = 'text';
    keywordInput.placeholder = '输入关键词...';
    keywordInput.style.pointerEvents = 'auto';
    
    // 创建标题列表容器
    const titleList = document.createElement('div');
    titleList.className = 'title-list';
    titleList.style.pointerEvents = 'auto';
    
    floatLayer.appendChild(closeButton);
    floatLayer.appendChild(keywordInput);
    floatLayer.appendChild(titleList);
    
    // 使用固定定位，并设置z-index更高
    floatLayer.style.position = 'fixed';
    floatLayer.style.zIndex = '99999';
    
    document.body.appendChild(floatLayer);
    
    return { floatLayer, keywordInput, titleList };
}

// 更新标题列表
async function updateTitleList(titleList) {
    const result = await chrome.storage.local.get('records');
    const records = result.records || [];
    
    titleList.innerHTML = '';
    records.forEach(record => {
        const titleItem = document.createElement('div');
        titleItem.className = 'title-item';
        titleItem.textContent = record.title;
        titleItem.addEventListener('click', () => handleTitleClick(record));
        titleList.appendChild(titleItem);
    });
}

// 新增：创建通知提示函数
function showNotification(message, isError = false) {
    const notification = document.createElement('div');
    notification.style.cssText = `
        position: fixed;
        bottom: 20px;
        right: 20px;
        background: ${isError ? '#FFE4E4' : '#4CAF50'};
        color: ${isError ? '#D32F2F' : 'white'};
        padding: 12px 24px;
        border-radius: 4px;
        z-index: 1000000;
    `;
    notification.textContent = message;
    document.body.appendChild(notification);
    
    // 3秒后移除提示
    setTimeout(() => {
        notification.remove();
    }, 3000);
}

// 修改：处理标题点击
async function handleTitleClick(record) {
    const keywordInput = document.querySelector('.prompt-helper-float input');
    const keyword = keywordInput.value.trim();
    
    if (!keyword) {
        showNotification('请先输入关键词', true);
        return;
    }
    
    const formattedContent = record.prompt.replace(/{keyword}/g, `{${keyword}}`);

    
    // if (!replaced) {
    //     showNotification('未找到可替换的关键词模式', true);
    //     return;
    // }
    
    try {
        await navigator.clipboard.writeText(formattedContent);
        showNotification('内容已复制到剪贴板');
    } catch (error) {
        showNotification('复制失败，请重试', true);
        console.error('复制到剪贴板时发生错误:', error);
    }
}

// 辅助函数：转义正则特殊字符
function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// 监听存储变化
chrome.storage.onChanged.addListener((changes) => {
    if (changes.records) {
        const titleList = document.querySelector('.prompt-helper-float .title-list');
        if (titleList) {
            updateTitleList(titleList);
        }
    }
});

// 新增：持续监听并重新插入悬浮层
function ensureFloatLayerPersistence() {
    const observer = new MutationObserver((mutations) => {
        const existingLayer = document.querySelector('.prompt-helper-float');
        
        if (!existingLayer) {
            init(); // 重新初始化
        }
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
}

// 域名白名单配置
const DOMAIN_WHITELIST = [
    'chatgpt.com', 
    'claude.ai', 
    'gemini.google.com',
    'grok.com' // 可以根据需要添加更多域名
];

// 检查当前域名是否在白名单中
function isDomainAllowed() {
    const currentDomain = window.location.hostname;
    return DOMAIN_WHITELIST.some(domain => 
        currentDomain === domain || currentDomain.endsWith('.' + domain)
    );
}

// 修改初始化函数
function init() {
    try {
        // 仅在允许的域名上初始化
        if (!isDomainAllowed()) {
            return;
        }

        const { titleList } = createFloatLayer();
        updateTitleList(titleList);
        ensureFloatLayerPersistence(); // 增加持久性监听
    } catch (error) {
        console.error('Prompt Helper初始化失败:', error);
    }
}

// 启动应用
init(); 