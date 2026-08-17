@echo off
setlocal
title Antigravity Background Mod
chcp 65001 >nul
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Write-Host '';Write-Host '   Antigravity Background Mod  v4.5.9' -ForegroundColor Cyan;Write-Host ('   '+('='*55)) -ForegroundColor DarkCyan;Write-Host ''"
if errorlevel 1 echo [WARN] splash skipped.
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$c=Get-Content -LiteralPath '%~f0' -Encoding UTF8;$s=($c|Select-String '^::<PS>$').LineNumber;$e=($c|Select-String '^::</PS>$').LineNumber;$c[($s)..($e-2)]|Set-Content -LiteralPath (Join-Path $env:TEMP 'agbg-mod.ps1') -Encoding UTF8"
if errorlevel 1 goto :error
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\agbg-mod.ps1" -BatDir "%~dp0"
set ERR=%ERRORLEVEL%
del /q "%TEMP%\agbg-mod.ps1" >nul 2>&1
if not "%ERR%"=="0" (
  echo.
  echo [ERROR] Antigravity Background Mod failed with exit code %ERR%.
)
echo.
pause
exit /b %ERR%

:error
echo [ERROR] Failed to prepare the script.
pause
exit /b 1

::<PS>
param([string]$BatDir='',[string]$Image='',[double]$Opacity=-1,[double]$Blur=-1,[switch]$Uninstall,[switch]$HideMenu)

$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$PatchVersion='4.5.9'
$Marker='ANTIGRAVITY_BACKGROUND_MOD_V4'
try { [Console]::OutputEncoding=[Text.Encoding]::UTF8 } catch {}
if(-not $BatDir){ $BatDir=Split-Path -Parent $MyInvocation.MyCommand.Path }
$BatDir = ($BatDir -replace '"','').TrimEnd('\')

# ==================== 界面辅助 ====================
function Info([string]$m){Write-Host "  [+] $m" -ForegroundColor Cyan}
function Ok([string]$m){Write-Host "  [OK] $m" -ForegroundColor Green}
function Warn([string]$m){Write-Host "  [!] $m" -ForegroundColor Yellow}
function Fail([string]$m){throw $m}

function Get-DisplayWidth([string]$s){
  $w=0
  foreach($ch in $s.ToCharArray()){ $w += $(if([int]$ch -gt 0x2E80){2}else{1}) }
  $w
}
function Pad-Center([string]$s,[int]$width){
  $pad=$width-(Get-DisplayWidth $s)
  if($pad -lt 0){$pad=0}
  $l=[int][Math]::Floor($pad/2);$r=$pad-$l
  (' '*$l)+$s+(' '*$r)
}
function Show-Box([string[]]$lines,[string]$color){
  $inner=2
  foreach($ln in $lines){$w=Get-DisplayWidth $ln;if($w -gt $inner){$inner=$w}}
  $inner+=4
  Write-Host ('   ╔'+('═'*$inner)+'╗') -ForegroundColor $color
  foreach($ln in $lines){
    $pad=$inner-2-(Get-DisplayWidth $ln);if($pad -lt 0){$pad=0}
    Write-Host ('   ║ '+$ln+(' '*$pad)+' ║') -ForegroundColor $color
  }
  Write-Host ('   ╚'+('═'*$inner)+'╝') -ForegroundColor $color
}
# 彩色提问：青色 ▸ 前缀 + 白色问题文本，回车后输入
function Ask([string]$question){
  Write-Host '   ▸ ' -ForegroundColor Cyan -NoNewline
  Write-Host $question -ForegroundColor White -NoNewline
  Write-Host '  ' -NoNewline
  Read-Host
}
# 阶段进度条：显示当前阶段与整体进度
$script:ProgressSteps=@('停止应用','解包','注入补丁','验证','打包','完成')
$script:ProgressIndex=0
function Show-Progress([string]$label){
  $script:ProgressIndex=[Math]::Min($script:ProgressIndex+1,$script:ProgressSteps.Count)
  $pct=[int]($script:ProgressIndex*100/$script:ProgressSteps.Count)
  $filled=[int]($pct/4)
  $bar=('█'*$filled)+('░'*(25-$filled))
  Write-Host ("   [进度] [{0}] {1}%  {2}" -f $bar,$pct,$label) -ForegroundColor Cyan
}
# 转圈动画（解包/打包等耗时命令执行期间显示）
function Invoke-WithSpinner([string]$label,[scriptblock]$Work){
  # 同步转圈动画（命令前短暂展示）+ 执行命令（不用后台线程，避免 PS5.1 退出码异常）
  $frames='⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏'
  for($i=0;$i -lt 6;$i++){
    Write-Host -NoNewline ("`r   [*] {0} {1}" -f $label,$frames[$i%10])
    Start-Sleep -Milliseconds 60
  }
  & $Work
  Write-Host ("`r   [OK] {0} 完成。    " -f $label) -ForegroundColor Green
}
function Show-MenuOption([string]$num,[string]$text,[int]$inner){
  $pad=$inner-5-(Get-DisplayWidth $text)
  if($pad -lt 0){$pad=0}
  Write-Host '   ║ ' -ForegroundColor Cyan -NoNewline
  Write-Host $num -ForegroundColor Green -NoNewline
  Write-Host ($text+(' '*$pad)+' ║') -ForegroundColor White
}
function Show-Menu {
  $inner=44
  Write-Host ('   ╔'+('═'*$inner)+'╗') -ForegroundColor Cyan
  Write-Host ('   ║ '+(Pad-Center ('Antigravity 背景美化工具  v'+$PatchVersion) ($inner-2))+' ║') -ForegroundColor White
  Write-Host ('   ║ '+(' '*($inner-2))+' ║') -ForegroundColor Cyan
  Show-MenuOption '[1]' ' 安装背景（选图 + 透明度 + 模糊度）' $inner
  Show-MenuOption '[2]' ' 卸载（恢复原始 app.asar）' $inner
  Show-MenuOption '[3]' ' 退出' $inner
  Write-Host ('   ║ '+(' '*($inner-2))+' ║') -ForegroundColor Cyan
  Write-Host ('   ╚'+('═'*$inner)+'╝') -ForegroundColor Cyan
}

# ==================== 核心逻辑 ====================
function Get-AntigravityAsarCandidates {
  $paths=New-Object 'System.Collections.Generic.List[string]'
  foreach($p in @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\resources\app.asar'),
    (Join-Path $env:LOCALAPPDATA 'Antigravity\resources\app.asar'),
    (Join-Path $env:ProgramFiles 'Antigravity\resources\app.asar'),
    (Join-Path ${env:ProgramFiles(x86)} 'Antigravity\resources\app.asar')
  )){ if($p -and (Test-Path -LiteralPath $p -PathType Leaf)){[void]$paths.Add([IO.Path]::GetFullPath([string]$p))} }
  if($paths.Count -eq 0){
    foreach($base in @($env:LOCALAPPDATA,$env:ProgramFiles,${env:ProgramFiles(x86)})|Where-Object{$_ -and(Test-Path -LiteralPath $_ -PathType Container)}){
      try{
        foreach($p in @(Get-ChildItem -LiteralPath $base -Filter 'app.asar' -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.FullName -match '(?i)\\Antigravity\\resources\\app\.asar$'}|Select-Object -ExpandProperty FullName)){
          if($p -and (Test-Path -LiteralPath $p -PathType Leaf)){[void]$paths.Add([IO.Path]::GetFullPath([string]$p))}
        }
      }catch{}
    }
  }
  @($paths|Select-Object -Unique)
}

