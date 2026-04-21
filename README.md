# PromptWise

macOS 提示语管理工具 — 通过桌面悬浮图标快速访问和管理你的 AI 提示语。

## 功能

### 核心交互

- **桌面悬浮图标** — 始终置顶的可拖拽浮动图标，点击打开/关闭管理面板；拖动时自动关闭管理面板
- **菜单栏入口** — 提供显示/隐藏面板、偏好设置、退出等快捷操作
- **快捷访问** — 鼠标悬停图标自动展开提示语列表，点击即复制，支持拖拽到其他应用粘贴

### 提示语管理

- **创建与编辑** — 标题 + Markdown 内容，支持实时预览；新建时可用 `⌘↩` 快速提交；实时显示字符数与 Token 估算
- **重复检测** — 新建时若标题已存在，弹框询问是否覆盖；批量导入同名标题自动静默覆盖
- **一键复制** — 点击即复制内容到剪切板
- **悬浮预览** — 鼠标悬停显示 Markdown 渲染后的完整内容（支持文本选择）
- **拖拽排序** — 列表内拖拽调整顺序，拖到列表外自动恢复原位
- **拖拽到外部** — 拖出窗口可将提示语内容粘贴到其他应用
- **列表/宫格切换** — 两种视图模式自由切换
- **分类管理** — 创建分类、自定义图标，拖拽调整分类顺序
- **搜索** — 按标题或内容关键字实时过滤

### 数据管理

- **导出数据** — 将所有提示语和分类导出为 JSON 文件
- **批量导入** — 支持三种格式导入：完整 JSON、简化 JSON `[{title, content}]`、Markdown；同名标题自动覆盖

### 偏好设置

- **深色/浅色主题** — 两套主题自由切换
- **数据新增位置** — 新建提示语追加到列表顶部或末尾
- **快捷访问开关** — 控制悬停展开功能的启用/禁用
- **显示条数** — 快捷列表展示数量（5 / 10 / 15 / 20 / 30 / 50 条可选）
- **自动收起时间** — 快捷列表自动消失延迟（0.5 / 1 / 2 / 3 / 5 / 8 / 10 秒可选）
- **显示分类** — 快捷列表只显示指定分类的提示语（默认全部）

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

## 签名与分发（无需开发者账号）

为减少“重装后辅助功能重复授权”问题，项目已内置本地固定签名流程（非 ad hoc）。

### 1) 首次初始化本地签名证书（仅一次）

```bash
./create_local_codesign_cert.sh
```

该脚本会：
- 创建/使用专用 keychain：`~/Library/Keychains/promptwise-signing.keychain-db`
- 导入 `PromptWise Local Code Signing` 证书与私钥

### 2) 构建并签名 `.app`

```bash
./build.sh
```

可选参数：
- `./build.sh --skip-build`：跳过 `swift build`
- `./build.sh --no-sign`：跳过签名（不推荐，可能导致权限识别不稳定）

### 3) 构建并签名 `.dmg`

```bash
./build_dmg.sh
./build_dmg.sh 1.2.0
```

可选参数：
- `./build_dmg.sh 1.2.0 --skip-build`
- `./build_dmg.sh 1.2.0 --no-sign`（不推荐）

### 4) 验证签名结果

```bash
# 默认检查当前目录 PromptWise.app
./verify_sign.sh

# 检查已安装 app
./verify_sign.sh /Applications/PromptWise.app

# 检查 dmg（会自动挂载并检查其中 app）
./verify_sign.sh ./PromptWise-1.0.0.dmg
```

检查重点：
- `codesign -dv` 输出中 `Signature` 不应为 `adhoc`
- `codesign --verify --deep --strict` 应通过

说明：
- 本地自签名场景下出现 `NOT_TRUSTED` 属于预期现象，不影响本地固定身份签名流程。
- 对外公开分发若需更高稳定性与系统信任，建议使用 Developer ID + notarization。

## 数据存储

提示语数据以 JSON 格式存储在：

```
~/Library/Application Support/PromptWise/data.json
```

## 技术栈

- Swift 5.9+
- SwiftUI + AppKit（混合架构）
- macOS 原生开发，无第三方依赖
