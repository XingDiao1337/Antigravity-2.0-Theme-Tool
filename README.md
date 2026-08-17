# Antigravity 2.0 Theme Tool

A single-file theming tool for the **Antigravity 2.x** desktop application (Windows). It injects a glassmorphism theme, custom wallpaper, layered blur effects and animations into the app's `app.asar` bundle through one interactive batch file.

Read this in: [English](#english) | [中文](#中文)

---

## English

### Features

- Custom wallpaper with persistent display (fixes the "wallpaper flashes then disappears" issue)
- Glassmorphism theme across the whole UI: sidebar, cards, inputs, menus, dialogs and dropdowns
- Layered blur system: every control group uses a distinct blur radius, all linked to the user-configured background blur
- Automatic dark / light theme adaptation (follows the app theme switch)
- Animations: wallpaper fade-in, dialog pop-up, hover effects, transitions
- Custom scrollbar and text selection styling
- Optional top menu bar removal (Antigravity / File / View / Window buttons)
- Install IDE button auto-hidden
- Native titlebar buttons recolored from a sampled wallpaper corner color
- Custom CSS injection entry (`custom.css`) for DIY styling
- Built-in backup, verification, atomic replacement and rollback for safe patching
- Command line interface with colored prompts, progress bars and spinners

### File Structure

```
Antigravity-Background.bat   The single-file tool (install / uninstall / configure)
background.png               Default wallpaper used by the installer
custom.css                   Optional custom CSS, injected on install (highest priority)
README.md                    This document
LICENSE                      MIT License
```

### Requirements

| Dependency | Version | Purpose |
|---|---|---|
| Windows | 10 / 11 | Target OS |
| Node.js | 22.12+ (Node 24 recommended) | Runtime for the ASAR tool |
| @electron/asar | 4.x | ASAR pack / unpack |

### Installation

1. Install Node.js (LTS) from https://nodejs.org, or via winget:

   ```powershell
   winget install OpenJS.NodeJS.LTS
   ```

   Verify:

   ```powershell
   node --version
   npm --version
   ```

2. (Optional) Install @electron/asar globally. The tool can also use `npx` automatically, but a global install avoids the first-run network wait:

   ```powershell
   npm install -g @electron/asar
   ```

   Verify:

   ```powershell
   asar --version
   ```

3. Download this repository:

   ```powershell
   git clone https://github.com/XingDiao1337/Antigravity-2.0-Theme-Tool.git
   cd Antigravity-2.0-Theme-Tool
   ```

4. Install the Antigravity 2.x desktop app (the tool patches its `resources/app.asar`).

### Usage

Double-click `Antigravity-Background.bat`, then follow the interactive menu:

```
  [1] Install background   (choose image + opacity + blur)
  [2] Uninstall            (restore original app.asar)
  [3] Exit
```

Install flow prompts: image (bundled `background.png` or a custom PNG/JPG/WEBP/BMP), overlay opacity (0..1, recommended 0.2~0.35), background blur (0..50 px), hide top menu bar (Y / N).

Uninstall restores the exact original `app.asar` backup created at first install.

### How It Works

Patching pipeline:

```
Stop Antigravity
  -> locate resources\app.asar (known paths + recursive scan)
  -> unpack app.asar into %TEMP%
  -> if a previous patch is detected, restore the original backup and re-unpack
  -> copy the wallpaper into dist\antigravity-background.png
  -> sample the wallpaper corner color and patch titleBarOverlay color in utils.js
  -> generate dist\backgroundInjection.js (theme CSS + runtime hooks)
  -> patch dist\utils.js:
       - add: const backgroundInjection_1 = require("./backgroundInjection");
       - add: (0, backgroundInjection_1.installBackground)(win); before win.loadURL(url)
  -> verify 5 patch markers, repack to a temp file
  -> atomic swap with rollback, keep a one-time exact original backup (.bak)
```

Runtime injection: `backgroundInjection.js` runs in the Electron main process. For every BrowserWindow it reads the wallpaper as a base64 data URI and, on `did-finish-load` / `did-navigate-in-page` / `did-frame-finish-load` (plus 500ms / 1500ms timers), executes JavaScript in the renderer that appends a `<style>` element. All values are baked in at install time.

Theme CSS architecture:

- Wallpaper layer: `body::before` (fixed, `z-index:-1`, cover, blur/brightness/saturate filters, fade-in animation)
- Overlay layer: `body::after` (`z-index:-1`) - dims the wallpaper only, not the UI
- Transparent base: `--color-background` / `--background` forced transparent (core fix for the "flash then revert" bug)
- Layered glass (per-control blur, all linked to the background blur):
  - Sidebar `.bg-sidebar`: background blur + 18px (cap 60)
  - Cards / settings panels `.bg-card`: same as sidebar
  - Secondary controls `.bg-secondary` / `.bg-muted`: sidebar - 8px (floor 10)
  - Floating layers `[role="dialog"]` / `[role="menu"]` / `[role="tooltip"]`: sidebar + 10px (cap 70)
  - Inputs: sidebar - 14px (floor 8)
  - Top application menu `[class*="menu-border"]`: dedicated high-opacity frosted style, z-index 99999
  - Dropdown lists `[role="listbox"]`: z-index 100000 (portal to body, sits above the dialog at 99998; its `z-[6000]` container is raised to 99998)
- Nested blur suppression: only the outermost containers keep `backdrop-filter` (5 compositing layers total)
- Dual theme: `body.theme-light` swaps every variable to a light glass palette
- Animations: `agbg-fade` (wallpaper), `agbg-pop` (dialogs/menus on mount), hover transitions
- Accessibility: foreground brightened (`#eaeaf0` dark / `#1a1a1f` light), muted-foreground raised; measured WCAG contrast 6.8~15.3:1

Safety: one-time original backup, temp-file repack, atomic replacement with rollback, 5-point verification after patching.

### Custom CSS

Place a `custom.css` next to the batch file. It is packed into the app and appended to the injected style sheet (highest priority) on install. Edit it and re-run the installer to apply.

```css
/* Example: card glass */
.bg-card {
  background-color: rgba(20,20,26,0.5) !important;
  backdrop-filter: blur(16px) saturate(1.25) !important;
}
```

### License

[MIT License](LICENSE)

---

## 中文

### 功能特性

- 自定义壁纸持久显示（修复"壁纸闪现后消失"问题）
- 全界面毛玻璃主题：侧栏、卡片、输入框、菜单、对话框、下拉框
- 分层模糊体系：每类控件独立模糊度，全部联动背景模糊设置
- 自动适配深色 / 浅色模式（跟随应用主题切换）
- 动画：壁纸淡入、弹窗弹出、悬停动效、过渡
- 自定义滚动条与选区样式
- 可选隐藏顶部菜单栏（Antigravity / File / View / Window 按钮）
- 自动隐藏 Install IDE 按钮
- 原生标题栏按钮配色采样壁纸角落色
- 自定义 CSS 注入入口（`custom.css`），方便 DIY
- 内置备份、校验、原子替换与回滚，安全打补丁
- 命令行界面：彩色提问、进度条、转圈动画

### 文件结构

```
Antigravity-Background.bat   单文件工具（安装 / 卸载 / 配置）
background.png               安装器使用的默认壁纸
custom.css                   可选自定义样式，安装时注入（优先级最高）
README.md                    本文档
LICENSE                      MIT 许可证
```

### 环境依赖

| 依赖 | 版本 | 用途 |
|---|---|---|
| Windows | 10 / 11 | 目标系统 |
| Node.js | 22.12+（推荐 Node 24） | ASAR 工具运行时 |
| @electron/asar | 4.x | ASAR 打包 / 解包 |

### 安装指令

1. 安装 Node.js LTS：从 https://nodejs.org 下载安装，或使用 winget：

   ```powershell
   winget install OpenJS.NodeJS.LTS
   ```

   验证：

   ```powershell
   node --version
   npm --version
   ```

2. （可选）全局安装 @electron/asar。工具也可以自动使用 npx（首次使用自动下载缓存），全局安装可避免首次联网等待：

   ```powershell
   npm install -g @electron/asar
   ```

   验证：

   ```powershell
   asar --version
   ```

3. 下载本仓库：

   ```powershell
   git clone https://github.com/XingDiao1337/Antigravity-2.0-Theme-Tool.git
   cd Antigravity-2.0-Theme-Tool
   ```

4. 先安装 Antigravity 2.x 桌面应用（工具会修补其 `resources/app.asar`）。

### 使用方法

双击 `Antigravity-Background.bat`，按交互菜单操作：

```
  [1] 安装背景（选图 + 透明度 + 模糊度）
  [2] 卸载（恢复原始 app.asar）
  [3] 退出
```

安装流程提示：图片（使用随附 `background.png` 或自选 PNG/JPG/WEBP/BMP）、遮罩透明度（0~1，推荐 0.2~0.35）、背景模糊（0~50 像素）、是否隐藏顶部菜单栏（Y / N）。

卸载会恢复首次安装时创建的原始 `app.asar` 备份。

### 工作原理

打补丁流程：

```
停止 Antigravity
  -> 定位 resources\app.asar（已知路径 + 递归扫描）
  -> 解包 app.asar 到 %TEMP%
  -> 检测到旧补丁时恢复原版备份并重新解包
  -> 复制壁纸到 dist\antigravity-background.png
  -> 采样壁纸角落色并修补 utils.js 的 titleBarOverlay 颜色
  -> 生成 dist\backgroundInjection.js（主题 CSS + 运行时钩子）
  -> 修补 dist\utils.js：
       - 添加：const backgroundInjection_1 = require("./backgroundInjection");
       - 添加：(0, backgroundInjection_1.installBackground)(win); 在 win.loadURL(url) 之前
  -> 验证 5 项补丁标记，重新打包到临时文件
  -> 原子替换（失败回滚），保留一次性原版备份（.bak）
```

运行时注入：`backgroundInjection.js` 运行于 Electron 主进程。对每个窗口，将壁纸读为 base64 data URI，并在 `did-finish-load` / `did-navigate-in-page` / `did-frame-finish-load`（外加 500ms / 1500ms 定时器）时向渲染进程注入脚本、追加 `<style>` 元素。所有值在安装时写入。

主题 CSS 架构：

- 壁纸层：`body::before`（fixed、`z-index:-1`、cover、模糊/亮度/饱和度滤镜、淡入动画）
- 遮罩层：`body::after`（`z-index:-1`）——只压暗壁纸，不影响 UI
- 透明基座：`--color-background` / `--background` 强制透明（修复"闪退"的核心）
- 分层毛玻璃（每类控件独立模糊，全部联动背景模糊）：
  - 侧栏 `.bg-sidebar`：背景模糊 + 18px（上限 60）
  - 卡片 / 设置面板 `.bg-card`：与侧栏一致
  - 次级控件 `.bg-secondary` / `.bg-muted`：侧栏 - 8px（下限 10）
  - 浮层 `[role="dialog"]` / `[role="menu"]` / `[role="tooltip"]`：侧栏 + 10px（上限 70）
  - 输入框：侧栏 - 14px（下限 8）
  - 顶部应用菜单 `[class*="menu-border"]`：专属高不透明磨砂样式，z-index 99999
  - 下拉列表 `[role="listbox"]`：z-index 100000（portal 到 body，须高于对话框 99998；其 `z-[6000]` 定位容器提升至 99998）
- 嵌套模糊抑制：仅最外层容器保留 backdrop-filter（共 5 个合成层）
- 双主题：`body.theme-light` 将全部变量切换为浅色玻璃调色板
- 动画：`agbg-fade`（壁纸）、`agbg-pop`（弹窗/菜单挂载）、悬停过渡
- 可读性：前景提亮（深色 `#eaeaf0` / 浅色 `#1a1a1f`）、次要文字提亮；实测 WCAG 对比度 6.8~15.3:1

安全性：一次性原版备份、临时文件打包、原子替换 + 回滚、补丁后 5 项验证。

### 自定义样式

在批处理文件旁放置 `custom.css`，安装时它会被打进应用并追加到注入样式表末尾（优先级最高）。修改后重新运行安装即可生效。

```css
/* 示例：卡片毛玻璃 */
.bg-card {
  background-color: rgba(20,20,26,0.5) !important;
  backdrop-filter: blur(16px) saturate(1.25) !important;
}
```

### 许可证

[MIT License](LICENSE)
