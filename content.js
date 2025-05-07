// 创建悬浮层
let hideTimeout; // 用于存储延迟隐藏的定时器

// 创建小图标
function createTriggerIcon() {
    const icon = document.createElement('div');
    icon.className = 'prompt-helper-trigger';
    icon.setAttribute('data-prompt-helper', 'true');
    icon.innerHTML = '📝'; // 使用 emoji 作为图标
    
    icon.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        width: 32px;
        height: 32px;
        background: #ffffff;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        z-index: 99999;
        font-size: 20px;
    `;
    
    document.body.appendChild(icon);
    return icon;
}

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
        left: 5px;
        cursor: pointer;
        font-size: 20px;
        color: #666;
        z-index: 100000;
        pointer-events: auto;
    `;
    closeButton.addEventListener('click', () => {
        hideFloatLayer(floatLayer);
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
    
    // 使用固定定位，并设置初始状态为隐藏
    floatLayer.style.cssText = `
        position: fixed;
        top: 60px;
        right: 20px;
        z-index: 99999;
        background: white;
        padding: 15px;
        border-radius: 8px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        display: none;
        min-width: 200px;
        max-width: 300px;
    `;
    
    // 添加鼠标事件处理
    floatLayer.addEventListener('mouseenter', () => {
        if (hideTimeout) {
            clearTimeout(hideTimeout);
        }
    });
    
    floatLayer.addEventListener('mouseleave', () => {
        startHideTimer(floatLayer);
    });
    
    document.body.appendChild(floatLayer);
    
    return { floatLayer, keywordInput, titleList };
}

// 显示悬浮层
function showFloatLayer(floatLayer) {
    if (hideTimeout) {
        clearTimeout(hideTimeout);
    }
    floatLayer.style.display = 'block';
}

// 隐藏悬浮层
function hideFloatLayer(floatLayer) {
    floatLayer.style.display = 'none';
}

// 开始隐藏计时器
function startHideTimer(floatLayer) {
    if (hideTimeout) {
        clearTimeout(hideTimeout);
    }
    hideTimeout = setTimeout(() => {
        hideFloatLayer(floatLayer);
    }, 2000);
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
    
    // if (!keyword) {
    //     showNotification('请先输入关键词', true);
    // }
    
    let formattedContent = keyword ? record.prompt.replace(/{keyword}/g, `{${keyword}}`) : record.prompt;

    
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

        const { floatLayer, titleList } = createFloatLayer();
        const triggerIcon = createTriggerIcon();
        
        // 添加图标的鼠标事件
        triggerIcon.addEventListener('mouseenter', () => {
            showFloatLayer(floatLayer);
        });
        
        triggerIcon.addEventListener('mouseleave', () => {
            startHideTimer(floatLayer);
        });
        
        updateTitleList(titleList);
        ensureFloatLayerPersistence();
    } catch (error) {
        console.error('Prompt Helper初始化失败:', error);
    }
}

// 启动应用
init(); 