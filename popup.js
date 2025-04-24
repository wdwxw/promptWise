// 存储操作封装
const storage = {
    async getRecords() {
        const result = await chrome.storage.local.get('records');
        return result.records || [];
    },

    async saveRecords(records) {
        await chrome.storage.local.set({ records });
    }
};

// DOM元素
const elements = {
    addNewBtn: document.getElementById('addNewBtn'),
    recordList: document.getElementById('recordList'),
    editForm: document.getElementById('editForm'),
    formTitle: document.getElementById('formTitle'),
    titleInput: document.getElementById('titleInput'),
    promptInput: document.getElementById('promptInput'),
    submitBtn: document.getElementById('submitBtn'),
    cancelBtn: document.getElementById('cancelBtn'),
    recordTemplate: document.getElementById('recordTemplate'),
    exportBtn: document.getElementById('exportBtn'),
    importBtn: document.getElementById('importBtn'),
    importForm: document.getElementById('importForm'),
    importInput: document.getElementById('importInput'),
    importSubmitBtn: document.getElementById('importSubmitBtn'),
    importCancelBtn: document.getElementById('importCancelBtn'),
};

// 当前编辑的记录ID
let currentEditId = null;

// 初始化
async function init() {
    await refreshRecordList();
    bindEvents();
}

// 绑定事件
function bindEvents() {
    elements.addNewBtn.addEventListener('click', showAddForm);
    elements.submitBtn.addEventListener('click', handleSubmit);
    elements.cancelBtn.addEventListener('click', hideForm);
    elements.exportBtn.addEventListener('click', handleExport);
    elements.importBtn.addEventListener('click', showImportForm);
    elements.importSubmitBtn.addEventListener('click', handleImport);
    elements.importCancelBtn.addEventListener('click', hideImportForm);
}

// 刷新记录列表
async function refreshRecordList() {
    const records = await storage.getRecords();
    elements.recordList.innerHTML = '';

    records.forEach(record => {
        const recordElement = createRecordElement(record);
        elements.recordList.appendChild(recordElement);
    });
}

// 创建记录元素
function createRecordElement(record) {
    const template = elements.recordTemplate.content.cloneNode(true);
    const recordItem = template.querySelector('.record-item');

    recordItem.querySelector('.record-title').textContent = record.title;
    recordItem.querySelector('.record-prompt').textContent = record.prompt;

    // 编辑按钮
    recordItem.querySelector('.edit').addEventListener('click', () => {
        showEditForm(record);
    });

    // 删除按钮
    recordItem.querySelector('.delete').addEventListener('click', () => {
        handleDelete(record.id);
    });

    return recordItem;
}

// 显示新增表单
function showAddForm() {
    currentEditId = null;
    elements.formTitle.textContent = '新增记录';
    elements.titleInput.value = '';
    elements.promptInput.value = '';
    elements.editForm.style.display = 'block';
    elements.recordList.style.display = 'none';
    elements.addNewBtn.style.display = 'none';
}

// 显示编辑表单
function showEditForm(record) {
    currentEditId = record.id;
    elements.formTitle.textContent = '编辑记录';
    elements.titleInput.value = record.title;
    elements.promptInput.value = record.prompt;
    elements.editForm.style.display = 'block';
    elements.recordList.style.display = 'none';
    elements.addNewBtn.style.display = 'none';
}

// 隐藏表单
function hideForm() {
    elements.editForm.style.display = 'none';
    elements.recordList.style.display = 'block';
    elements.addNewBtn.style.display = 'block';
    currentEditId = null;
}

// 处理提交
async function handleSubmit() {
    const title = elements.titleInput.value.trim();
    const prompt = elements.promptInput.value.trim();

    if (!title || !prompt) {
        alert('请填写完整信息');
        return;
    }

    const records = await storage.getRecords();

    if (currentEditId) {
        // 编辑现有记录
        const index = records.findIndex(r => r.id === currentEditId);
        if (index !== -1) {
            records[index] = { ...records[index], title, prompt };
        }
    } else {
        // 添加新记录
        records.push({
            id: Date.now(),
            title,
            prompt
        });
    }

    await storage.saveRecords(records);
    hideForm();
    await refreshRecordList();
}

// 处理删除
async function handleDelete(id) {
    if (!confirm('确定要删除这条记录吗？')) {
        return;
    }

    if (!confirm('此操作不可恢复，确定要继续吗？')) {
        return;
    }

    const records = await storage.getRecords();
    const newRecords = records.filter(record => record.id !== id);
    await storage.saveRecords(newRecords);
    await refreshRecordList();
}

// 导出功能
async function handleExport() {
    const records = await storage.getRecords();
    const exportData = records.map(record => ({
        标题: record.title,
        prompt内容: record.prompt
    }));
    
    // 创建下载链接
    const dataStr = JSON.stringify(exportData, null, 2);
    const blob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    
    // 创建并触发下载
    const a = document.createElement('a');
    a.href = url;
    a.download = `prompt_recode_${new Date().getFullYear()}_${(new Date().getMonth() + 1).toString().padStart(2, '0')}_${new Date().getDate().toString().padStart(2, '0')}_${new Date().getHours().toString().padStart(2, '0')}_${new Date().getMinutes().toString().padStart(2, '0')}_${new Date().getSeconds().toString().padStart(2, '0')}.json`;
    document.body.appendChild(a);
    a.click();
    
    // 清理
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

// 显示导入表单
function showImportForm() {
    elements.recordList.style.display = 'none';
    elements.editForm.style.display = 'none';
    elements.importForm.style.display = 'block';
    elements.addNewBtn.style.display = 'none';
}

// 隐藏导入表单
function hideImportForm() {
    elements.importForm.style.display = 'none';
    elements.recordList.style.display = 'block';
    elements.addNewBtn.style.display = 'block';
    elements.importInput.value = '';
}

// 导入功能
async function handleImport() {
    try {
        const importText = elements.importInput.value.trim();
        if (!importText) {
            alert('请输入要导入的内容');
            return;
        }

        const importData = JSON.parse(importText);
        if (!Array.isArray(importData)) {
            alert('导入的数据格式不正确');
            return;
        }

        // 获取现有记录
        const existingRecords = await storage.getRecords();
        
        // 处理导入数据
        const newRecords = importData.map(item => ({
            id: Date.now() + Math.random(), // 生成临时ID
            title: item.标题,
            prompt: item.prompt内容
        }));

        // 根据标题进行合并（覆盖）
        const mergedRecords = [...existingRecords];
        newRecords.forEach(newRecord => {
            const existingIndex = mergedRecords.findIndex(r => r.title === newRecord.title);
            if (existingIndex !== -1) {
                mergedRecords[existingIndex] = newRecord;
            } else {
                mergedRecords.push(newRecord);
            }
        });

        // 保存更新后的记录
        await storage.saveRecords(mergedRecords);
        await refreshRecordList();
        hideImportForm();
        
        alert('导入成功！');
    } catch (error) {
        alert('导入失败：' + error.message);
    }
}

// 启动应用
document.addEventListener('DOMContentLoaded', init); 