function Get-AsarPath {
  $c=@(Get-AntigravityAsarCandidates)
  if($c.Count -eq 0){Fail '未找到 Antigravity 的 app.asar，请先安装 Antigravity 2.x。'}
  [string]$c[0]
}

function Stop-Antigravity {
  Get-Process -Name 'Antigravity' -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 1500
}

function Find-AsarTool {
  $candidates=@(
    (Get-Command 'asar.cmd' -ErrorAction SilentlyContinue|Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue),
    (Get-Command 'asar.exe' -ErrorAction SilentlyContinue|Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue),
    (Get-Command 'asar.ps1' -ErrorAction SilentlyContinue|Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue),
    (Get-Command 'asar' -ErrorAction SilentlyContinue|Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue)
  )|Where-Object{$_ -and (Test-Path -LiteralPath $_ -PathType Leaf)}
  foreach($p in @($candidates)){ if($p -match '\.ps1$'){continue}; return [pscustomobject]@{Kind='direct';Path=[string]$p} }
  $npx=Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
  if(-not $npx){$npx=Get-Command 'npx' -ErrorAction SilentlyContinue}
  if($npx){return [pscustomobject]@{Kind='npx';Path=[string]$npx.Path}}
  Fail '未找到 asar 工具，请安装 Node.js 22.12+ 与 @electron/asar。'
}

function Invoke-NativeWithArgs([string]$Executable,[string[]]$CliArgs){ & $Executable @CliArgs; if($LASTEXITCODE -ne 0){throw "ASAR 命令失败，退出码 $LASTEXITCODE。"} }

function Invoke-Asar([pscustomobject]$Tool,[string[]]$CliArgs){
  if($Tool.Kind -eq 'direct'){Invoke-NativeWithArgs -Executable $Tool.Path -CliArgs $CliArgs;return}
  Invoke-NativeWithArgs -Executable $Tool.Path -CliArgs (@('--yes','@electron/asar@4.2.1')+@($CliArgs))
}

function Assert-Asar([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){Fail "无效的 app.asar 路径: $Path"}
  if((Get-Item -LiteralPath $Path).Length -lt 100KB){Fail 'app.asar 体积异常（小于 100KB）。'}
}

function Read-Number([string]$label,[double]$min,[double]$max,[double]$default){
  while($true){
    $raw=Ask ("{0}（{1}~{2}，回车=默认 {3}）" -f $label,$min,$max,$default)
    if([string]::IsNullOrWhiteSpace($raw)){return $default}
    $v=0.0
    if([double]::TryParse($raw,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$v) -and $v -ge $min -and $v -le $max){return $v}
    Write-Host '   [!] 输入无效，请重新输入。' -ForegroundColor Yellow
  }
}

