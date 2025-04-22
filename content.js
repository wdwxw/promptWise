// 创建悬浮层
function createFloatLayer() {
    const floatLayer = document.createElement('div');
    floatLayer.className = 'prompt-helper-float';
    
    // 创建关键词输入框
    const keywordInput = document.createElement('input');
    keywordInput.type = 'text';
    keywordInput.placeholder = '输入关键词...';
    
    // 创建标题列表容器
    const titleList = document.createElement('div');
    titleList.className = 'title-list';
    
    floatLayer.appendChild(keywordInput);
    floatLayer.appendChild(titleList);
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
    
    // 替换关键词并复制到剪贴板
    const formattedContent = record.prompt.replace(new RegExp(`{${keyword}}`, 'g'), keyword);
    await navigator.clipboard.writeText(formattedContent);
    
    // 提示用户
    showNotification('内容已复制到剪贴板');
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

// 初始化
function init() {
    const { titleList } = createFloatLayer();
    updateTitleList(titleList);
}

// 启动应用
init(); 