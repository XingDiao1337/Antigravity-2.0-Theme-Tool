# Antigravity 2.0 Theme Tool

English | [中文](#中文)

A single-file theming tool for the **Antigravity 2.x** desktop application (Windows). It injects a glassmorphism (frosted glass) theme, custom wallpaper, layered blur effects, animations and per-control styling into the app's `app.asar` bundle - all from one batch file with an interactive menu.

---

## Features

- Custom wallpaper with persistent display (fixes the "wallpaper flashes then disappears" issue)
- Glassmorphism (frosted glass) theme across the whole UI: sidebar, cards, inputs, menus, dialogs and dropdowns
- Layered blur system: every control group uses a distinct blur radius, all linked to the user-configured background blur
- Automatic dark / light theme adaptation (follows the app theme switch)
- Fade-in and pop-up animations, hover effects, custom scrollbar and text selection styling
- Optional top menu bar removal (Antigravity / File / View / Window buttons)
- Custom CSS injection entry (`custom.css`) for DIY styling
- Built-in backup, verification, atomic replacement and rollback for safe patching
- Chinese/English dual-language command line interface with progress bars and spinners

## 功能特性

- 自定义壁纸持久显示（修复"壁纸闪现后消失"问题）
- 全界面毛玻璃主题：侧栏、卡片、输入框、菜单、对话框、下拉框
- 分层模糊体系：每类控件独立模糊度，全部联动背景模糊设置
- 自动适配深色/浅色模式（跟随应用主题切换）
- 淡入、弹窗动画、悬停动效、自定义滚动条与选区样式
- 可选隐藏顶部菜单栏（Antigravity / File / View / Window 按钮）
- 自定义 CSS 注入入口（`custom.css`），方便 DIY
- 内置备份、校验、原子替换与回滚，安全打补丁
- 中英双语命令行界面，带进度条与转圈动画

---

## File Structure / 文件结构

```
Antigravity-Background.bat   The single-file tool (install / uninstall / configure)
background.png               Default wallpaper used by the installer
custom.css                   Optional custom CSS, injected on install (priority highest)
README.md                    This document
LICENSE                      MIT License
```

> Note: the `asar/` folder (unpacked app reference) and `obsolete-kept/` (old version files) are NOT part of this repository and are excluded via `.gitignore`.

> 说明：`asar/`（应用解包参考）与 `obsolete-kept/`（旧版文件）不属于本仓库，已通过 `.gitignore` 排除。

---

## Requirements / 环境依赖

| Dependency | Version | Purpose |
|---|---|---|
| Windows | 10 / 11 | Target OS |
| Node.js | 22.12+ (Node 24 recommended) | Runtime for the ASAR tool |
| @electron/asar | 4.x (auto-installed via npx) | ASAR pack / unpack |

| 依赖 | 版本 | 用途 |
|---|---|---|
| Windows | 10 / 11 | 目标系统 |
| Node.js | 22.12+（推荐 Node 24） | ASAR 工具的运行时 |
| @electron/asar | 4.x（npx 自动安装） | ASAR 打包 / 解包 |

### Installation instructions / 安装指令

**1. Install Node.js**

Download the LTS installer from https://nodejs.org and run it, or use winget:

```powershell
winget install OpenJS.NodeJS.LTS
```

Verify:

```powershell
node --version
npm --version
```

**2. (Optional) Install @electron/asar globally**

The tool can also use `npx` automatically (it will download and cache `@electron/asar@4.2.1` on first use), but a global install avoids the first-run network wait:

```powershell
npm install -g @electron/asar
```

Verify:

```powershell
asar --version
```

**3. Clone / download this repository**

```powershell
git clone https://github.com/XingDiao1337/Antigravity-2.0-Theme-Tool.git
cd Antigravity-2.0-Theme-Tool
```

**4. Install Antigravity 2.x**

Install the Antigravity desktop app first (the tool patches its `resources/app.asar`).

---

## Usage / 使用方法

Double-click `Antigravity-Background.bat`, then follow the interactive menu:

```
  [1] Install background   (choose image + opacity + blur)
  [2] Uninstall            (restore original app.asar)
  [3] Exit
```

Install flow prompts:

- Image: use the bundled `background.png` or pick another (PNG/JPG/WEBP/BMP)
- Overlay opacity: 0..1 (recommended 0.2~0.35)
- Background blur: 0..50 px
- Hide top menu bar (Antigravity / File / View / Window): Y / N

Automation (non-interactive):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Antigravity-Background.bat
```

Command line parameters (used with the extracted script):

```powershell
# Install with a specific image, opacity and blur, hiding the menu bar
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\agbg-mod.ps1" ^
  -BatDir "%~dp0" -Image "D:\wallpaper.png" -Opacity 0.25 -Blur 6 -HideMenu

# Uninstall (restore the original app.asar)
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\agbg-mod.ps1" -Uninstall
```

Uninstall restores the exact original `app.asar` backup created at first install.

---

## How It Works / 工作原理

### 1. Patching pipeline / 打补丁流程

```
Stop Antigravity
  -> find resources\app.asar (known paths + recursive scan)
  -> unpack app.asar (asar extract) into %TEMP%
  -> if a previous patch is detected, restore the original backup and re-unpack
  -> copy the wallpaper into dist\antigravity-background.png
  -> sample the wallpaper corner color and patch titleBarOverlay color in utils.js
  -> generate dist\backgroundInjection.js (theme CSS + runtime hooks)
  -> patch dist\utils.js:
       - add: const backgroundInjection_1 = require("./backgroundInjection");
       - add: (0, backgroundInjection_1.installBackground)(win);  before win.loadURL(url)
  -> verify 5 patch markers, then repack (asar pack) to a temp file
  -> atomic swap: move original aside, move new in, roll back on failure
  -> keep a one-time exact original backup (.bak)
```

### 2. Runtime injection / 运行时注入

`backgroundInjection.js` runs in the Electron main process. For every BrowserWindow it:

- reads `dist/antigravity-background.png` as a base64 data URI
- on `did-finish-load`, `did-navigate-in-page`, `did-frame-finish-load` (plus 500ms/1500ms timers)
  executes JavaScript in the renderer that appends a `<style>` element
- the style sheet (all values are baked in at install time) provides:

### 3. Theme CSS architecture / 主题 CSS 架构

- **Wallpaper layer**: `body::before` (fixed, `z-index:-1`, cover, blur/brightness/saturate filters, fade-in animation) - sits behind all content
- **Overlay layer**: `body::after` (`z-index:-1`) - dims the wallpaper only, not the UI
- **Transparent base**: `--color-background` / `--background` forced transparent so the wallpaper shows through everywhere (this is the core fix for the "flash then revert" bug)
- **Layered glass (per control blur)**:
  - Sidebar `.bg-sidebar`: `bgBlur + 18px` (cap 60)
  - Cards / settings panels `.bg-card`: same as sidebar
  - Secondary controls `.bg-secondary/.bg-muted`: `sidebar - 8px` (floor 10)
  - Floating layers `[role="dialog"]/[role="menu"]/[role="tooltip"]`: `sidebar + 10px` (cap 70)
  - Inputs: `sidebar - 14px` (floor 8)
  - Top application menu `[class*="menu-border"]`: dedicated high-opacity frosted style (z-index 99999)
  - Dropdown lists `[role="listbox"]`: z-index 100000 (portal to body, must sit above the dialog at 99998)
- **Nested blur suppression**: only the outermost containers keep `backdrop-filter`; nested blocks are disabled to keep compositing cheap (5 layers total)
- **Dual theme**: `body.theme-light` swaps every variable to a light glass palette (auto follow)
- **Animations**: `agbg-fade` (wallpaper), `agbg-pop` (dialogs/menus on mount), hover transitions
- **Accessibility**: foreground colors are brightened (`#eaeaf0` dark / `#1a1a1f` light) and muted-foreground raised; measured WCAG contrast 6.8~15.3:1

### 4. Safety / 安全性

- One-time original backup (`app.asar.antigravity-background.original.bak`) used by uninstall
- Repack to a temp file before replacement; automatic rollback if the swap fails
- 5-point verification after patching (marker, import, hook, files exist)
- The installer refuses to run over an ambiguous partial patch without a backup

---

## Custom CSS / 自定义样式

Place a `custom.css` next to the batch file; it is packed into the app and appended to the injected style sheet (highest priority) on install. Edit it and re-run the installer to apply.

```css
/* Example: card glass */
.bg-card {
  background-color: rgba(20,20,26,0.5) !important;
  backdrop-filter: blur(16px) saturate(1.25) !important;
}
```

---

## License / 许可证

[MIT License](LICENSE) - see the `LICENSE` file.

---