function Select-BackgroundImage{
  Add-Type -AssemblyName System.Windows.Forms
  $d=New-Object System.Windows.Forms.OpenFileDialog
  $d.Title='选择背景图片 (PNG/JPG/JPEG/WEBP/BMP)'
  $d.Filter='图片文件|*.png;*.jpg;*.jpeg;*.webp;*.bmp|所有文件|*.*'
  $d.Multiselect=$false
  if($d.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return $null}
  $d.FileName
}

function Convert-ToPng([string]$src,[string]$dst){
  if([IO.Path]::GetExtension($src).ToLowerInvariant() -eq '.png'){
    Copy-Item -LiteralPath $src -Destination $dst -Force
  }else{
    Add-Type -AssemblyName System.Drawing
    try{
      $img=[System.Drawing.Image]::FromFile($src)
      try{$img.Save($dst,[System.Drawing.Imaging.ImageFormat]::Png)}finally{$img.Dispose()}
    }catch{Fail ("无法解析图片 {0}：{1}" -f $src,$_.Exception.Message)}
  }
  if(-not(Test-Path -LiteralPath $dst -PathType Leaf)){Fail '图片转换失败。'}
  $len=(Get-Item -LiteralPath $dst).Length
  if($len -gt 15MB){Fail '图片超过 15MB 上限。'}
}

