# PromptWise

macOS 提示语管理工具 — 通过桌面悬浮图标快速访问和管理你的 AI 提示语。

## 功能

- **桌面悬浮图标** — 可拖拽的浮动图标，点击即可打开管理面板
- **提示语管理** — 录入标题 + Markdown 内容
- **一键复制** — 点击标题即复制提示语内容到剪切板
- **鼠标悬浮预览** — 悬浮在标题上查看 Markdown 渲染后的内容
- **拖拽排序** — 直接拖拽调整提示语顺序
- **列表/宫格切换** — 支持列表模式和宫格模式（九宫格风格）
- **分类管理** — 创建分类文件夹组织提示语
- **搜索** — 按标题或内容关键字搜索
- **菜单栏图标** — 同时提供菜单栏快捷入口

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode Command Line Tools (`xcode-select --install`)

## 构建运行

```bash
# 开发运行
swift run

# 构建 .app 应用包
./build.sh

# 运行应用
open PromptWise.app

# 安装到应用程序文件夹
cp -r PromptWise.app /Applications/
```

## 数据存储

提示语数据以 JSON 格式存储在：

```
~/Library/Application Support/PromptWise/data.json
```

## 技术栈

- Swift 5.9+
- SwiftUI + AppKit
- macOS 原生开发
