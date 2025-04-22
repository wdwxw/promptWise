# Prompt管理Chrome插件

这是一个用于管理和快速使用prompt模板的Chrome插件。

## 功能特点

1. 提供弹出窗口界面，用于管理prompt模板
   - 新增记录
   - 编辑记录
   - 删除记录
   - 查看记录列表

2. 在所有网页显示悬浮层
   - 快速访问已保存的prompt模板
   - 支持关键词替换功能

## 项目结构

```
├── manifest.json        # 插件配置文件
├── popup.html          # 弹出窗口页面
├── popup.js            # 弹出窗口逻辑
├── content.js          # 页面注入脚本
├── styles/             # 样式文件
│   ├── popup.css      # 弹出窗口样式
│   └── content.css    # 悬浮层样式
└── README.md          # 项目说明文档
```

## 开发日志

### 2024-03-21
- 初始化项目
- 创建基本文件结构
- 实现Chrome插件配置 # promptWise