function Install-Mod([string]$ImagePath,[double]$OpacityVal,[double]$BlurVal,[switch]$HideMenuVal){
  $AsarPath=Get-AsarPath
  Assert-Asar $AsarPath
  $BackupPath="$AsarPath.antigravity-background.original.bak"
  $WorkDir=Join-Path $env:TEMP ("antigravity-bg-{0}" -f [Guid]::NewGuid().ToString('N'))
  $Unpacked=Join-Path $WorkDir 'app'
  $TempAsar=Join-Path $WorkDir 'app.asar'
  $inv=[System.Globalization.CultureInfo]::InvariantCulture

  # ---------- 选择图片 ----------
  if(-not $ImagePath){
    $nearby=Join-Path $BatDir 'background.png'
    if(Test-Path -LiteralPath $nearby -PathType Leaf){
      $ans=Ask '检测到 background.png，使用它吗？（Y=使用 / N=重新选择）'
      if($ans -match '^[yY]?$'){$ImagePath=$nearby}
    }
    if(-not $ImagePath){
      $ImagePath=Select-BackgroundImage
      if(-not $ImagePath){Write-Host '   [!] 已取消。' -ForegroundColor Yellow;return $false}
    }
  }
  if(-not(Test-Path -LiteralPath $ImagePath -PathType Leaf)){Fail ("找不到图片文件: {0}" -f $ImagePath)}

  $opacity=0.2; $blur=0
  if($OpacityVal -ge 0){$opacity=$OpacityVal}else{$opacity=Read-Number '背景透明度' 0.0 1.0 0.2}
  if($BlurVal -ge 0){$blur=$BlurVal}else{$blur=Read-Number '背景模糊度(像素)' 0 50 0}
  $scale=1.0; $position='center center'; $brightness=1.0; $saturation=1.0; $enabled=$true
  $hideMenu=$false
  if($HideMenuVal){
    $hideMenu=$true
  }else{
    $ans=Ask '隐藏顶部菜单栏（Antigravity/File/View/Window 按钮）？（Y=隐藏 / N=保留）'
    if($ans -match '^[yY]'){$hideMenu=$true}
  }

  Write-Host ''
  Show-Box @(
    ('图片   ：'+[IO.Path]::GetFileName($ImagePath)),
    ('透明度 ：'+$opacity.ToString($inv)),
    ('模糊度 ：'+$blur.ToString($inv)+' px'),
    ('菜单栏 ：'+$(if($hideMenu){'已隐藏'}else{'保留'}))
  ) 'Yellow'
  $confirm=Ask '确认安装？（Y=确认 / 其他=取消）'
  if($confirm -notmatch '^[yY]'){Write-Host '   [!] 已取消。' -ForegroundColor Yellow;return $false}

  $Tool=Find-AsarTool
  Info "使用 ASAR 工具: $($Tool.Path)"
  Show-Progress '停止应用'
  Stop-Antigravity
  New-Item -ItemType Directory -Path $WorkDir -Force|Out-Null

  Show-Progress '解包'
  Invoke-WithSpinner '正在解包 app.asar' { Invoke-Asar $Tool @('extract',$AsarPath,$Unpacked) }
  if(-not(Test-Path -LiteralPath $Unpacked -PathType Container)){Fail '解包失败：未产生输出目录。'}

  $UtilsPath=Join-Path $Unpacked 'dist\utils.js'
  if(-not(Test-Path -LiteralPath $UtilsPath -PathType Leaf)){Fail '未找到 dist/utils.js，此版本应用结构不同。'}
  $Utils=[IO.File]::ReadAllText($UtilsPath)

  if($Utils.Contains('ANTIGRAVITY_BACKGROUND_MOD_')){
    Warn '检测到旧补丁，先恢复原版再重新安装 ...'
    if(Test-Path -LiteralPath $BackupPath -PathType Leaf){
      Copy-Item -LiteralPath $BackupPath -Destination $AsarPath -Force
      Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
      New-Item -ItemType Directory -Path $WorkDir -Force|Out-Null
      $Unpacked=Join-Path $WorkDir 'app';$TempAsar=Join-Path $WorkDir 'app.asar'
      Invoke-WithSpinner '正在解包 app.asar' { Invoke-Asar $Tool @('extract',$AsarPath,$Unpacked) }
      if(-not(Test-Path -LiteralPath $UtilsPath -PathType Leaf)){Fail '恢复原版后重新解包失败。'}
      $Utils=[IO.File]::ReadAllText($UtilsPath)
    }else{Fail '发现旧补丁但没有原始备份，请先重装 Antigravity 后再试。'}
  }

  $installDir=Join-Path $Unpacked 'dist'
  $installedBg=Join-Path $installDir 'antigravity-background.png'
  Convert-ToPng $ImagePath $installedBg

  $customCss=Join-Path $BatDir 'custom.css'
  if(Test-Path -LiteralPath $customCss -PathType Leaf){
    Copy-Item -LiteralPath $customCss -Destination (Join-Path $installDir 'custom.css') -Force
    Info '已打包自定义样式 custom.css'
  }

  Show-Progress '注入补丁'

  # ---------- 原生标题栏按钮背景适配（采样壁纸右上角颜色，替代纯黑） ----------
  try{
    Add-Type -AssemblyName System.Drawing
    $img=[System.Drawing.Bitmap]::FromFile($ImagePath)
    try{
      $px=$img.GetPixel([int]($img.Width*0.85),[int]($img.Height*0.1))
      $cr=[int]($px.R*0.5);$cg=[int]($px.G*0.5);$cb=[int]($px.B*0.5)
      $hex=('#{0:X2}{1:X2}{2:X2}' -f $cr,$cg,$cb)
      if($Utils.Contains('color: backgroundColor,')){
        $Utils=$Utils.Replace('color: backgroundColor,',('color: "'+$hex+'",'))
        Info "标题栏按钮背景适配为壁纸色调: $hex"
      }
    }finally{$img.Dispose()}
  }catch{ Warn ("标题栏背景适配跳过：{0}" -f $_.Exception.Message) }

  $Injection=@'
// ANTIGRAVITY_BACKGROUND_MOD_V4
'use strict';
const fs = require('fs');
const path = require('path');
const MOD_ENABLED = __BG_ENABLED__;
const BG_OVERLAY = __BG_OVERLAY__;
const BG_BLUR = __BG_BLUR__;
const BG_SCALE = __BG_SCALE__;
const BG_POSITION = __BG_POSITION_JSON__;
const BG_BRIGHTNESS = __BG_BRIGHTNESS__;
const BG_SATURATION = __BG_SATURATION__;
const HIDE_MENU = __HIDE_MENU__;
const BG_FILE = path.join(__dirname, 'antigravity-background.png');
let BG_DATA_URI = '';
let CUSTOM_CSS = '';
try { BG_DATA_URI = 'data:image/png;base64,' + fs.readFileSync(BG_FILE).toString('base64'); }
catch (e) { console.error('[Antigravity Background Mod] background read failed:', e); }
try { CUSTOM_CSS = fs.readFileSync(path.join(__dirname, 'custom.css'), 'utf8'); }
catch (e) { CUSTOM_CSS = ''; }
function installBackground(win) {
  const payload = JSON.stringify(BG_DATA_URI);
  // ---- 模糊分层体系：所有控件模糊度联动背景模糊 ----
  const SIDEBAR_BLUR = Math.min(BG_BLUR + 18, 60);          // 侧栏
  const PANEL_BLUR = SIDEBAR_BLUR;                           // 卡片/设置面板 = 与侧栏一致
  const SUB_BLUR = Math.max(SIDEBAR_BLUR - 8, 10);           // 次级控件（按钮/悬停底）
  const FLOAT_BLUR = Math.min(SIDEBAR_BLUR + 10, 70);        // 浮层（对话框）
  const MENU_BLUR = FLOAT_BLUR;                              // 顶部应用菜单（模糊加深）
  const INPUT_BLUR = Math.max(SIDEBAR_BLUR - 14, 8);         // 输入框
  const cssText =
    // ============ 1. 深色主题变量 ============
    ':root{--color-background:transparent!important;--background:transparent!important;' +
    '--color-sidebar:rgba(13,13,18,0.52)!important;' +
    '--color-card:rgba(15,15,20,0.6)!important;' +
    '--color-card-border:rgba(255,255,255,0.07)!important;' +
    '--color-secondary:rgba(24,24,30,0.52)!important;' +
    '--color-muted:rgba(24,24,30,0.5)!important;' +
    '--color-sidebar-secondary:rgba(24,24,30,0.5)!important;' +
    '--color-sidebar-muted:rgba(24,24,30,0.45)!important;' +
    '--color-overlay-default:rgba(8,8,14,0.55)!important;' +
    '--color-foreground:#eaeaf0!important;' +
    '--color-muted-foreground:rgba(206,206,214,0.78)!important;' +
    '--radius-md:10px!important;--radius-lg:12px!important;--radius-xl:14px!important;--radius-2xl:18px!important;}' +
    // ============ 2. 浅色主题变量（自动适配切换） ============
    'body.theme-light{--color-sidebar:rgba(248,248,250,0.6)!important;' +
    '--color-card:rgba(250,250,252,0.65)!important;' +
    '--color-card-border:rgba(0,0,0,0.07)!important;' +
    '--color-secondary:rgba(235,235,240,0.62)!important;' +
    '--color-muted:rgba(235,235,240,0.55)!important;' +
    '--color-sidebar-secondary:rgba(235,235,240,0.6)!important;' +
    '--color-sidebar-muted:rgba(235,235,240,0.5)!important;' +
    '--color-overlay-default:rgba(240,240,245,0.5)!important;' +
    '--color-foreground:#1a1a1f!important;' +
    '--color-muted-foreground:rgba(88,88,98,0.85)!important;}' +
    // ============ 3. 透明基座（壁纸直透） ============
    'html,body{background:transparent!important;}' +
    '#root,#app,[data-testid="root"],.bg-background,.theme-standalone{background:transparent!important;}' +
    // ============ 4. 壁纸层 / 遮罩层 ============
    'body::before{content:"";position:fixed;inset:0;z-index:-1;pointer-events:none;' +
    'background-image:url(' + payload + ');background-size:cover;' +
    'background-position:' + BG_POSITION + ';background-repeat:no-repeat;background-attachment:fixed;' +
    'transform:scale(' + BG_SCALE + ');' +
    'filter:blur(' + BG_BLUR + 'px) brightness(' + BG_BRIGHTNESS + ') saturate(' + BG_SATURATION + ');' +
    'animation:agbg-fade .9s ease-out both;}' +
    'body::after{content:"";position:fixed;inset:0;z-index:-1;pointer-events:none;' +
    'background:rgba(8,8,14,' + BG_OVERLAY + ');animation:agbg-fade 1.15s ease-out .15s both;}' +
    // ============ 5. 毛玻璃分层（L2 侧栏 / L3 卡片 / L4 次级 / L6 输入框） ============
    // 仅最外层容器保留 backdrop-filter，内部嵌套禁用，避免重复模糊与合成层膨胀
    'body{-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility;}' +
    '.bg-sidebar{background-color:var(--color-sidebar)!important;' +
    'backdrop-filter:blur(' + SIDEBAR_BLUR + 'px) saturate(1.35)!important;' +
    '-webkit-backdrop-filter:blur(' + SIDEBAR_BLUR + 'px) saturate(1.35)!important;}' +
    '.bg-sidebar .bg-sidebar:not([class*="menu-border"]):not([role="menu"]):not([role="dialog"]):not([role="tooltip"]){backdrop-filter:none!important;-webkit-backdrop-filter:none!important;}' +
    // 侧栏内部区块：更透的底色 + 圆角（消除"黑色直角块"观感）
    '.bg-sidebar .bg-sidebar{background-color:rgba(13,13,18,0.38)!important;border-radius:10px!important;}' +
    'body.theme-light .bg-sidebar .bg-sidebar{background-color:rgba(248,248,250,0.42)!important;}' +
    '.bg-sidebar .bg-secondary,.bg-sidebar .bg-sidebar-secondary{background-color:rgba(24,24,30,0.4)!important;}' +
    'body.theme-light .bg-sidebar .bg-secondary,body.theme-light .bg-sidebar .bg-sidebar-secondary{background-color:rgba(235,235,240,0.45)!important;}' +
    // ============ 设置窗口：磨砂玻璃（窗口+导航+设置项分层模糊） ============
    '[role="dialog"][class*="settings"],[role="dialog"][class*="preferences"],[class*="settings"],[class*="preferences"]{' +
    'background-color:rgba(14,14,20,0.72)!important;' +
    'backdrop-filter:blur(' + FLOAT_BLUR + 'px) saturate(1.4)!important;' +
    '-webkit-backdrop-filter:blur(' + FLOAT_BLUR + 'px) saturate(1.4)!important;z-index:99998!important;}' +
    'body.theme-light [role="dialog"][class*="settings"],body.theme-light [class*="preferences"]{background-color:rgba(248,248,252,0.82)!important;}' +
    // 设置窗口内部：左侧导航磨砂 + 设置项分组/行磨砂（排除输入类）
    '[class*="settings"] .bg-sidebar,[class*="preferences"] .bg-sidebar{background-color:var(--color-sidebar)!important;' +
    'backdrop-filter:blur(' + SIDEBAR_BLUR + 'px) saturate(1.35)!important;' +
    '-webkit-backdrop-filter:blur(' + SIDEBAR_BLUR + 'px) saturate(1.35)!important;border-radius:0!important;}' +
    '[class*="settings"] .border-border:not(input):not(textarea):not([contenteditable="true"]){background-color:rgba(24,24,30,0.35)!important;' +
    'backdrop-filter:blur(18px) saturate(1.25)!important;' +
    '-webkit-backdrop-filter:blur(18px) saturate(1.25)!important;}' +
    '[class*="settings"] .bg-secondary\\/20{background-color:rgba(24,24,30,0.28)!important;' +
    'backdrop-filter:blur(14px) saturate(1.2)!important;' +
    '-webkit-backdrop-filter:blur(14px) saturate(1.2)!important;}' +
    'body.theme-light [class*="settings"] .border-border:not(input):not(textarea):not([contenteditable="true"]){background-color:rgba(240,240,245,0.4)!important;}' +
    'body.theme-light [class*="settings"] .bg-secondary\\/20{background-color:rgba(235,235,240,0.3)!important;}' +
    '.bg-card{background-color:var(--color-card)!important;' +
    'backdrop-filter:blur(' + PANEL_BLUR + 'px) saturate(1.3)!important;' +
    '-webkit-backdrop-filter:blur(' + PANEL_BLUR + 'px) saturate(1.3)!important;}' +
    '.bg-card .bg-card:not([role="menu"]):not([role="dialog"]):not([role="tooltip"]){backdrop-filter:none!important;-webkit-backdrop-filter:none!important;}' +
    '.bg-card-border{background-color:var(--color-card-border)!important;}' +
    '.bg-secondary,.bg-sidebar-secondary{background-color:var(--color-secondary)!important;' +
    'backdrop-filter:blur(' + SUB_BLUR + 'px) saturate(1.2)!important;' +
    '-webkit-backdrop-filter:blur(' + SUB_BLUR + 'px) saturate(1.2)!important;}' +
    '.bg-muted,.bg-sidebar-muted{background-color:var(--color-muted)!important;' +
    'backdrop-filter:blur(' + SUB_BLUR + 'px) saturate(1.15)!important;' +
    '-webkit-backdrop-filter:blur(' + SUB_BLUR + 'px) saturate(1.15)!important;}' +
    '.bg-sidebar .bg-secondary,.bg-sidebar .bg-sidebar-secondary,.bg-sidebar .bg-muted,.bg-sidebar .bg-sidebar-muted{backdrop-filter:none!important;-webkit-backdrop-filter:none!important;}' +
    '.bg-overlay-default{background-color:var(--color-overlay-default)!important;backdrop-filter:blur(2px)!important;}' +
    // 下拉选择列表：portal 到 body 的浮层，需置于所有对话框/菜单之上（100000 绝对最高层）
    '[role="listbox"]{position:relative!important;z-index:100000!important;}' +
    // 下拉列表的定位容器（z-[6000]）与对话框同层时须高于 dialog（99998），否则容器连同列表被 dialog 盖住
    '[class*="z-[6000]"]{z-index:99998!important;}' +
    'input:not([type="file"]),textarea,select,[contenteditable="true"]{background-color:rgba(24,24,30,0.55)!important;' +
    'backdrop-filter:blur(' + INPUT_BLUR + 'px)!important;' +
    '-webkit-backdrop-filter:blur(' + INPUT_BLUR + 'px)!important;border-radius:10px!important;}' +
    'body.theme-light input:not([type="file"]),body.theme-light textarea,body.theme-light select,body.theme-light [contenteditable="true"]{background-color:rgba(250,250,252,0.7)!important;}' +
    // ============ 6. 顶部应用菜单（独立于 sidebar 的高层浮层） ============
    '[class*="menu-border"]{z-index:99999!important;' +
    'background-color:rgba(18,18,26,0.92)!important;' +
    'backdrop-filter:blur(' + MENU_BLUR + 'px) saturate(1.5)!important;' +
    '-webkit-backdrop-filter:blur(' + MENU_BLUR + 'px) saturate(1.5)!important;' +
    'box-shadow:0 10px 36px rgba(0,0,0,0.4)!important;' +
    'border-radius:12px!important;' +
    'animation:agbg-pop .15s ease-out!important;}' +
    'body.theme-light [class*="menu-border"]{background-color:rgba(250,250,252,0.92)!important;' +
    'box-shadow:0 10px 36px rgba(0,0,0,0.16)!important;}' +
    // ============ 7. 对话框 / 弹层浮层 ============
    '[role="dialog"],[role="menu"],[role="tooltip"]{background-color:rgba(14,14,20,0.72)!important;' +
    'backdrop-filter:blur(' + FLOAT_BLUR + 'px) saturate(1.4)!important;' +
    '-webkit-backdrop-filter:blur(' + FLOAT_BLUR + 'px) saturate(1.4)!important;' +
    'z-index:99998!important;animation:agbg-pop .18s ease-out!important;}' +
    '[data-radix-popper-content-wrapper]{z-index:99997!important;}' +
    'body.theme-light [role="dialog"],body.theme-light [role="menu"],body.theme-light [role="tooltip"]{background-color:rgba(248,248,252,0.82)!important;}' +
    // ============ 8. 动画 / 过渡 ============
    '@keyframes agbg-fade{from{opacity:0}to{opacity:1}}' +
    '@keyframes agbg-pop{from{opacity:0;transform:scale(.97) translateY(6px)}to{opacity:1;transform:none}}' +
    '[data-state="open"]{animation:agbg-pop .2s ease-out!important;}' +
    '.bg-card,.bg-card-border,.bg-secondary,.bg-muted,.bg-sidebar-secondary,.bg-sidebar-muted{transition:background-color .25s ease,transform .18s ease,box-shadow .25s ease!important;}' +
    '.bg-card:not([class*="h-full"]):not([class*="h-screen"]):hover{transform:translateY(-1px);box-shadow:0 4px 20px rgba(0,0,0,0.22)!important;}' +
    '.bg-secondary:hover,.bg-sidebar-secondary:hover{transform:translateY(-1px);}' +
    // ============ 9. 滚动条 / 选区 ============
    '::-webkit-scrollbar{width:9px;height:9px}::-webkit-scrollbar-track{background:transparent}' +
    '::-webkit-scrollbar-thumb{background:rgba(255,255,255,0.14);border-radius:5px;border:2px solid transparent;background-clip:padding-box}' +
    '::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,0.28);border:2px solid transparent;background-clip:padding-box}' +
    'body.theme-light ::-webkit-scrollbar-thumb{background:rgba(0,0,0,0.18);border:2px solid transparent;background-clip:padding-box}' +
    'body.theme-light ::-webkit-scrollbar-thumb:hover{background:rgba(0,0,0,0.3);border:2px solid transparent;background-clip:padding-box}' +
    '::selection{background:rgba(0,122,204,0.35)!important}' +
    CUSTOM_CSS;
  const jsCode = '(()=>{' +
    'const ID="antigravity-background-mod-v4";' +
    'const remove=()=>{const e=document.getElementById(ID);if(e)e.remove();};' +
    'remove();' +
    (MOD_ENABLED ? '' : 'return;') +
    'const css=document.createElement("style");css.id=ID;' +
    'css.textContent=' + JSON.stringify(cssText) + ';' +
    '(document.head||document.documentElement).appendChild(css);' +
    '})();' +
    ';window.__agbgIdeHider||((window.__agbgIdeHider=1),(function(){' +
    'const hb=()=>{for(const b of document.querySelectorAll("button")){' +
    'if((b.textContent||"").trim().includes("Install IDE")){b.style.display="none";}}};' +
    'hb();new MutationObserver(hb).observe(document.body,{childList:true,subtree:true});' +
    '})());' +
    (HIDE_MENU ? ';window.__agbgMenuHider||((window.__agbgMenuHider=1),(function(){' +
      'const hb=()=>{for(const b of document.querySelectorAll("button")){' +
      'const t=(b.textContent||"").trim();' +
      'if(t==="Antigravity"||t==="File"||t==="View"||t==="Window"){b.style.display="none";}}};' +
      'hb();new MutationObserver(hb).observe(document.body,{childList:true,subtree:true});' +
      '})());' : '');
  const apply = () => {
    win.webContents.executeJavaScript(jsCode, true).catch(()=>{});
  };
  win.webContents.on('did-finish-load', apply);
  win.webContents.on('did-navigate-in-page', apply);
  win.webContents.on('did-frame-finish-load', apply);
  setTimeout(apply,500); setTimeout(apply,1500);
}
module.exports={installBackground};
'@
    $Injection=$Injection.Replace('__BG_ENABLED__',($(if($enabled){'true'}else{'false'})))
    $Injection=$Injection.Replace('__BG_OVERLAY__',$opacity.ToString($inv))
    $Injection=$Injection.Replace('__BG_BLUR__',$blur.ToString($inv))
    $Injection=$Injection.Replace('__BG_SCALE__',$scale.ToString($inv))
    $Injection=$Injection.Replace('__BG_POSITION_JSON__',(ConvertTo-Json $position -Compress))
    $Injection=$Injection.Replace('__BG_BRIGHTNESS__',$brightness.ToString($inv))
    $Injection=$Injection.Replace('__BG_SATURATION__',$saturation.ToString($inv))
    $Injection=$Injection.Replace('__HIDE_MENU__',($(if($hideMenu){'true'}else{'false'})))
    $injectPath=Join-Path $installDir 'backgroundInjection.js'
    [IO.File]::WriteAllText($injectPath,$Injection,[Text.UTF8Encoding]::new($false))

  # ---------- 修补 utils.js ----------
  $importRegex='const\s+loadingOverlay_1\s*=\s*require\(([''\"])\./loadingOverlay\1\);'
  $m=[regex]::Match($Utils,$importRegex)
  if(-not $m.Success){Fail '未找到 loadingOverlay 引用，无法注入（应用结构可能已变化）。'}
  $importLine='/* ANTIGRAVITY_BACKGROUND_MOD_V4 */ const backgroundInjection_1 = require("./backgroundInjection");'
  $Utils=$Utils.Insert($m.Index+$m.Length,"`r`n"+$importLine)

  $loadRegex='void\s+win\.loadURL\(url\);'
  $lm=[regex]::Match($Utils,$loadRegex)
  if(-not $lm.Success){Fail '未找到 loadURL 调用，无法注入（应用结构可能已变化）。'}
  $hook='(0, backgroundInjection_1.installBackground)(win);'
  $Utils=$Utils.Insert($lm.Index,"    $hook`r`n")
  [IO.File]::WriteAllText($UtilsPath,$Utils,[Text.UTF8Encoding]::new($false))

  # ---------- 验证 ----------
  $verify=[IO.File]::ReadAllText($UtilsPath)
  if(-not $verify.Contains($Marker)){Fail '验证失败：补丁标记缺失。'}
  if(-not $verify.Contains('backgroundInjection_1')){Fail '验证失败：import 缺失。'}
  if(-not $verify.Contains('backgroundInjection_1.installBackground')){Fail '验证失败：hook 缺失。'}
  if(-not(Test-Path -LiteralPath $injectPath -PathType Leaf)){Fail '验证失败：注入模块缺失。'}
  if(-not(Test-Path -LiteralPath $installedBg -PathType Leaf)){Fail '验证失败：背景图片缺失。'}
  Ok '补丁内容验证通过。'
  Show-Progress '验证'

  # ---------- 备份 ----------
  if(-not(Test-Path -LiteralPath $BackupPath -PathType Leaf)){
    Info '创建原始 app.asar 备份 ...'
    Copy-Item -LiteralPath $AsarPath -Destination $BackupPath -Force
  }else{Ok "原始备份已存在: $BackupPath"}

  # ---------- 打包 + 原子替换 ----------
  Show-Progress '打包'
  Invoke-WithSpinner '正在打包 app.asar' { Invoke-Asar $Tool @('pack',$Unpacked,$TempAsar) }
  if(-not(Test-Path -LiteralPath $TempAsar -PathType Leaf)){Fail '打包失败：未产生 app.asar。'}
  if((Get-Item -LiteralPath $TempAsar).Length -lt 100KB){Fail '打包结果异常（小于 100KB）。'}

  $Swap="$AsarPath.antigravity-background.swap.bak"
  if(Test-Path -LiteralPath $Swap){Remove-Item -LiteralPath $Swap -Force -ErrorAction SilentlyContinue}
  Move-Item -LiteralPath $AsarPath -Destination $Swap -Force
  try{
    Move-Item -LiteralPath $TempAsar -Destination $AsarPath -Force
    Remove-Item -LiteralPath $Swap -Force -ErrorAction SilentlyContinue
  }catch{
    if(Test-Path -LiteralPath $Swap -PathType Leaf){Move-Item -LiteralPath $Swap -Destination $AsarPath -Force}
    throw
  }

  # ---------- 保存图片到批处理旁边，方便下次安装 ----------
  try{
    $savedBg=Join-Path $BatDir 'background.png'
    if($ImagePath -ne $savedBg){Copy-Item -LiteralPath $ImagePath -Destination $savedBg -Force}
  }catch{}

  Show-Progress '完成'
  Write-Host ''
  Show-Box @(
    ('Antigravity 背景补丁 v'+$PatchVersion+' 安装完成'),
    '现在可以启动 Antigravity 了'
  ) 'Green'
  return $true
}

function Uninstall-Mod{
  $AsarPath=Get-AsarPath
  $BackupPath="$AsarPath.antigravity-background.original.bak"
  if(-not(Test-Path -LiteralPath $BackupPath -PathType Leaf)){Fail "未找到原始备份：$BackupPath`n可能尚未安装本补丁，或备份已被删除。"}
  Info "找到: $AsarPath"
  Info '停止 Antigravity ...'
  Stop-Antigravity
  Copy-Item -LiteralPath $BackupPath -Destination $AsarPath -Force
  Write-Host ''
  Show-Box @('已恢复原始 app.asar','现在可以正常使用 Antigravity') 'Green'
  return $true
}

# ==================== 主流程 ====================
try {
  if($Uninstall){ Uninstall-Mod; exit 0 }
  if($Image){ Install-Mod -ImagePath $Image -OpacityVal $Opacity -BlurVal $Blur -HideMenuVal:$HideMenu; exit 0 }
  $done=$false
  while(-not $done){
    Show-Menu
    Write-Host ''
    $choice=Ask '请选择 (1/2/3)'
    switch($choice){
      '1'{ if(Install-Mod -ImagePath $null -OpacityVal -1 -BlurVal -1 -HideMenuVal:$HideMenu){$done=$true} }
      '2'{ if(Uninstall-Mod){$done=$true} }
      '3'{ Write-Host ''; Show-Box @('感谢使用，再见！') 'DarkCyan'; exit 0 }
      default{ Write-Host '   [!] 无效选择，请重新输入。' -ForegroundColor Yellow }
    }
  }
  exit 0
} catch {
  Write-Host ''
  Show-Box @(('出错了：'+$_.Exception.Message)) 'Red'
  Write-Host ''
  exit 1
}
::</PS>
