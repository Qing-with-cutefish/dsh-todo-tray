#Requires -Version 5.1
<#
    dsh-todo-tray · 待办托盘 · v2.0 / 0.3.40
    ==========================================================
    Windows 自带 PowerShell 5.1 + WinForms；零依赖、不联网、不写注册表；开机自启只写「启动」文件夹（0.3.36 起新装默认开）。

    这个文件装下整个托盘程序：数据/配置的公共函数在 todo-lib.ps1（CLI 与托盘共用），
    其余全部在这里。全文件按 19 个模块顺序排列，每个模块用 #region 标出，模块内按
    「谁被谁调用」从底层往上排。找代码、改功能先看下面的地图。

    程序结构（按文件顺序）
    ----------------------------------------------------------
    M01 全局参数与状态        命令行参数、$script: 运行期状态总表、EXSTYLE 常量
    M02 基础设施              日志 / 数据戳 / 消息框 / 退出看门狗
    M03 数据层                todos.json 读写、勾选、排序字段、星级名额
    M04 配置与几何            config 读写、窗口默认值、屏幕工作区、尺寸夹取
    M05 Win32 · 穿透与悬停    原生互操作、EXSTYLE/LAYERED、交互态、悬停计时
    M06 主面板                面板构建（顶栏/搜索/列表/底栏）、显示与隐藏
    M07 拖动与收边            标题条拖动、缩放抓手、拖到边收成侧边条
    M08 小鲸鱼与滑动动画      小鲸鱼窗口、收起/展开、换边 130ms、滑入/滑出
    M09 收起箭头 · 图钉 · 焦点 侧向箭头、图钉、透明度口径、窗口夹边、按钮焦点
    M10 冒泡                  小鲸鱼旁的待办气泡：轮播、外观、置顶、6 秒
    M11 托盘图标              GDI 画未完成条数、悬停提示
    M12 列表行与卷帘          行控件工厂、卷帘逐行铺开、编辑态拖动、状态刷新
    M13 删除 · 撤销 · 编辑     二次确认、真删、15 秒撤销、编辑弹窗入口
    M14 多清单                清单下拉、新建/改名/移除、清单管理窗
    M15 弹窗 · 设置 · 导出 · 提醒  新增窗、设置窗、导出菜单、Toast、到期提醒
    M16 启动项与过滤          开机自启（只写启动文件夹）、搜索/清单过滤
    M17 小窗 · 计时 · 退出     子窗口计数、自动隐藏、展开后 3 秒收回、退出
    M18 无界面自检            250 项断言，在临时目录跑，不碰真实数据
    M19 主流程                Mutex → 初始化 → 托盘 → Application.Run

    各模块包含的函数
    ----------------------------------------------------------
    M02 基础设施                   日志、数据戳、消息框、退出看门狗
    M03 数据层                    读/写 todos.json、勾选、排序字段
    M04 配置与窗口几何                config 读写、ui/窗口默认值、屏幕工作区、尺寸夹取
    M05 Win32 · 穿透与悬停          原生互操作、EXSTYLE/LAYERED、交互态切换、悬停计时
    M06 主面板                    面板构建（顶栏/搜索/列表/底栏）、显示与隐藏
    M07 拖动与收边                  标题条拖动、缩放抓手、拖到边收成侧边条
    M08 小鲸鱼与滑动动画               小鲸鱼窗口、收起/展开、换边与滑入滑出
    M09 收起箭头 · 图钉 · 焦点         侧向箭头、图钉、透明度口径、窗口夹边界、按钮焦点清理
    M10 冒泡                     小鲸鱼旁边的待办气泡：轮播、外观、置顶、显示 6 秒
    M11 托盘图标                   GDI 画未完成条数图标、悬停提示
    M12 列表行与卷帘                 行控件工厂、卷帘逐行铺开、编辑态拖动、状态刷新
    M13 删除 · 撤销 · 编辑           二次确认、真删、15 秒撤销、编辑弹窗入口
    M14 多清单                    清单下拉、新建/改名/移除、清单管理窗
    M15 弹窗 · 设置 · 导出 · 提醒      新增窗、设置窗、导出菜单、Toast、到期提醒
    M16 启动项与过滤                 开机自启（只写启动文件夹）、搜索/清单过滤
    M17 小窗 · 计时 · 退出           子窗口计数、自动隐藏、展开后 3 秒收回、退出
    M18 无界面自检                  250 项断言，在临时目录跑，不碰真实数据
    [M02] Get-DataStamp / Get-LogFilePath / Show-MessageBox / Start-ExitWatchdog
    [M03] Load-State / Set-ItemStatus / Update-LegacyFields / Get-PrioUsage
    [M04] Get-UiSettings / Save-UiSettings / Apply-UiSettings / Get-DefaultWindowSettings / Get-WindowSettings / Save-WindowSettings / Get-ScreenArea / Get-ClampedSize / Save-PanelGeometry
    [M05] Initialize-Native / Initialize-ShellNative / Set-PanelChrome / Set-WinAlpha / Sync-PanelLayeredAlpha / Apply-PanelExStyle / Set-Interactive / Test-PointInForm / Invoke-PanelDeactivate / Update-PointerState / Start-StateTimers / Stop-StateTimers / Get-DeepWindowAt
    [M06] Initialize-Ui / Initialize-Fonts / New-HeaderPanel / Show-Panel / Hide-Panel / Toggle-Panel
    [M07] Position-DragGrip / Add-PanelDragHandlers / Start-PanelDrag / Update-PanelDrag / Enter-BarPhase / Exit-BarPhase / End-PanelDrag / Get-EdgeSpot / Get-BarTop
    [M08] Initialize-Whale / Set-WhalePosition / Show-Whale / Hide-Whale / Set-Collapsed / Start-SlideAnim / Update-WhaleSideFromX / Start-WhaleDrag / Update-WhaleDrag / End-WhaleDrag
    [M09] Initialize-CollapseTab / Position-CollapseTab / Show-CollapseTab / Hide-CollapseTab / Update-CollapseChrome / Save-PinState / Toggle-Pin / Update-PinVisual / Get-PanelOpacityValue / Get-ClampedWindowPos / Set-PanelCursor / Clear-FocusCue / Register-ButtonFocusFix
    [M10] Test-BubbleContext / Initialize-Bubble / Set-BubbleRegion / Apply-BubbleExStyle / Set-BubblePosition / Get-BubbleIntervalSeconds / Restart-BubbleSchedule / Get-BubbleEntry / Show-Bubble / Hide-Bubble
    [M11] New-TrayIconObject / Update-TrayIcon
    [M12] New-EntryRow / New-WarnRow / New-DeletedRow / New-EmptyLabel / Get-RowSpecs / Get-BlendColor / Add-RowSpec / Clear-Rows / Build-Rows / Start-RowRoll / Step-RowRoll / Stop-RowRoll / Set-RowHover / Toggle-RowCheck / Toggle-EditMode / Start-RowDrag / Update-RowDrag / End-RowDrag / Update-Status / Refresh-All / Watch-Data / On-CheckChanged
    [M13] Confirm-Delete / Invoke-DeleteConfirmed / Get-ListItemRaw / Invoke-UndoDelete / Invoke-DeleteEntry / Show-EditDialog
    [M14] Update-ListCombo / Sync-ListCombo / Add-TrayList / New-ListDialog / Show-NewListDialog / Get-RawListsKey / Confirm-RemoveList / Rename-TrayList / Remove-TrayList / Update-ListManagerList / New-ListManagerDialog / Show-ListManager
    [M15] New-AddDialog / Show-AddDialog / New-SettingsDialog / Show-Settings / Invoke-Export / New-ExportMenuForm / Show-ExportMenu / Initialize-Toast / Show-Toast / Hide-Toast / Get-NotifySettings / Get-NotifyStatePath / Initialize-NotifyState / Save-NotifyState / Get-DueChecks / Show-DueBalloon / Invoke-Reminders
    [M16] Get-AutostartPath / Test-Autostart / Set-Autostart / Test-FilterMatch / Get-FilteredEntries
    [M17] Enter-ChildWindow / Exit-ChildWindow / Test-PointerInPanel / Restart-PeekCountdown / Start-AutoHide / Stop-AutoHide / Exit-App
    [M18] Invoke-SelfTest

    常见改动入口
    ----------------------------------------------------------
      托盘点数 / 图标        Update-TrayIcon / New-TrayIconObject
      列表排序 / 过滤        Load-State / Get-RowSpecs / Test-FilterMatch
      面板布局 / 控件        Initialize-Ui（顶栏、搜索、列表、底栏、抓手都在这里）
      穿透 / 悬停 / 透明度   Set-Interactive / Update-PointerState / Get-PanelOpacityValue
      小鲸鱼 / 3 秒收回      Set-Collapsed / Show-Whale / Exit-ChildWindow / Restart-PeekCountdown
      图钉 / 拖动边界        Toggle-Pin / Update-PanelDrag / Get-ClampedWindowPos
      冒泡                  Show-Bubble / Get-BubbleEntry / Restart-BubbleSchedule
      设置项                Get-UiSettings / Save-UiSettings / New-SettingsDialog
      清单（新建/改名/移除）  Add-TrayList / Rename-TrayList / Remove-TrayList
      自检                  Invoke-SelfTest（加断言：Check '名字' (条件) '细节'）

    最近几版（完整 0.1.0~0.3.40 变更史见同目录 CHANGELOG.md）
    ----------------------------------------------------------
      0.3.40  修「点导出提示框后收起箭头消失、3 秒自动收回停」：提示框点击不再重显面板
      0.3.39  小鲸鱼摆尾两摆 → 四摆 1400ms；鼠标移到鲸鱼上也摇
      0.3.38  小鲸鱼会摆尾巴（从侧边出现 / 冒气泡时，40ms 一拍只重画小窗）
      0.3.34  代码整理：按模块重排 + 模块地图 + 变更史外移到 CHANGELOG.md（无行为变化）
      0.3.33  冒泡窗每次显示补 HWND_TOPMOST，全屏置顶程序压不住
      0.3.32  恢复「展开 3 秒自动收回」；关设置后侧向箭头不再消失；焦点框覆盖全

    用法：
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File todo-tray.ps1
      powershell.exe ... -File todo-tray.ps1 -ConfigPath "D:\x\data\config.json"
      powershell.exe ... -File todo-tray.ps1 -SelfTest      # 无界面自检，ExitCode 0 = 通过

    注意：本文件必须存成 UTF-8 带 BOM（Windows PowerShell 5.1 否则按 GBK 读，中文乱码/语法错）。
#>

[CmdletBinding()]
param(
    # 配置文件路径。留空 = %USERPROFILE%\.dsh\deepseek-todo\config.json
    [string]$ConfigPath = '',
    # 测试用：启动 N 秒后自动退出（验证「退出后无残留」）
    [int]$ExitAfter = 0,
    # 测试用：启动 1 秒后把 UI 线程故意卡住 N 秒（验证退出看门狗）
    [int]$HangSeconds = 0,
    # 调试用：把面板和「新增」对话框渲染成 PNG（不弹窗、不抢焦点）
    [string]$DumpUi = '',
    # 调试用：把托盘图标导出成 PNG（给文档/测试看效果）
    [string]$DumpIcons = '',
    # 启动即显示面板（调试/截图用，正常双击启动不需要）
    [switch]$ShowPanelOnStart,
    # 无界面自检（在临时目录跑，不碰任何真实数据）
    [switch]$SelfTest,
    # 不写日志
    [switch]$NoLog,
    # 测试用：模拟「本机没有 Excel/WPS」，让导出走 CSV 回落（河豚验 UI 回落用）
    [switch]$DisableXlsxForTest
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# 命令行显式配置路径单独存一份：$ConfigPath 与 $script:ConfigPath 是同一个变量，
# 后面一改就会被 Resolve-ConfigPath 误当成「显式指定」（便携模式自检踩到）。
$script:ParamConfigPath = $ConfigPath

$script:AppVersion = '0.3.40'
$script:AppName    = 'dsh-todo-tray'
$script:Stage      = 'v1.8'

$script:BaseDir    = ''
$script:NoLog      = [bool]$NoLog
$script:HasNative  = $false
$script:IconHandle = [IntPtr]::Zero
$script:OldIconHandles = New-Object System.Collections.ArrayList
$script:HideTime   = [datetime]::MinValue
$script:LastStamp  = ''
$script:Exiting    = $false
$script:JustDone   = @{}      # 'listIndex|itemId' → $true（本次面板会话内刚勾掉，仍显示成划线）
$script:Reminded   = @{}      # 'listIndex|itemId' → 已提醒过的 due 文本
$script:FilterListIndex = -1  # -1 = 全部清单
$script:FilterText = ''
$script:SuppressListCombo = $false   # 0.3.12：重建清单下拉/程序改选项时不触发业务事件
$script:ListComboSig = ''             # 0.3.13：清单名签名，变了就重画下拉（外部改名/加删也能跟上）
$script:SuppressDeactivate = $false
$script:LastReminderCheck = [datetime]::MinValue
$script:ScriptPath = ''
$script:SelfTestMessages = New-Object System.Collections.ArrayList
# 0.2.0 · R3 设置（ui 段）与自动隐藏/淡出用的运行时状态
$script:UiSettings   = $null
$script:AutoHideTimer = $null
$script:FadeTimer    = $null
$script:SettingsForm = $null
$script:SetModeAlways = $null
$script:SetModeAuto   = $null
$script:SetHide       = $null
$script:SetOpacity    = $null
$script:SetOpacityLbl = $null
$script:SetTop        = $null
$script:SetAutostart  = $null
$script:SetPeek       = $null
# 0.2.2 · M3 编辑态 / 拖动 / 删除
$script:EditMode     = $false
$script:EditButton   = $null
$script:DragEntry    = $null
$script:DragValid    = $true
$script:DragTargetIndex = -1
$script:DragTargetPrio  = 0
$script:DlgEdit      = $null
$script:ConfirmTitle = ''
# 0.3.9 · 删除：15 秒撤销窗口（删除已生效，列表里留一行「已删除」+ 撤销按钮）
$script:PendingDeletes       = @()
$script:PendingDeleteSeconds = 15
$script:PendingDeleteTimer   = $null
$script:SelfTestConfirmResult = $null   # 仅自检用：$null=弹确认框；$true/$false=直接当已确认/已取消
# 0.2.3 · M4 导出 + 完成后 5 秒消失
$script:DoneFadeTimer = $null
$script:DoneFadeAt    = @{}
$script:ExportForm    = $null
$script:ExportCsvRadio = $null
$script:ExportXlsxRadio = $null
$script:BtnAdd = $null
$script:BtnRefresh = $null
$script:SetBtnClose = $null
# 0.3.0 · M5-M8 双态 / 几何 / 小鲸鱼
$script:InteractMode   = $false   # $false=穿透态  $true=交互态
$script:ChromeLevel    = 'none'   # none / hint / active（1px 边框提示）
$script:HoverSince     = $null    # 光标进入面板的时刻（穿透态累计 0.6 秒）
$script:LeaveSince     = $null    # 光标离开面板的时刻（交互态累计 1.5 秒）
$script:HoverTimer     = $null
$script:LeaveTimer     = $null
$script:ShellHook      = $null
$script:AllowHide      = $false
$script:WinCfg         = $null    # config.ui.window 的解析结果
$script:DragTimer      = $null    # 0.3.6：20ms 轮询拖动（收成侧边栏后窗口已 Hide，Capture 会丢）
$script:ChildOpen      = 0        # 0.3.6：打开中的小窗口数（新增/编辑/删除确认/设置/导出）
$script:SelfTestPointerInside = $null   # 仅自检用：$null=读真实光标；$true/$false=强制"鼠标在/不在面板内"
$script:PanelCollapsed = $false   # 已收成侧边小鲸鱼
$script:PanelDrag      = $null    # 拖动/缩放会话 {Mode,GrabX,GrabY,OffX,OffY,BaseW,BaseH,Phase,Edge}
$script:DragGrip       = $null    # 右下角 18×18 缩放手柄

# 0.3.6 拖拽参数（收边/脱边的磁滞区间，避免边上来回抖）
$script:BarWidth    = 24   # 侧边栏宽
$script:BarHeight   = 72   # 侧边栏高
$script:EdgeTouchPx = 10   # 窗口边进到离屏幕边 ≤ 这个距离 → 收成侧边栏
$script:EdgeLeavePx = 60   # 收着时把窗口拖离边 ≥ 这个距离 → 恢复成窗口
$script:Whale          = $null
$script:WhaleTimer     = $null
$script:TopmostTimer   = $null   # 0.3.37：置顶守护（每 3 秒把可见的鲸鱼/冒泡/钉住面板抬回置顶层）
$script:WhaleDeadline  = $null
$script:WhaleWagTimer  = $null   # 0.3.38：摆尾动画（40ms 一拍，700ms 两摆）
$script:WhaleWagStart  = $null
$script:WhaleWagOffset = 0
$script:WhaleWagMs     = 1400
$script:PeekExpanded   = $false   # 由小鲸鱼展开（3 秒后自动收回）
$script:WhaleTip       = $null
$script:WhaleDrag      = $null   # 0.3.20：小鲸鱼拖拽会话 {StartY, BaseTop, Moved}
# 0.3.25 · 图钉
$script:Pinned         = $false  # 钉住：不收回侧边栏、开穿透、可拖动
$script:BtnPin         = $null
$script:PinTip         = $null
$script:HeadPanel      = $null
# 0.3.21 · 滑动动画（鲸鱼换边 / 面板展开、收回）
$script:SlideTimer     = $null
$script:SlideJob       = $null   # @{Ctrl,From,To,Start,Ms}
$script:SlideThen      = $null   # 动画结束后要做的收尾 @{Kind='collapse',Reason,FromWhale}
$script:OpenFillTimer  = $null   # 0.3.23：滑入开始后再补 Refresh-All（别把建行的耗时压在起滑前）
# 0.3.24 · 卷帘式逐行出现
$script:RollTimer      = $null
$script:RollQueue      = @()
$script:RollIndex      = 0
$script:RollWidth      = 360
$script:RollPending    = $false
$script:FadeRows       = New-Object System.Collections.ArrayList   # 正在淡入的行 @{Row,From,To,Step}
$script:RollFadeSteps  = 8
$script:AnimOff        = $false  # 自检/无动画：直接落位
if ($SelfTest) { $script:AnimOff = $true }
# 0.3.14 · 侧边展开标记 / 收起箭头 / 小鲸鱼右键菜单
$script:FromWhale       = $false   # 当前面板是不是从侧边（小鲸鱼）展开的 → 用收起箭头代替 ×
$script:BtnClose        = $null    # 面板右上角的 ×（侧边展开时隐藏）
$script:CollapseTab     = $null    # 贴面板侧边的收起箭头（独立小窗）
$script:CollapseTabSide = 'right'  # 0.3.16：right=面板在右半边（箭头贴左沿、朝右）；left 反之
$script:WhaleMenu       = $null
# 0.3.11 · 小鲸鱼冒泡（6 秒一个，按 3★→2★→普通 的顺序轮着显示；鼠标完全点不到）
$script:Bubble          = $null
$script:BubbleTimer     = $null
$script:BubbleText      = ''
$script:BubblePrio      = 1
$script:BubbleNextAt    = $null   # 下一个冒泡的时刻
$script:BubbleHideAt    = $null   # 当前这个的收起时刻
$script:BubbleIndex     = 0       # 轮到第几条（升序轮播，跑到头再从头）
$script:BubbleSeconds   = 6       # 每个冒泡显示多久（用户 2026-11-09 定，后续可改）
$script:SelfTestForceBubble = $null   # 仅自检：\$null=按真实可见性判；\$true/\$false=强制
$script:ExTransparent  = 0x00000020
$script:ExLayered      = 0x00080000
$script:ExNoActivate   = 0x08000000
$script:ExToolWindow   = 0x00000080

# ============================================================
#  公共函数（JSON / 配置 / 清单 / 写盘 / 文件锁）都在 todo-lib.ps1，CLI 用同一份
# ============================================================

. (Join-Path $PSScriptRoot 'todo-lib.ps1')


# ============================================================
#  M02 基础设施 —— 日志、数据戳、消息框、退出看门狗
# ============================================================
#region M02 基础设施
function Get-DataStamp {
    $sb = New-Object System.Text.StringBuilder
    $stampFiles = @($script:ConfigPath)
    foreach ($l in @(Get-Lists)) { $stampFiles += $l.Path }
    foreach ($f in $stampFiles) {
        if (Test-Path -LiteralPath $f) {
            try { [void]$sb.Append($f).Append('=').Append((Get-Item -LiteralPath $f).LastWriteTimeUtc.Ticks).Append(';') }
            catch { [void]$sb.Append($f).Append('=?;') }
        } else {
            [void]$sb.Append($f).Append('=-;')
        }
    }
    return $sb.ToString()
}

# P8：万一 UI 线程被对话框/异常卡住，3 秒后硬退，避免留下僵尸进程
function Get-LogFilePath {
    if ([string]::IsNullOrWhiteSpace($script:BaseDir)) { return '' }
    return (Join-Path $script:BaseDir 'logs\todo-tray.log')
}

function Show-MessageBox {
    param([string]$Text, [string]$Title = '待办托盘')
    try {
        [void][System.Windows.Forms.MessageBox]::Show($Text, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch { }
}

function Start-ExitWatchdog {
    if (-not ('DshTodoTray.Keeper' -as [type])) { return }
    try {
        [DshTodoTray.Keeper]::Arm(3000, (Get-LogFilePath))
    } catch { }
}

#endregion

# ============================================================
#  M03 数据层 —— 读/写 todos.json、勾选、排序字段
# ============================================================
#region M03 数据层
function Load-State {
    $lists   = @(Get-Lists)
    $entries = @()
    $errors  = @()
    $pending = 0
    $overdue = 0
    $nextDue = $null
    $now     = Get-Date

    foreach ($l in $lists) {
        if (-not (Test-Path -LiteralPath $l.Path)) {
            $errors += ('数据文件不存在：' + $l.Path)
            continue
        }
        $doc = Read-JsonFile $l.Path
        if ($null -eq $doc) {
            $errors += ('数据文件读不出（JSON 可能损坏）：' + $l.Path)
            continue
        }
        $seq = 0
        foreach ($it in @(Get-Prop $doc 'items' @())) {
            $orderFallback = $seq
            $seq++
            if ($null -eq $it) { continue }
            $status = [string](Get-Prop $it 'status' 'todo')
            if ([string]::IsNullOrWhiteSpace($status)) { $status = 'todo' }
            $itemId  = [string](Get-Prop $it 'id' '')
            $key     = ('{0}|{1}' -f $l.Index, $itemId)
            $isDone  = ($status -eq 'done')
            $dueText = [string](Get-Prop $it 'due' '')
            $dueDate = ConvertTo-DateOrNull $dueText
            $isOverdue = ((-not $isDone) -and ($null -ne $dueDate) -and ($dueDate -lt $now))
            # R5/R8：prio 缺省 1；order 缺省按文件现有顺序（升级时会落盘补齐，见 Update-LegacyFields）
            $prio = [int](Get-Prop $it 'prio' 1)
            if ($prio -lt 1) { $prio = 1 }
            if ($prio -gt 3) { $prio = 3 }
            $orderVal = [int](Get-Prop $it 'order' $orderFallback)

            if (-not $isDone) {
                $pending++
                if ($isOverdue) { $overdue++ }
                if ($null -ne $dueDate) {
                    if ($null -eq $nextDue -or $dueDate -lt $nextDue) { $nextDue = $dueDate }
                }
            } else {
                if (-not $script:JustDone.ContainsKey($key)) { continue }
            }

            $tags = @(Get-Prop $it 'tags' @())
            $entries += [pscustomobject]@{
                ListIndex   = $l.Index
                ListName    = $l.Name
                ItemId      = $itemId
                Title       = [string](Get-Prop $it 'title' '(无标题)')
                Status      = $status
                DueText     = $dueText
                DueDate     = $dueDate
                Overdue     = $isOverdue
                Tags        = $tags
                CreatedText = [string](Get-Prop $it 'created' '')
                DoneAt      = ConvertTo-DateOrNull ([string](Get-Prop $it 'done_at' ''))
                Prio        = $prio
                Order       = $orderVal
            }
        }
    }

    # R8：显示顺序 = prio 降序 → 组内 order 升序；**不再按到期/标题重排**
    # 已完成条目固定排最后（v1 行为，勾掉的行留在本次面板底部）
    $sortProps = @(
        @{ Expression = { if ($_.Status -eq 'done') { 1 } else { 0 } } },
        @{ Expression = { 0 - [int]$_.Prio } },
        @{ Expression = { [int]$_.Order } },
        @{ Expression = { [int]$_.ListIndex } },
        @{ Expression = { [string]$_.ItemId } }
    )
    $sorted = @($entries | Sort-Object -Property $sortProps)

    return [pscustomobject]@{
        Lists   = $lists
        Entries = $sorted
        Errors  = $errors
        Pending = $pending
        Overdue = $overdue
        NextDue = $nextDue
    }
}

function Set-ItemStatus {
    param([int]$ListIndex, [string]$ItemId, [bool]$Done)
    $lists = @(Get-Lists)
    if ($ListIndex -lt 0 -or $ListIndex -ge $lists.Count) { Write-Log ('勾选写回：清单序号越界 ' + $ListIndex) 'WARN'; return $false }
    $list = $lists[$ListIndex]
    if (-not (Test-Path -LiteralPath $list.Path)) { Write-Log ('勾选写回：清单文件不存在 ' + $list.Path) 'WARN'; return $false }
    $doc = Read-JsonFile $list.Path
    if ($null -eq $doc) { Write-Log ('勾选写回：清单读不出 ' + $list.Path) 'WARN'; return $false }

    $items = @(Get-Prop $doc 'items' @())
    $found = $false
    foreach ($it in $items) {
        if ($null -eq $it) { continue }
        if ([string](Get-Prop $it 'id' '') -eq $ItemId) {
            $found = $true
            if ($Done) {
                Set-Prop $it 'status' 'done'
                Set-Prop $it 'done_at' (Get-NowStamp)
            } else {
                Set-Prop $it 'status' 'todo'
                Set-Prop $it 'done_at' ''
            }
        }
    }
    if (-not $found) { Write-Log ('勾选写回：清单里找不到条目 ' + $ItemId) 'WARN'; return $false }

    Set-Prop $doc 'items' @($items)
    if ($null -ne $doc.PSObject.Properties['updatedAt']) { Set-Prop $doc 'updatedAt' (Get-NowStamp) }
    else { Set-Prop $doc 'updatedAt' (Get-NowStamp) }

    $text = (ConvertTo-JsonText $doc) + "`n"
    try {
        # 落盘前先自查：写出去的东西必须还能被解析，且条数不变
        $check = ConvertFrom-Json -InputObject $text
        if (@(Get-Prop $check 'items' @()).Count -ne $items.Count) {
            throw '序列化自检失败：条数不一致'
        }
    } catch {
        Write-Log ('写回前自检失败，已放弃写入：' + $_.Exception.Message) 'ERROR'
        return $false
    }

    try {
        Save-TextAtomic -Path $list.Path -Text $text
    } catch {
        Write-Log ('写回失败 ' + $list.Path + ' :: ' + $_.Exception.Message) 'ERROR'
        return $false
    }

    Write-Log ('{0} {1}/{2}' -f $(if ($Done) { '完成' } else { '取消完成' }), $list.Name, $ItemId)
    return $true
}

# ============================================================
#  0.2.1 · M2 数据升级：老条目补 prio / order（只补一次，幂等）
#  规则：没有 prio 的当 1★；没有 order 的按「文件现有顺序」补 0..n-1。
#  绝不能丢条目、不能改语义 —— 写盘前由 Save-TodoDoc 做条数自检。
# ============================================================
function Update-LegacyFields {
    $changed = 0
    foreach ($l in @(Get-Lists)) {
        if (-not (Test-Path -LiteralPath $l.Path)) { continue }
        $doc = Read-JsonFile $l.Path
        if ($null -eq $doc) { continue }
        $items = @(Get-Prop $doc 'items' @())
        $dirty = $false
        for ($i = 0; $i -lt $items.Count; $i++) {
            $it = $items[$i]
            if ($null -eq $it) { continue }
            if ($null -eq (Get-Prop $it 'prio' $null)) { Set-Prop $it 'prio' 1; $dirty = $true }
            if ($null -eq (Get-Prop $it 'order' $null)) { Set-Prop $it 'order' $i; $dirty = $true }
        }
        if (-not $dirty) { continue }
        try {
            Save-TodoDoc -Doc $doc -Path $l.Path | Out-Null
            $changed++
            Write-Log ('老数据补 prio/order：' + $l.Name + ' / ' + $items.Count + ' 条')
        } catch {
            Write-Log ('老数据补字段失败 ' + $l.Path + ' :: ' + $_.Exception.Message) 'ERROR'
        }
    }
    return $changed
}

# 星级名额占用：按**未完成**条目统计（已完成的不占名额，否则「先取消现有的」无法兑现）
function Get-PrioUsage {
    # 注意：这里必须用 Hashtable，不能用 [ordered]@{} —— OrderedDictionary 同时有
    # this[int index]（按位置）和 this[object key] 两个索引器，$counts[$p] 会绑到
    # 位置索引上，items 少时直接抛 ArgumentOutOfRange（5.1 上实测）。
    $counts = @{ 1 = 0; 2 = 0; 3 = 0 }
    foreach ($l in @(Get-Lists)) {
        if (-not (Test-Path -LiteralPath $l.Path)) { continue }
        $doc = Read-JsonFile $l.Path
        if ($null -eq $doc) { continue }
        foreach ($it in @(Get-Prop $doc 'items' @())) {
            if ($null -eq $it) { continue }
            if ([string](Get-Prop $it 'status' 'todo') -eq 'done') { continue }
            $p = [int](Get-Prop $it 'prio' 1)
            if ($p -lt 1 -or $p -gt 3) { $p = 1 }
            $counts[$p]++
        }
    }
    return $counts
}

#endregion

# ============================================================
#  M04 配置与窗口几何 —— config 读写、ui/窗口默认值、屏幕工作区、尺寸夹取
# ============================================================
#region M04 配置与窗口几何
# ============================================================
#  0.2.0 · R3 设置（config.json 的 ui 段）
#  ui = { mode: "auto"|"always", hideSeconds: 5|15|30|60,
#         opacity: 30~100, topmost: true|false }
#  口径：auto = N 秒后自动隐藏（默认 15 秒、100% 不透明）；
#        always = 常驻悬浮（右上角固定、置顶、不自动隐藏、默认 85%）。
# ============================================================
function Get-UiSettings {
    param($Config = $null)
    if ($null -eq $Config) { $Config = Get-Config }
    $mode = 'auto'
    $hide = 15
    $opacity = 0
    $top = $true
    $bubbleOn = $true
    $bubbleMax = 60
    $pinned = $false
    $hoverMs = 1500
    if ($null -ne $Config) {
        $ui = Get-Prop $Config 'ui' $null
        if ($null -ne $ui) {
            $m = [string](Get-Prop $ui 'mode' 'auto')
            if ($m -eq 'always' -or $m -eq 'auto') { $mode = $m }
            $hs = [int](Get-Prop $ui 'hideSeconds' 15)
            if (@(5, 15, 30, 60) -contains $hs) { $hide = $hs }
            $op = [int](Get-Prop $ui 'opacity' 0)
            if ($op -ge 30 -and $op -le 100) { $opacity = $op }
            $top = [bool](Get-Prop $ui 'topmost' $true)
            # 0.3.25：图钉（钉住 = 不收回侧边栏、开穿透、可拖动）
            $pinned = [bool](Get-Prop $ui 'pinned' $false)
            # 0.3.27：悬停多久进交互（毫秒）
            $hm = [int](Get-Prop $ui 'hoverMs' 1500)
            if ($hm -ge 200 -and $hm -le 5000) { $hoverMs = $hm }
            # 0.3.11：小鲸鱼冒泡（默认开，最长 60 秒）
            $bub = Get-Prop $ui 'bubble' $null
            if ($null -ne $bub) {
                $bubbleOn = [bool](Get-Prop $bub 'enabled' $true)
                $bm = [int](Get-Prop $bub 'maxSeconds' 60)
                if ($bm -ge 10 -and $bm -le 60) { $bubbleMax = $bm }
            }
        }
    }
    # 没写透明度时按模式给默认：常驻 85、自动隐藏 100（需求 Q3）
    if ($opacity -eq 0) {
        if ($mode -eq 'always') { $opacity = 85 } else { $opacity = 100 }
    }
    return [pscustomobject]@{
        Mode        = $mode
        HideSeconds = $hide
        Opacity     = $opacity
        TopMost     = [bool]$top
        BubbleEnabled    = [bool]$bubbleOn
        BubbleMaxSeconds = [int]$bubbleMax
        Pinned           = [bool]$pinned
        HoverMs          = [int]$hoverMs
    }
}

function Save-UiSettings {
    param($Settings)
    $cfg = Get-Config
    if ($null -eq $cfg) {
        New-DefaultConfig -Path $script:ConfigPath
        $cfg = Get-Config
    }
    if ($null -eq $cfg) { return $false }
    # 0.3.11：冒泡设置（老调用方没带这两个字段时按默认走，别把功能关掉）
    $bOn = $true
    if ($null -ne $Settings.PSObject.Properties['BubbleEnabled']) { $bOn = [bool]$Settings.BubbleEnabled }
    $bMax = 60
    if ($null -ne $Settings.PSObject.Properties['BubbleMaxSeconds']) { $bMax = [int]$Settings.BubbleMaxSeconds }
    if ($bMax -lt 10 -or $bMax -gt 60) { $bMax = 60 }
    # 0.3.27：悬停进交互（毫秒；没带就沿用旧值/默认 1500）
    $hMs = 1500
    $oldHover = 0
    $oldUiForHover = Get-Prop $cfg 'ui' $null
    if ($null -ne $oldUiForHover) { $oldHover = [int](Get-Prop $oldUiForHover 'hoverMs' 0) }
    if ($oldHover -ge 200 -and $oldHover -le 5000) { $hMs = $oldHover }
    if ($null -ne $Settings.PSObject.Properties['HoverMs']) {
        $tryHover = [int]$Settings.HoverMs
        if ($tryHover -ge 200 -and $tryHover -le 5000) { $hMs = $tryHover }
    }
    $ui = [ordered]@{
        mode        = [string]$Settings.Mode
        hideSeconds = [int]$Settings.HideSeconds
        opacity     = [int]$Settings.Opacity
        topmost     = [bool]$Settings.TopMost
        bubble      = [ordered]@{ enabled = $bOn; maxSeconds = $bMax }
        hoverMs     = [int]$hMs
    }
    # 0.3.0：ui.window 等新增键不能被「保存设置」冲掉
    $oldUi = Get-Prop $cfg 'ui' $null
    if ($null -ne $oldUi) {
        if ($oldUi -is [System.Collections.IDictionary]) {
            foreach ($k in $oldUi.Keys) { if (-not $ui.Contains($k)) { $ui[$k] = $oldUi[$k] } }
        } else {
            foreach ($p in $oldUi.PSObject.Properties) { if (-not $ui.Contains($p.Name)) { $ui[$p.Name] = $p.Value } }
        }
    }
    Set-Prop $cfg 'ui' $ui
    try {
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfg) + "`n")
    } catch {
        Write-Log ('保存设置失败: ' + $_.Exception.Message) 'ERROR'
        return $false
    }
    $script:UiSettings = Get-UiSettings -Config $cfg
    Write-Log ('设置已保存: mode={0} hide={1}s opacity={2}% topmost={3}' -f $ui.mode, $ui.hideSeconds, $ui.opacity, $ui.topmost)
    return $true
}

function Apply-UiSettings {
    if ($null -eq $script:UiSettings) { $script:UiSettings = Get-UiSettings }
    if ($null -eq $script:Form) { return }
    $ui = $script:UiSettings
    try { $script:Form.TopMost = [bool]$ui.TopMost } catch { }
    if ($script:Form.Visible) {
        try { $script:Form.Opacity = Get-PanelOpacityValue } catch { }
        Sync-PanelLayeredAlpha   # 0.3.3：改完透明度补 layered 属性，别让面板变"点不到"
        if ($script:HasNative) {
            try {
                # SWP_NOSIZE(1) | SWP_NOMOVE(2) | SWP_NOACTIVATE(16)
                $insert = if ($ui.TopMost) { [IntPtr](-1) } else { [IntPtr](-2) }
                [void][DshTodoTray.Win]::SetWindowPos($script:Form.Handle, $insert, 0, 0, 0, 0, 0x0013)
            } catch { }
        }
        Start-AutoHide
    }
    Restart-BubbleSchedule   # 0.3.11：设置一变，冒泡节奏重排
}

function Get-DefaultWindowSettings {
    $wa = Get-ScreenArea
    $h = [Math]::Min(560, $wa.Height - 96)
    if ($h -lt 240) { $h = 240 }
    return [pscustomobject]@{
        X = ($wa.Right - 420 - 12)
        Y = ($wa.Top + 12)
        W = 420
        H = $h
        Edge = 'none'
        Collapsed = $false
        WhaleSide = 'right'
        WhaleY = ($wa.Top + [int]($wa.Height / 2) - 36)
        AutoCollapseSeconds = 3
    }
}

# config.ui.window 读取；老 config 没这一段 → 全用默认（不许崩）
function Get-WindowSettings {
    param($Config = $null)
    $d = Get-DefaultWindowSettings
    if ($null -eq $Config) { $Config = Get-Config }
    if ($null -eq $Config) { return $d }
    $ui = Get-Prop $Config 'ui' $null
    $w = $null
    if ($null -ne $ui) { $w = Get-Prop $ui 'window' $null }
    if ($null -eq $w) { return $d }

    $wa = Get-ScreenArea
    $x = [int](Get-Prop $w 'x' $d.X)
    $y = [int](Get-Prop $w 'y' $d.Y)
    $ww = [int](Get-Prop $w 'w' $d.W)
    $hh = [int](Get-Prop $w 'h' $d.H)
    if ($ww -lt 320) { $ww = 320 }
    if ($hh -lt 240) { $hh = 240 }
    if ($ww -gt $wa.Width) { $ww = $wa.Width }
    if ($hh -gt $wa.Height) { $hh = $wa.Height }

    $edge = [string](Get-Prop $w 'edge' 'none')
    if (@('none', 'left', 'right') -notcontains $edge) { $edge = 'none' }

    $side = [string](Get-Prop $w 'whaleSide' 'right')
    if (@('left', 'right') -notcontains $side) { $side = 'right' }

    $acs = [int](Get-Prop $w 'autoCollapseSeconds' 3)
    if (@(0, 3, 10) -notcontains $acs) { $acs = 3 }

    $wy = [int](Get-Prop $w 'whaleY' $d.WhaleY)
    if ($wy -lt $wa.Top) { $wy = $wa.Top }
    if ($wy -gt ($wa.Bottom - 72)) { $wy = $wa.Bottom - 72 }

    return [pscustomobject]@{
        X = $x
        Y = $y
        W = $ww
        H = $hh
        Edge = $edge
        Collapsed = [bool](Get-Prop $w 'collapsed' $false)
        WhaleSide = $side
        WhaleY = $wy
        AutoCollapseSeconds = $acs
    }
}

function Save-WindowSettings {
    param($Settings)
    if ($null -eq $Settings) { return $false }
    $cfg = Get-Config
    if ($null -eq $cfg) {
        New-DefaultConfig -Path $script:ConfigPath
        $cfg = Get-Config
    }
    if ($null -eq $cfg) { return $false }

    # 合并写：保留 ui 段其它键（mode / hideSeconds / opacity / topmost）
    $oldUi = Get-Prop $cfg 'ui' $null
    $uiNode = [ordered]@{}
    if ($null -ne $oldUi) {
        if ($oldUi -is [System.Collections.IDictionary]) {
            foreach ($k in $oldUi.Keys) { $uiNode[$k] = $oldUi[$k] }
        } else {
            foreach ($p in $oldUi.PSObject.Properties) { $uiNode[$p.Name] = $p.Value }
        }
    }
    if ($uiNode.Count -eq 0) {
        $uiNode = [ordered]@{ mode = 'auto'; hideSeconds = 15; opacity = 100; topmost = $true }
    }
    $uiNode['window'] = [ordered]@{
        x                   = [int]$Settings.X
        y                   = [int]$Settings.Y
        w                   = [int]$Settings.W
        h                   = [int]$Settings.H
        edge                = [string]$Settings.Edge
        collapsed           = [bool]$Settings.Collapsed
        whaleSide           = [string]$Settings.WhaleSide
        whaleY              = [int]$Settings.WhaleY
        autoCollapseSeconds = [int]$Settings.AutoCollapseSeconds
    }
    Set-Prop $cfg 'ui' $uiNode
    try {
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfg) + "`n")
    } catch {
        Write-Log ('保存窗口几何失败: ' + $_.Exception.Message) 'ERROR'
        return $false
    }
    return $true
}

function Get-ScreenArea {
    return [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
}

function Get-ClampedSize {
    param([int]$W, [int]$H)
    if ($W -lt 320) { $W = 320 }
    if ($H -lt 240) { $H = 240 }
    return [pscustomobject]@{ W = $W; H = $H }
}

function Save-PanelGeometry {
    if ($null -eq $script:Form) { return }
    if ($null -eq $script:WinCfg) { $script:WinCfg = Get-WindowSettings }
    if ($null -eq $script:WinCfg) { return }
    $script:WinCfg.X = [int]$script:Form.Left
    $script:WinCfg.Y = [int]$script:Form.Top
    $script:WinCfg.W = [int]$script:Form.Width
    $script:WinCfg.H = [int]$script:Form.Height
    [void](Save-WindowSettings -Settings $script:WinCfg)
}

#endregion

# ============================================================
#  M05 Win32 · 穿透与悬停 —— 原生互操作、EXSTYLE/LAYERED、交互态切换、悬停计时
# ============================================================
#region M05 Win32 · 穿透与悬停
function Initialize-Native {
    try {
        if (-not ('DshTodoTray.Native' -as [type])) {
            Add-Type -Namespace DshTodoTray -Name Native -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern bool DestroyIcon(System.IntPtr hIcon);
'@
        }
        if (-not ('DshTodoTray.Win' -as [type])) {
            Add-Type -Namespace DshTodoTray -Name Win -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern int GetWindowLong(System.IntPtr hWnd, int nIndex);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern int SetWindowLong(System.IntPtr hWnd, int nIndex, int dwNewLong);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetWindowPos(System.IntPtr hWnd, System.IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);
public static void MakeNoActivate(System.IntPtr hWnd) {
    int ex = GetWindowLong(hWnd, -20);
    SetWindowLong(hWnd, -20, ex | 0x08000000);
}
'@
        }
        if (-not ('DshTodoTray.Keeper' -as [type])) {
            Add-Type -Namespace DshTodoTray -Name Keeper -MemberDefinition @'
private static System.Threading.Timer _t;
public static void Arm(int ms, string logPath) {
    _t = new System.Threading.Timer(delegate(object state) {
        try {
            if (!string.IsNullOrEmpty(logPath)) {
                string line = System.DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " [WARN] 看门狗到点，强制结束进程" + System.Environment.NewLine;
                System.IO.File.AppendAllText(logPath, line, System.Text.Encoding.UTF8);
            }
        } catch { }
        System.Environment.Exit(0);
    }, null, ms, System.Threading.Timeout.Infinite);
}
'@
        }
        $script:HasNative = $true
    } catch {
        $script:HasNative = $false
    }
}

# ============================================================
#  0.3.0 · M5 双态（穿透 / 交互）· M6 几何 · M7 小鲸鱼
#  穿透态 = WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE（鼠标点穿、不抢焦点）
#  交互态 = 去掉 TRANSPARENT / NOACTIVATE，1px 边框，可点可拖
#  穿透窗口收不到 WM_MOUSEMOVE，所以悬停由 100ms 定时器取 GetCursorPos 判定。
# ============================================================
function Initialize-ShellNative {
    if ('DshTodoTray.Win3' -as [type]) { return }
    Add-Type -ReferencedAssemblies @('System.Windows.Forms', 'System.Drawing') -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Windows.Forms;

namespace DshTodoTray
{
    public static class Win3
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct POINT { public int X; public int Y; }

        [StructLayout(LayoutKind.Sequential)]
        public struct WINDOWPOS
        {
            public IntPtr hwnd;
            public IntPtr hwndInsertAfter;
            public int x;
            public int y;
            public int cx;
            public int cy;
            public uint flags;
        }

        [DllImport("user32.dll")]
        public static extern bool GetCursorPos(out POINT p);

        [DllImport("user32.dll")]
        public static extern short GetAsyncKeyState(int vKey);

        // 0.3.6：拖动靠轮询左键状态 —— 收成侧边栏时窗口已 Hide，收不到 WM_LBUTTONUP
        public static bool LeftDown() { return (GetAsyncKeyState(0x01) & 0x8000) != 0; }

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr h);

        [DllImport("user32.dll")]
        public static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);

        [DllImport("user32.dll")]
        public static extern int GetWindowLong(IntPtr h, int i);

        [DllImport("user32.dll")]
        public static extern int SetWindowLong(IntPtr h, int i, int v);

        [DllImport("user32.dll")]
        public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);

        public static int ExStyle(IntPtr h) { return GetWindowLong(h, -20); }

        public static int SetEx(IntPtr h, int value)
        {
            int old = GetWindowLong(h, -20);
            SetWindowLong(h, -20, value);
            // SWP_NOSIZE(1) | SWP_NOMOVE(2) | SWP_NOZORDER(4) | SWP_FRAMECHANGED(0x20)
            SetWindowPos(h, IntPtr.Zero, 0, 0, 0, 0, 0x0027);
            return old;
        }

        // 0.3.3：只加 WS_EX_LAYERED 位、不给 layered 属性（SetLayeredWindowAttributes）的窗口，
        // 其表面与子窗口都不参与 WindowFromPoint / 真鼠标命中——鼠标直接穿透到桌面。
        // 所以设完 EXSTYLE 必须补一次 alpha（LWA_ALPHA）。
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetLayeredWindowAttributes(IntPtr h, uint colorKey, byte alpha, uint flags);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetLayeredWindowAttributes(IntPtr h, out uint colorKey, out byte alpha, out uint flags);

        public static bool SetAlpha(IntPtr h, int alpha)
        {
            if (alpha < 1) { alpha = 1; }      // alpha=0 = 看不见也点不到
            if (alpha > 255) { alpha = 255; }
            return SetLayeredWindowAttributes(h, 0, (byte)alpha, 0x00000002); // LWA_ALPHA
        }

        public static bool ReadAlpha(IntPtr h, out int alpha, out uint flags)
        {
            uint key;
            byte a;
            bool ok = GetLayeredWindowAttributes(h, out key, out a, out flags);
            alpha = (int)a;
            return ok;
        }

        public static Point Cursor()
        {
            POINT p;
            GetCursorPos(out p);
            return new Point(p.X, p.Y);
        }

        // 模拟 Win+D 发出的 WM_WINDOWPOSCHANGING(SWP_HIDEWINDOW)，返回处理后 flags 里是否已无隐藏位
        public static bool ProbeHide(IntPtr h, out uint flagsAfter)
        {
            WINDOWPOS wp = new WINDOWPOS();
            wp.hwnd = h;
            wp.flags = 0x0080; // SWP_HIDEWINDOW
            IntPtr p = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(WINDOWPOS)));
            try
            {
                Marshal.StructureToPtr(wp, p, false);
                SendMessage(h, 0x0046, IntPtr.Zero, p);
                WINDOWPOS back = (WINDOWPOS)Marshal.PtrToStructure(p, typeof(WINDOWPOS));
                flagsAfter = back.flags;
                return (back.flags & 0x0080u) == 0;
            }
            finally { Marshal.FreeHGlobal(p); }
        }

        public static IntPtr HitTest(IntPtr h, int screenX, int screenY)
        {
            int lp = ((screenY & 0xFFFF) << 16) | (screenX & 0xFFFF);
            return SendMessage(h, 0x0084, IntPtr.Zero, (IntPtr)lp);
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

        [DllImport("user32.dll")]
        public static extern IntPtr WindowFromPoint(POINT p);
        [DllImport("user32.dll")]
        public static extern IntPtr GetAncestor(IntPtr h, uint flags);
        [DllImport("user32.dll")]
        public static extern bool ScreenToClient(IntPtr h, ref POINT p);
        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr h, out RECT r);
        [DllImport("user32.dll")]
        public static extern IntPtr ChildWindowFromPointEx(IntPtr parent, POINT p, uint flags);

        public static IntPtr ChildAt(IntPtr parent, int x, int y)
        {
            POINT p; p.X = x; p.Y = y;
            return ChildWindowFromPointEx(parent, p, 3); // SKIPINVISIBLE|SKIPDISABLED
        }

        public static IntPtr WindowAt(int x, int y)
        {
            POINT p; p.X = x; p.Y = y;
            return WindowFromPoint(p);
        }

        public static IntPtr RootOf(IntPtr h) { return GetAncestor(h, 2); } // GA_ROOT

        public static int[] RectOf(IntPtr h)
        {
            RECT r; GetWindowRect(h, out r);
            return new int[] { r.Left, r.Top, r.Right, r.Bottom };
        }

        public static int[] ClientPointOf(IntPtr h, int screenX, int screenY)
        {
            POINT p; p.X = screenX; p.Y = screenY;
            ScreenToClient(h, ref p);
            return new int[] { p.X, p.Y };
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct CURSORINFO { public int cbSize; public int flags; public IntPtr hCursor; public POINT ptScreenPos; }
        [DllImport("user32.dll")]
        public static extern bool GetCursorInfo(ref CURSORINFO pci);
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        public static IntPtr Foreground() { return GetForegroundWindow(); }

        public static IntPtr CursorHandle()
        {
            CURSORINFO ci = new CURSORINFO();
            ci.cbSize = Marshal.SizeOf(typeof(CURSORINFO));
            GetCursorInfo(ref ci);
            return ci.hCursor;
        }
    }

    public class ShellHook : NativeWindow
    {
        public bool Interactive = false;
        public bool AllowHide = false;
        public int HeaderHeight = 46;
        public int DragMaxX = 316;
        public int CornerSize = 18;
        public int HiddenBlocked = 0;
        public int MinimizeBlocked = 0;

        protected override void WndProc(ref Message m)
        {
            const int WM_NCHITTEST = 0x0084;
            const int WM_WINDOWPOSCHANGING = 0x0046;
            const int WM_SYSCOMMAND = 0x0112;

            if (m.Msg == WM_WINDOWPOSCHANGING)
            {
                // M8：Win+D = ShowWindow(SW_HIDE) 走这条路，把 SWP_HIDEWINDOW 摘掉
                Win3.WINDOWPOS wp = (Win3.WINDOWPOS)Marshal.PtrToStructure(m.LParam, typeof(Win3.WINDOWPOS));
                if (!AllowHide && (wp.flags & 0x0080u) != 0)
                {
                    wp.flags &= ~0x0080u;
                    Marshal.StructureToPtr(wp, m.LParam, false);
                    HiddenBlocked++;
                }
            }
            else if (m.Msg == WM_NCHITTEST)
            {
                if (!Interactive) { m.Result = (IntPtr)(-1); return; } // HTTRANSPARENT
                Form f = Control.FromHandle(Handle) as Form;
                if (f != null)
                {
                    int lp = m.LParam.ToInt32();
                    int sx = (short)(lp & 0xFFFF);
                    int sy = (short)((lp >> 16) & 0xFFFF);
                    Point c = f.PointToClient(new Point(sx, sy));
                    int r = 0;
                    if (c.X >= f.ClientSize.Width - CornerSize && c.Y >= f.ClientSize.Height - CornerSize) r = 17; // HTBOTTOMRIGHT
                    else if (c.X >= 0 && c.X <= DragMaxX && c.Y >= 0 && c.Y <= HeaderHeight) r = 2;                 // HTCAPTION
                    if (r != 0) { m.Result = (IntPtr)r; return; }
                }
            }
            else if (m.Msg == WM_SYSCOMMAND)
            {
                if (((int)m.WParam & 0xFFF0) == 0xF020) { MinimizeBlocked++; m.Result = IntPtr.Zero; return; } // SC_MINIMIZE
            }
            base.WndProc(ref m);
        }

        public static ShellHook Hook(IntPtr h)
        {
            ShellHook s = new ShellHook();
            s.AssignHandle(h);
            return s;
        }
    }

    // WinForms 在 Show / Opacity / TopMost 变化时会用 CreateParams 重刷 EXSTYLE，
    // 把 SetWindowLong 设的穿透位冲掉。所以把「穿透/不抢焦点」做成窗体的固有参数。
    public class TrayForm : Form
    {
        public bool ClickThrough = true;
        public bool NoActivate = true;

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= 0x00080000; // WS_EX_LAYERED（透明度用）
                cp.ExStyle |= 0x00000080; // WS_EX_TOOLWINDOW（不进 Alt+Tab）
                if (ClickThrough) { cp.ExStyle |= 0x00000020; } else { cp.ExStyle &= ~0x00000020; }
                if (NoActivate) { cp.ExStyle |= 0x08000000; } else { cp.ExStyle &= ~0x08000000; }
                return cp;
            }
        }

        public void ApplyStyles()
        {
            try { UpdateStyles(); } catch { }
        }
    }
}
'@
}

function Set-PanelChrome {
    param([string]$Level)
    if ($null -eq $script:Form) { return }
    $script:ChromeLevel = $Level
    try {
        if ($Level -eq 'none') {
            $script:Form.Padding = New-Object System.Windows.Forms.Padding(0)
            $script:Form.BackColor = [System.Drawing.Color]::White
        } else {
            $script:Form.Padding = New-Object System.Windows.Forms.Padding(1)
            if ($Level -eq 'active') {
                $script:Form.BackColor = [System.Drawing.Color]::FromArgb(255, 64, 126, 214)
            } else {
                $script:Form.BackColor = [System.Drawing.Color]::FromArgb(255, 150, 182, 232)
            }
        }
    } catch { }
}

function Set-WinAlpha {
    # 0.3.4（T20261029-02 B-①）：WS_EX_LAYERED 只是位；不给属性，窗口表面/子窗口
    # 不参与合成，也不参与 WindowFromPoint / 真鼠标命中（屏上"不画"）。
    # alpha 下限 1：alpha=0 等于看不见也点不到。
    param([IntPtr]$Hwnd, [double]$Opacity)
    if ($Hwnd -eq [IntPtr]::Zero) { return $false }
    if (-not ('DshTodoTray.Win3' -as [type])) { return $false }
    $a = 255
    try { $a = [int][Math]::Round($Opacity * 255) } catch { }
    if ($a -lt 1) { $a = 1 }
    if ($a -gt 255) { $a = 255 }
    $ok = $false
    try { $ok = [DshTodoTray.Win3]::SetAlpha($Hwnd, $a) } catch { }
    return [bool]$ok
}

function Sync-PanelLayeredAlpha {
    # 0.3.3（T20261028-08）：只设 WS_EX_LAYERED 位、不给 layered 属性时，
    # 窗口表面和子窗口都不参与 WindowFromPoint / 真鼠标命中（鼠标落到桌面）。
    # 修法：每次设完 EXSTYLE、每次改完 Opacity，都补一次 SetLayeredWindowAttributes。
    # alpha 跟 Form.Opacity 同步，但下限 1 —— alpha=0 会连窗口一起"点不到"。
    if ($null -eq $script:Form) { return }
    if (-not ('DshTodoTray.Win3' -as [type])) { return }
    $h = [IntPtr]::Zero
    try { $h = $script:Form.Handle } catch { return }
    if ($h -eq [IntPtr]::Zero) { return }
    $reqAlpha = 255
    try { $reqAlpha = [int][Math]::Round(([double]$script:Form.Opacity) * 255) } catch { }
    if ($reqAlpha -lt 1) { $reqAlpha = 1 }
    if ($reqAlpha -gt 255) { $reqAlpha = 255 }
    $setOk = Set-WinAlpha -Hwnd $h -Opacity ([double]$script:Form.Opacity)
    $aNow = 0
    $flNow = [uint32]0
    $readOk = $false
    try { $readOk = [DshTodoTray.Win3]::ReadAlpha($h, [ref]$aNow, [ref]$flNow) } catch { }
    $script:LayeredOk = [bool]($setOk -and $readOk -and ($flNow -band 0x2) -and ($aNow -ge 1))
    $script:LayeredAlpha = [int]$aNow
    Write-Log ('[LAYERED] set={0} req={1} readback ok={2} alpha={3} flags=0x{4:X}' -f $setOk, $reqAlpha, $readOk, $aNow, $flNow)
}

function Apply-PanelExStyle {
    if ($null -eq $script:Form) { return }
    if (-not ('DshTodoTray.Win3' -as [type])) { return }
    try {
        # 先同步 CreateParams 的口径：WinForms 在 Show/Opacity/TopMost 变化时会拿它重刷 EXSTYLE
        if ($null -ne $script:Form.PSObject.Properties['ClickThrough']) {
            $script:Form.ClickThrough = (-not $script:InteractMode)
            $script:Form.NoActivate = (-not $script:InteractMode)
        }
        $h = $script:Form.Handle
        if ($h -eq [IntPtr]::Zero) { return }
        $ex = [DshTodoTray.Win3]::ExStyle($h)
        $ex = $ex -bor $script:ExLayered -bor $script:ExToolWindow
        if ($script:InteractMode) {
            $ex = $ex -band (-bnot $script:ExTransparent)
            $ex = $ex -band (-bnot $script:ExNoActivate)
        } else {
            $ex = $ex -bor $script:ExTransparent -bor $script:ExNoActivate
        }
        [void][DshTodoTray.Win3]::SetEx($h, $ex)
        Write-Log ('[EXSTYLE] 0x{0:X8} mode={1}' -f $ex, $(if ($script:InteractMode) { '交互' } else { '穿透' }))
        Sync-PanelLayeredAlpha
        if ($null -ne $script:ShellHook) { $script:ShellHook.Interactive = [bool]$script:InteractMode }
    } catch {
        Write-Log ('切态设置 EXSTYLE 失败: ' + $_.Exception.Message) 'ERROR'
    }
}

function Set-Interactive {
    param([bool]$On, [string]$Reason = '', [switch]$Focus)
    # 0.3.10：弹窗开着时不动面板的 EXSTYLE / 不抢焦点 ——
    # 改 EXSTYLE 会 SetWindowPos(SWP_FRAMECHANGED)，把输入焦点从弹窗的输入框上抢走。
    if ($script:ChildOpen -gt 0) { return }
    if ($script:InteractMode -eq $On) { return }
    $script:InteractMode = $On
    $script:HoverSince = $null
    $script:LeaveSince = $null
    Apply-PanelExStyle
    if ($On) {
        if ($null -ne $script:HoverTimer) { try { $script:HoverTimer.Stop() } catch { } }
        if ($null -ne $script:LeaveTimer) { try { $script:LeaveTimer.Start() } catch { } }
        Set-PanelChrome 'active'
        # P6：显式进入（托盘/鲸鱼）才抢一次焦点，auto 模式失焦才能收起；
        # 悬停进交互不抢焦点（P3：焦点留在下面那个程序）
        if ($Focus -and $null -ne $script:Form) {
            try { $script:Form.Activate() } catch { }
        }
        Start-AutoHide
    } else {
        if ($null -ne $script:LeaveTimer) { try { $script:LeaveTimer.Stop() } catch { } }
        if ($null -ne $script:Form -and $script:Form.Visible) {
            if ($null -ne $script:HoverTimer) { try { $script:HoverTimer.Start() } catch { } }
        }
        Set-PanelChrome 'none'
        # 0.3.28/0.3.29：回穿透态时按模式恢复透明度（钉住=配置值，侧边=100%）
        if ($null -ne $script:Form) {
            try { $script:Form.Opacity = Get-PanelOpacityValue } catch { }
            Sync-PanelLayeredAlpha
        }
    }
    Write-Log ('[STATE] ' + $(if ($On) { '交互态' } else { '穿透态' }) + ' 原因=' + $Reason)
}

function Test-PointInForm {
    param([int]$X, [int]$Y)
    if ($null -eq $script:Form) { return $false }
    $b = $script:Form.Bounds
    return ($X -ge $b.Left -and $X -lt $b.Right -and $Y -ge $b.Top -and $Y -lt $b.Bottom)
}

# P6：失焦处理。auto 收起（0.2.3b 原行为），always 只回穿透不收起。
function Invoke-PanelDeactivate {
    if ($null -eq $script:Form) { return }
    if ($script:ChildOpen -gt 0) { return }   # 小窗口开着：大面板不收起、也不退交互态
    if (-not [bool]$script:Pinned) {
        # 0.3.25：贴边面板一直可点，失焦不退穿透；auto 模式仍按原逻辑收起
        if ($null -ne $script:UiSettings -and $script:UiSettings.Mode -eq 'always') { return }
        if ($script:EditMode) { return }
        if (-not $script:PanelCollapsed) { Hide-Panel }
        return
    }
    if ($null -ne $script:UiSettings -and $script:UiSettings.Mode -eq 'always') {
        if ($script:InteractMode) { Set-Interactive $false '失焦' }
        return
    }
    if ($script:EditMode) { return }
    if ($script:InteractMode) { Set-Interactive $false '失焦' }
    if (-not $script:PanelCollapsed) { Hide-Panel }
}

# 状态机（可注入坐标/时间，便于自检；正常由 100ms/200ms 定时器调用）
function Update-PointerState {
    param($X = $null, $Y = $null, [datetime]$Now = (Get-Date))
    if ($null -eq $script:Form) { return }
    if ($script:ChildOpen -gt 0) { return }   # 弹窗开着：不判悬停/离开，避免动面板状态
    if (-not [bool]$script:Pinned) { return }  # 0.3.25：侧边面板一直可点，不需要悬停进交互
    if ($null -eq $X -or $null -eq $Y) {
        if (-not ('DshTodoTray.Win3' -as [type])) { return }
        $p = [DshTodoTray.Win3]::Cursor()
        $X = $p.X
        $Y = $p.Y
    }
    $inside = Test-PointInForm -X ([int]$X) -Y ([int]$Y)

    # 0.3.8：鼠标在面板里 → 停掉自动隐藏倒计时；离开 → 从这一刻重新起算
    if ($inside) {
        if (($null -ne $script:AutoHideTimer -and $script:AutoHideTimer.Enabled) -or
            ($null -ne $script:FadeTimer -and $script:FadeTimer.Enabled)) { Stop-AutoHide }
    }

    if ($script:InteractMode) {
        if ($inside) {
            $script:LeaveSince = $null
        } else {
            if ($null -eq $script:LeaveSince) {
                $script:LeaveSince = $Now
                Start-AutoHide
                Restart-PeekCountdown
            } elseif (($Now - $script:LeaveSince).TotalMilliseconds -ge 1500) {
                Set-Interactive $false '移开1.5秒'
            }
        }
    } else {
        if ($inside) {
            if ($null -eq $script:HoverSince) {
                # 0.3.28：进入只开始倒计时，界面不出现任何变化（不再点亮提示边框）
                $script:HoverSince = $Now
                Write-Log '[HOVER] 光标进入面板（倒计时中，界面不变）'
            } else {
                $hoverNeedMs = 1500
                if ($null -ne $script:UiSettings -and $null -ne $script:UiSettings.PSObject.Properties['HoverMs']) {
                    $hoverNeedMs = [int]$script:UiSettings.HoverMs
                }
                if ($hoverNeedMs -lt 200) { $hoverNeedMs = 200 }
                if ((($Now - $script:HoverSince).TotalMilliseconds -ge $hoverNeedMs) -and $script:ChromeLevel -ne 'active') {
                    Set-Interactive $true ('悬停' + $hoverNeedMs + 'ms')
                    # 0.3.28：倒计时结束这一刻才出边框 + 直接变 100% 不透明
                    if ($null -ne $script:Form) {
                        try { $script:Form.Opacity = 1.0 } catch { }
                        Sync-PanelLayeredAlpha
                    }
                    Write-Log '[HOVER] 到点：进交互态 + 不透明'
                }
            }
        } else {
            if ($null -ne $script:HoverSince) {
                $script:HoverSince = $null
                Start-AutoHide
                Restart-PeekCountdown
            }
        }
    }
}

function Start-StateTimers {
    if ($null -eq $script:Form -or -not $script:Form.Visible) { return }
    if ($script:InteractMode) {
        if ($null -ne $script:HoverTimer) { try { $script:HoverTimer.Stop() } catch { } }
        if ($null -ne $script:LeaveTimer) { try { $script:LeaveTimer.Start() } catch { } }
    } else {
        if ($null -ne $script:LeaveTimer) { try { $script:LeaveTimer.Stop() } catch { } }
        if ($null -ne $script:HoverTimer) { try { $script:HoverTimer.Start() } catch { } }
    }
}

function Stop-StateTimers {
    if ($null -ne $script:HoverTimer) { try { $script:HoverTimer.Stop() } catch { } }
    if ($null -ne $script:LeaveTimer) { try { $script:LeaveTimer.Stop() } catch { } }
}

function Get-DeepWindowAt {
    param([IntPtr]$Root, [int]$X, [int]$Y)
    $cur = $Root
    for ($i = 0; $i -lt 8; $i++) {
        $cp = [DshTodoTray.Win3]::ClientPointOf($cur, $X, $Y)
        $child = [DshTodoTray.Win3]::ChildAt($cur, $cp[0], $cp[1])
        if ($child -eq [IntPtr]::Zero -or $child -eq $cur) { break }
        $cur = $child
    }
    return $cur
}

#endregion

# ============================================================
#  M06 主面板 —— 面板构建（顶栏/搜索/列表/底栏）、显示与隐藏
# ============================================================
#region M06 主面板
function Initialize-Ui {
    [System.Windows.Forms.Application]::EnableVisualStyles()

    if ($null -eq $script:UiSettings) { $script:UiSettings = Get-UiSettings }
    $script:Pinned = [bool]$script:UiSettings.Pinned   # 0.3.25

    Initialize-Fonts
    # 必须在建窗体前：窗体要用 DshTodoTray.TrayForm 把穿透位做成 CreateParams
    Initialize-ShellNative

    $formType = 'System.Windows.Forms.Form'
    if ('DshTodoTray.TrayForm' -as [type]) { $formType = 'DshTodoTray.TrayForm' }
    $script:Form = New-Object $formType
    if ($formType -eq 'DshTodoTray.TrayForm') {
        $script:Form.ClickThrough = -not $script:InteractMode
        $script:Form.NoActivate = -not $script:InteractMode
    }
    $script:Form.Text = '待办'
    $script:Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $script:Form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $script:Form.ShowInTaskbar = $false
    $script:Form.TopMost = [bool]$script:UiSettings.TopMost
    $script:Form.MinimizeBox = $false
    $script:Form.MaximizeBox = $false
    $script:Form.KeyPreview = $true
    $script:Form.BackColor = [System.Drawing.Color]::White
    $script:Form.Padding = New-Object System.Windows.Forms.Padding(0)
    $script:Form.ClientSize = New-Object System.Drawing.Size(420, 520)
    $script:Form.MinimumSize = New-Object System.Drawing.Size(320, 240)

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.ColumnCount = 1
    $layout.RowCount = 3
    $layout.BackColor = [System.Drawing.Color]::White
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 84)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $script:Form.Controls.Add($layout)
    $script:Layout = $layout   # 0.3.3：Show-Panel 改 ClientSize 后要显式 PerformLayout，保证底栏跟着到底

    # --- 头部 ---
    $head = New-HeaderPanel
    $head.Margin = New-Object System.Windows.Forms.Padding(0)
    $layout.Controls.Add($head, 0, 0)

    $script:LblHeader = New-Object System.Windows.Forms.Label
    $script:LblHeader.Text = '待办'
    $script:LblHeader.AutoSize = $false
    $script:LblHeader.Location = New-Object System.Drawing.Point(16, 14)
    $script:LblHeader.Size = New-Object System.Drawing.Size(260, 24)
    $script:LblHeader.Font = $script:FontHead
    $script:LblHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 30, 34, 40)
    $head.Controls.Add($script:LblHeader)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = [char]0x00D7
    $btnClose.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 12, [System.Drawing.FontStyle]::Regular)
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(255, 235, 238, 242)
    $btnClose.Size = New-Object System.Drawing.Size(30, 28)
    $btnClose.Location = New-Object System.Drawing.Point(376, 10)
    $btnClose.TabStop = $false
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClose.Add_Click({ Hide-Panel })
    $head.Controls.Add($btnClose)
    $script:BtnClose = $btnClose   # 0.3.14：侧边展开时要把它藏掉

    # 0.3.25 · 图钉按钮（GDI 画的图钉；蓝=钉住，灰=未钉）
    $script:BtnPin = New-Object System.Windows.Forms.Button
    $script:BtnPin.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $script:BtnPin.FlatAppearance.BorderSize = 0
    $script:BtnPin.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(255, 235, 238, 242)
    $script:BtnPin.Size = New-Object System.Drawing.Size(28, 28)
    $script:BtnPin.Location = New-Object System.Drawing.Point(342, 10)
    $script:BtnPin.TabStop = $false
    $script:BtnPin.Cursor = [System.Windows.Forms.Cursors]::Hand
    $script:BtnPin.Add_Paint({
        param($s, $e)
        try {
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $col = [System.Drawing.Color]::FromArgb(255, 120, 126, 134)
            if ([bool]$script:Pinned) { $col = [System.Drawing.Color]::FromArgb(255, 64, 126, 214) }
            $br = New-Object System.Drawing.SolidBrush($col)
            $pen = New-Object System.Drawing.Pen($col, 2)
            try {
                $g.FillEllipse($br, 8, 4, 12, 12)
                $g.FillPolygon($br, [System.Drawing.Point[]]@(
                    (New-Object System.Drawing.Point(9, 14)),
                    (New-Object System.Drawing.Point(19, 14)),
                    (New-Object System.Drawing.Point(14, 22))
                ))
                $g.DrawLine($pen, 14, 22, 14, 26)
            } finally { $br.Dispose(); $pen.Dispose() }
        } catch { }
    })
    $script:BtnPin.Add_Click({ Toggle-Pin })
    $head.Controls.Add($script:BtnPin)
    $script:PinTip = New-Object System.Windows.Forms.ToolTip
    $script:PinTip.SetToolTip($script:BtnPin, '固定面板（钉住后不收回侧边栏，可拖动）')

    # M3：编辑 / 完成 切换（常态不加任何按钮，保持 v1 观感）
    $script:EditButton = New-Object System.Windows.Forms.Button
    $script:EditButton.Text = '编辑'
    $script:EditButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $script:EditButton.FlatAppearance.BorderSize = 0
    $script:EditButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(255, 235, 238, 242)
    $script:EditButton.Font = $script:FontMeta
    $script:EditButton.ForeColor = [System.Drawing.Color]::FromArgb(255, 60, 66, 74)
    $script:EditButton.Size = New-Object System.Drawing.Size(44, 28)
    $script:EditButton.Location = New-Object System.Drawing.Point(292, 10)
    $script:EditButton.TabStop = $false
    $script:EditButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $script:EditButton.Add_Click({ Toggle-EditMode })
    $head.Controls.Add($script:EditButton)

    $script:CbList = New-Object System.Windows.Forms.ComboBox
    $script:CbList.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $script:CbList.Location = New-Object System.Drawing.Point(16, 48)
    $script:CbList.Size = New-Object System.Drawing.Size(130, 24)
    $script:CbList.Font = $script:FontMeta
    $script:CbList.Add_SelectedIndexChanged({
        param($s, $e)
        if ($script:SuppressListCombo) { return }
        $idx = [int]$s.SelectedIndex
        $lists = @(Get-Lists)
        if (($idx -eq ($lists.Count + 1)) -or ($idx -eq ($lists.Count + 2))) {
            # 0.3.12/0.3.13：「＋ 新建清单…」「⚙ 清单管理…」是动作不是选项——先退回原选择，再开窗
            $script:SuppressListCombo = $true
            try {
                $back = [int]$script:FilterListIndex + 1
                if ($back -lt 0 -or $back -gt $lists.Count) { $back = 0 }
                $s.SelectedIndex = $back
            } finally { $script:SuppressListCombo = $false }
            # 下拉的 SelectedIndexChanged 里直接弹模态窗容易和下拉收起打架：丢回消息循环再弹
            if ($idx -eq ($lists.Count + 1)) {
                $miDefer = [System.Windows.Forms.MethodInvoker]{ Show-NewListDialog }
            } else {
                $miDefer = [System.Windows.Forms.MethodInvoker]{ Show-ListManager }
            }
            if ($null -ne $script:Form) {
                [void]$script:Form.BeginInvoke($miDefer)
            } else {
                [void]$miDefer.Invoke()
            }
            return
        }
        $script:FilterListIndex = $idx - 1
        Restart-BubbleSchedule          # 0.3.12：换清单 → 冒泡从新清单重新轮
        if ($null -ne $script:RefreshTimer) { $script:RefreshTimer.Stop(); $script:RefreshTimer.Start() }
    })
    $head.Controls.Add($script:CbList)
    Update-ListCombo -ListIndex (-1)

    $lbSearch = New-Object System.Windows.Forms.Label
    $lbSearch.Text = '搜索'
    $lbSearch.AutoSize = $false
    $lbSearch.Location = New-Object System.Drawing.Point(156, 52)
    $lbSearch.Size = New-Object System.Drawing.Size(38, 20)
    $lbSearch.Font = $script:FontMeta
    $lbSearch.ForeColor = [System.Drawing.Color]::FromArgb(255, 120, 126, 134)
    $head.Controls.Add($lbSearch)

    $script:TxtSearch = New-Object System.Windows.Forms.TextBox
    $script:TxtSearch.Location = New-Object System.Drawing.Point(196, 49)
    $script:TxtSearch.Size = New-Object System.Drawing.Size(206, 24)
    $script:TxtSearch.Font = $script:FontMeta
    $script:TxtSearch.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $script:TxtSearch.Add_TextChanged({
        param($s, $e)
        $script:FilterText = [string]$s.Text
        if ($null -ne $script:RefreshTimer) { $script:RefreshTimer.Stop(); $script:RefreshTimer.Start() }
    })
    $head.Controls.Add($script:TxtSearch)

    $line = New-Object System.Windows.Forms.Panel
    $line.BackColor = [System.Drawing.Color]::FromArgb(255, 232, 235, 240)
    $line.Location = New-Object System.Drawing.Point(0, 83)
    $line.Size = New-Object System.Drawing.Size(420, 1)
    $head.Controls.Add($line)

    # 0.3.1 · D1：标题条 / 标题文字自己的 MouseDown 启动拖动（子窗口命中也走得通）
    # 0.3.25：面板钉住后才能拖（未钉住时只能拖小鲸鱼）；右下角缩放保留
    Add-PanelDragHandlers -Ctrl $head -Mode 'move'
    Add-PanelDragHandlers -Ctrl $script:LblHeader -Mode 'move'
    $head.Cursor = [System.Windows.Forms.Cursors]::Default
    $script:LblHeader.Cursor = [System.Windows.Forms.Cursors]::Default
    $script:HeadPanel = $head

    # --- 列表 ---
    $script:Flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $script:Flow.Dock = [System.Windows.Forms.DockStyle]::Fill
    $script:Flow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $script:Flow.WrapContents = $false
    $script:Flow.AutoScroll = $true
    $script:Flow.BackColor = [System.Drawing.Color]::FromArgb(255, 249, 250, 252)
    $script:Flow.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
    $script:Flow.Margin = New-Object System.Windows.Forms.Padding(0)
    $layout.Controls.Add($script:Flow, 0, 1)

    # --- 底部 ---
    $foot = New-Object System.Windows.Forms.Panel
    $foot.Dock = [System.Windows.Forms.DockStyle]::Fill
    $foot.BackColor = [System.Drawing.Color]::White
    $foot.Margin = New-Object System.Windows.Forms.Padding(0)
    $layout.Controls.Add($foot, 0, 2)
    $script:Foot = $foot   # 0.3.3：自检要断言底栏是真 HWND 且铺到窗口底沿

    $footLine = New-Object System.Windows.Forms.Panel
    $footLine.BackColor = [System.Drawing.Color]::FromArgb(255, 232, 235, 240)
    $footLine.Location = New-Object System.Drawing.Point(0, 0)
    $footLine.Size = New-Object System.Drawing.Size(420, 1)
    $foot.Controls.Add($footLine)

    $btnAdd = New-Object System.Windows.Forms.Button
    $btnAdd.Text = '＋ 新增'
    $btnAdd.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnAdd.FlatAppearance.BorderSize = 0
    $btnAdd.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(255, 235, 245, 235)
    $btnAdd.Font = $script:FontMeta
    $btnAdd.ForeColor = [System.Drawing.Color]::FromArgb(255, 30, 120, 60)
    $btnAdd.Size = New-Object System.Drawing.Size(70, 28)
    $btnAdd.Location = New-Object System.Drawing.Point(10, 6)
    $btnAdd.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnAdd.Add_Click({ Show-AddDialog })
    $foot.Controls.Add($btnAdd)
    $script:BtnAdd = $btnAdd

    # M4（R12/Q7）：原来的「打开数据文件夹」换成「导出 ▾」；打开数据文件夹移到 设置 里
    $btnFolder = New-Object System.Windows.Forms.Button
    $btnFolder.Text = '导出 ▾'
    $btnFolder.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnFolder.FlatAppearance.BorderSize = 0
    $btnFolder.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(255, 240, 243, 247)
    $btnFolder.Font = $script:FontMeta
    $btnFolder.ForeColor = [System.Drawing.Color]::FromArgb(255, 60, 66, 74)
    $btnFolder.Size = New-Object System.Drawing.Size(88, 28)
    $btnFolder.Location = New-Object System.Drawing.Point(88, 6)
    $btnFolder.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnFolder.Add_Click({ Show-ExportMenu -Anchor $script:Form })
    $foot.Controls.Add($btnFolder)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = '刷新'
    $btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnRefresh.FlatAppearance.BorderSize = 0
    $btnRefresh.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(255, 240, 243, 247)
    $btnRefresh.Font = $script:FontMeta
    $btnRefresh.ForeColor = [System.Drawing.Color]::FromArgb(255, 60, 66, 74)
    $btnRefresh.Size = New-Object System.Drawing.Size(56, 28)
    $btnRefresh.Location = New-Object System.Drawing.Point(206, 6)
    $btnRefresh.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnRefresh.Add_Click({
        $script:JustDone.Clear()
        Refresh-All
    })
    $foot.Controls.Add($btnRefresh)
    $script:BtnRefresh = $btnRefresh

    $btnSettings = New-Object System.Windows.Forms.Button
    $btnSettings.Text = '设置'
    $btnSettings.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSettings.FlatAppearance.BorderSize = 0
    $btnSettings.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(255, 240, 243, 247)
    $btnSettings.Font = $script:FontMeta
    $btnSettings.ForeColor = [System.Drawing.Color]::FromArgb(255, 60, 66, 74)
    $btnSettings.Size = New-Object System.Drawing.Size(52, 28)
    $btnSettings.Location = New-Object System.Drawing.Point(266, 6)
    $btnSettings.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnSettings.Add_Click({ Show-Settings })
    $foot.Controls.Add($btnSettings)

    $script:LblFoot = New-Object System.Windows.Forms.Label
    $script:LblFoot.Text = ('{0} · {1}' -f $script:AppVersion, $script:Stage)
    $script:LblFoot.AutoSize = $false
    $script:LblFoot.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $script:LblFoot.Font = $script:FontMeta
    $script:LblFoot.ForeColor = [System.Drawing.Color]::FromArgb(255, 165, 170, 178)
    $script:LblFoot.Location = New-Object System.Drawing.Point(322, 8)
    $script:LblFoot.Size = New-Object System.Drawing.Size(88, 24)
    $foot.Controls.Add($script:LblFoot)

    # 常驻模式（R3）下失焦不收起；编辑态（M3）也不收起；× / Esc 仍然只收界面（R4）
    # 0.3.1 P6：auto 失焦收起、always 只回穿透；逻辑抽成函数，自检可直接验
    $script:Form.Add_Deactivate({ Invoke-PanelDeactivate })
    $script:Form.Add_MouseEnter({ Start-AutoHide })
    $script:Form.Add_Resize({ Position-DragGrip; Position-CollapseTab })
    $script:Form.Add_Move({ Position-CollapseTab })
    $script:Form.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { Hide-Panel; return }
        Start-AutoHide
    })
    $script:Form.Add_FormClosing({
        param($s, $e)
        if (-not $script:Exiting) { $e.Cancel = $true; Hide-Panel }
    })

    # --- 托盘 ---
    $script:Notify = New-Object System.Windows.Forms.NotifyIcon
    $script:Notify.Text = '待办'
    $script:Notify.Visible = $true
    $script:Notify.Add_MouseClick({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Toggle-Panel }
    })

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $miShow = New-Object System.Windows.Forms.ToolStripMenuItem
    $miShow.Text = '显示待办'
    $miShow.Font = New-Object System.Drawing.Font($script:FontTitle.FontFamily, 9, [System.Drawing.FontStyle]::Bold)
    $miShow.Add_Click({ Show-Panel })
    [void]$menu.Items.Add($miShow)

    $miRefresh = New-Object System.Windows.Forms.ToolStripMenuItem
    $miRefresh.Text = '立即刷新'
    $miRefresh.Add_Click({ $script:LastStamp = ''; Refresh-All })
    [void]$menu.Items.Add($miRefresh)

    $miAdd = New-Object System.Windows.Forms.ToolStripMenuItem
    $miAdd.Text = '新增待办…'
    $miAdd.Add_Click({ Show-AddDialog })
    [void]$menu.Items.Add($miAdd)

    $miNewList = New-Object System.Windows.Forms.ToolStripMenuItem
    $miNewList.Text = '新建清单…'
    $miNewList.Add_Click({ Show-NewListDialog })
    [void]$menu.Items.Add($miNewList)

    $miLists = New-Object System.Windows.Forms.ToolStripMenuItem
    $miLists.Text = '清单管理…'
    $miLists.Add_Click({ Show-ListManager })
    [void]$menu.Items.Add($miLists)

    $miFolder = New-Object System.Windows.Forms.ToolStripMenuItem
    $miFolder.Text = '打开数据文件夹'
    $miFolder.Add_Click({
        try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $script:BaseDir) } catch { }
    })
    [void]$menu.Items.Add($miFolder)

    $miSettings = New-Object System.Windows.Forms.ToolStripMenuItem
    $miSettings.Text = '设置…'
    $miSettings.Add_Click({ Show-Settings })
    [void]$menu.Items.Add($miSettings)

    $script:MiAuto = New-Object System.Windows.Forms.ToolStripMenuItem
    $script:MiAuto.Text = '开机自启（启动文件夹）'
    $script:MiAuto.CheckOnClick = $true
    $script:MiAuto.Checked = (Test-Autostart)
    $script:MiAuto.Add_Click({ param($s, $e) [void](Set-Autostart -On ([bool]$s.Checked)); $script:MiAuto.Checked = (Test-Autostart) })
    [void]$menu.Items.Add($script:MiAuto)
    $menu.Add_Opening({ if ($null -ne $script:MiAuto) { $script:MiAuto.Checked = (Test-Autostart) } })

    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $miAbout = New-Object System.Windows.Forms.ToolStripMenuItem
    $miAbout.Text = ('{0} {1}（{2}）' -f $script:AppName, $script:AppVersion, $script:Stage)
    $miAbout.Enabled = $false
    [void]$menu.Items.Add($miAbout)

    $miExit = New-Object System.Windows.Forms.ToolStripMenuItem
    $miExit.Text = '退出'
    $miExit.Add_Click({ Exit-App })
    [void]$menu.Items.Add($miExit)

    $script:Notify.ContextMenuStrip = $menu
    $script:Menu = $menu

    # 复选框改动后延迟重建行（避免在控件自己的事件里 Dispose 它）
    $script:RefreshTimer = New-Object System.Windows.Forms.Timer
    $script:RefreshTimer.Interval = 60
    $script:RefreshTimer.Add_Tick({
        $script:RefreshTimer.Stop()
        Refresh-All
    })

    # 轮询数据文件变化（10 秒一次，很轻）
    $script:WatchTimer = New-Object System.Windows.Forms.Timer
    $script:WatchTimer.Interval = 10000
    $script:WatchTimer.Add_Tick({ Watch-Data })
    $script:WatchTimer.Start()

    # 第二个实例启动时用它把面板叫出来（Win11 把托盘图标收进溢出区，不好点）
    $script:ShowTimer = New-Object System.Windows.Forms.Timer
    $script:ShowTimer.Interval = 500
    $script:ShowTimer.Add_Tick({
        if ($null -ne $script:ShowEvent) {
            try { if ($script:ShowEvent.WaitOne(0)) { Show-Panel } } catch { }
        }
    })
    $script:ShowTimer.Start()

    # R3：自动隐藏（auto 模式到点淡出）+ 淡出动画
    $script:FadeTimer = New-Object System.Windows.Forms.Timer
    $script:FadeTimer.Interval = 40
    $script:FadeTimer.Add_Tick({
        if ($null -eq $script:Form -or -not $script:Form.Visible) { $script:FadeTimer.Stop(); return }
        $op = $script:Form.Opacity - 0.16
        if ($op -le 0.05) {
            $script:FadeTimer.Stop()
            Hide-Panel
        } else {
            $script:Form.Opacity = $op
        }
    })

    $script:AutoHideTimer = New-Object System.Windows.Forms.Timer
    $script:AutoHideTimer.Interval = 15000
    $script:AutoHideTimer.Add_Tick({
        $script:AutoHideTimer.Stop()
        if ($null -eq $script:Form -or -not $script:Form.Visible) { return }
        if ($script:ChildOpen -gt 0) { return }   # 小窗口开着：等它关掉再重新计时
        Write-Log '自动隐藏到点，开始淡出'
        $script:FadeTimer.Start()
    })

    # M4（R14）：勾完 5 秒后从列表消失（数据还在，导出能看到）
    $script:DoneFadeTimer = New-Object System.Windows.Forms.Timer
    $script:DoneFadeTimer.Interval = 1000
    $script:DoneFadeTimer.Add_Tick({
        $now = Get-Date
        $expired = @()
        foreach ($k in @($script:DoneFadeAt.Keys)) {
            if ([datetime]$script:DoneFadeAt[$k] -le $now) { $expired += $k }
        }
        if ($expired.Count -eq 0) {
            # 0.3.5（T20261029-06）：本拍没有到期项，不代表以后没有（条目是 +5s）。
            # 只有队列真的空了才停表；否则保持运行，等下一拍。
            if ($script:DoneFadeAt.Count -eq 0) { $script:DoneFadeTimer.Stop() }
            return
        }
        foreach ($k in $expired) {
            $script:DoneFadeAt.Remove($k)
            $script:JustDone.Remove($k)
        }
        if ($null -ne $script:Form -and $script:Form.Visible) { Refresh-All }
        if ($script:DoneFadeAt.Count -eq 0) { $script:DoneFadeTimer.Stop() }
    })

    # 0.3.9：删除撤销窗口（15 秒）到点就把「已删除」行收掉；数据早已真删，这里只管界面
    $script:PendingDeleteTimer = New-Object System.Windows.Forms.Timer
    $script:PendingDeleteTimer.Interval = 1000
    $script:PendingDeleteTimer.Add_Tick({
        if ($script:PendingDeletes.Count -eq 0) { $script:PendingDeleteTimer.Stop(); return }
        $now = Get-Date
        $alive = @($script:PendingDeletes | Where-Object { ($now - $_.At).TotalSeconds -lt $script:PendingDeleteSeconds })
        if ($alive.Count -ne $script:PendingDeletes.Count) {
            $script:PendingDeletes = $alive
            if ($null -ne $script:Form -and $script:Form.Visible) { Refresh-All }
        }
        if ($script:PendingDeletes.Count -eq 0) { $script:PendingDeleteTimer.Stop() }
    })

    # 0.3.0 · M5：悬停/离开判定。穿透态 100ms（悬停 0.6 秒进交互）；
    # 交互态换成 200ms 只做「移开 1.5 秒回穿透」，悬停定时器停掉（省电）。
    $script:HoverTimer = New-Object System.Windows.Forms.Timer
    $script:HoverTimer.Interval = 100
    $script:HoverTimer.Add_Tick({
        if (-not $script:InteractMode) { Update-PointerState }
    })

    $script:LeaveTimer = New-Object System.Windows.Forms.Timer
    $script:LeaveTimer.Interval = 200
    $script:LeaveTimer.Add_Tick({
        if ($script:InteractMode) { Update-PointerState }
    })

    # 0.3.6：拖动/缩放由一个 20ms 定时器轮询（收成侧边栏后窗口已 Hide，Capture 会丢）
    $script:DragTimer = New-Object System.Windows.Forms.Timer
    $script:DragTimer.Interval = 20
    $script:DragTimer.Add_Tick({
        if ($null -eq $script:PanelDrag) { $script:DragTimer.Stop(); return }
        try { Update-PanelDrag } catch { Write-Log ('拖动异常: ' + $_.Exception.Message) 'ERROR' }
    })

    # M7：小鲸鱼展开后自动收回（250ms 看一次截止时间）
    $script:WhaleTimer = New-Object System.Windows.Forms.Timer
    $script:WhaleTimer.Interval = 250
    $script:WhaleTimer.Add_Tick({
        if ($null -eq $script:WhaleDeadline) { $script:WhaleTimer.Stop(); return }
        if ($script:ChildOpen -gt 0) { return }   # 小窗口开着：不收，等它关掉再重新计时
        if (Test-PointerInPanel) { Restart-PeekCountdown; return }   # 鼠标在面板里：不计时
        if ((Get-Date) -lt $script:WhaleDeadline) { return }
        $script:WhaleDeadline = $null
        $script:WhaleTimer.Stop()
        if (-not $script:PanelCollapsed) { Set-Collapsed $true '自动收回' }
    })

    # 0.3.11 · 小鲸鱼冒泡：250ms 看一次，到点冒一个、6 秒后收
    $script:BubbleTimer = New-Object System.Windows.Forms.Timer
    $script:BubbleTimer.Interval = 250
    $script:BubbleTimer.Add_Tick({
        try {
            if ($null -eq $script:UiSettings -or -not [bool]$script:UiSettings.BubbleEnabled) {
                if ($null -ne $script:Bubble -and $script:Bubble.Visible) { Hide-Bubble }
                return
            }
            if ($script:ChildOpen -gt 0) { return }          # 弹窗开着：先不冒
            if (-not (Test-BubbleContext)) {                 # 0.3.14：面板和小鲸鱼都关了 → 不冒
                if ($null -ne $script:Bubble -and $script:Bubble.Visible) { Hide-Bubble }
                $script:BubbleNextAt = (Get-Date).AddSeconds(5)
                return
            }
            if ($null -eq $script:BubbleNextAt) { Restart-BubbleSchedule; return }
            $now = Get-Date
            if ($null -ne $script:BubbleHideAt) {
                if ($now -ge $script:BubbleHideAt) {
                    Hide-Bubble
                    $script:BubbleNextAt = $now.AddSeconds((Get-BubbleIntervalSeconds))
                }
                return
            }
            if ($now -lt $script:BubbleNextAt) { return }
            $entry = Get-BubbleEntry
            if ($null -eq $entry) { $script:BubbleNextAt = $now.AddSeconds((Get-BubbleIntervalSeconds)); return }
            Show-Bubble -Entry $entry
        } catch { Write-Log ('冒泡异常: ' + $_.Exception.Message) 'ERROR' }
    })
    $script:BubbleTimer.Start()

    # 0.3.21 · 滑动动画（鲸鱼换边 / 面板展开、收回）
    # 0.3.23 · 滑入完成后再补内容（一次性）
    $script:OpenFillTimer = New-Object System.Windows.Forms.Timer
    $script:OpenFillTimer.Interval = 180
    $script:OpenFillTimer.Add_Tick({
        try {
            $script:OpenFillTimer.Stop()
            if ([bool]$script:RollPending) {
                $script:RollPending = $false
                $stateRoll = Load-State
                Update-Status -State $stateRoll
                $script:LastStamp = Get-DataStamp
                Start-RowRoll -State $stateRoll
                Write-Log '[PANEL] 卷帘开始'
            } else {
                Refresh-All
                Write-Log '[PANEL] 展开后补内容完成'
            }
        } catch { Write-Log ('补内容异常: ' + $_.Exception.Message) 'ERROR' }
    })

    # 0.3.24 · 卷帘逐行出现（10ms 一拍、每拍 4 行）
    $script:RollTimer = New-Object System.Windows.Forms.Timer
    $script:RollTimer.Interval = 18
    $script:RollTimer.Add_Tick({
        try { [void](Step-RowRoll -Max 1) } catch { Write-Log ('卷帘异常: ' + $_.Exception.Message) 'ERROR' }
    })

    $script:SlideTimer = New-Object System.Windows.Forms.Timer
    $script:SlideTimer.Interval = 12
    $script:SlideTimer.Add_Tick({
        try {
            if ($null -eq $script:SlideJob) { $script:SlideTimer.Stop(); return }
            $j = $script:SlideJob
            $t = ((Get-Date) - $j.Start).TotalMilliseconds / [double]$j.Ms
            if ($t -ge 1) { $t = 1 }
            $ease = 1 - [Math]::Pow((1 - $t), 3)
            try { $j.Ctrl.Left = [int]($j.From + ($j.To - $j.From) * $ease) } catch { }
            if ($t -ge 1) {
                $script:SlideJob = $null
                $script:SlideTimer.Stop()
                try { $j.Ctrl.Left = [int]$j.To } catch { }
                $then = $script:SlideThen
                $script:SlideThen = $null
                if (($null -ne $then) -and ([string]$then.Kind -eq 'collapse')) {
                    Set-Collapsed $true ([string]$then.Reason) -NoAnim -FromWhale:([bool]$then.FromWhale)
                }
            }
        } catch { Write-Log ('滑动动画异常: ' + $_.Exception.Message) 'ERROR' }
    })

    # 0.3.37 · 置顶守护（用户 2026-11-11：小鲸鱼被压到别的置顶层窗口下面了）
    # 置顶是一「层」：谁后显示谁在上面。小鲸鱼一直可见，后面再有置顶层窗口（任务栏、全屏程序、
    # 小火箭之类）就不动了 → 每 3 秒把对应的窗口用 HWND_TOPMOST + NOACTIVATE 抬回顶层（不动、不抢焦点）。
    # 只抬「该一直看得见」的：小鲸鱼、显示中的冒泡、钉住的面板；未钉住的面板是临时展开，不抢别人。
    $script:TopmostTimer = New-Object System.Windows.Forms.Timer
    $script:TopmostTimer.Interval = 3000
    $script:TopmostTimer.Add_Tick({
        try {
            if (-not $script:HasNative) { return }
            $hwndTop = [IntPtr](-1)
            if ($null -ne $script:Whale -and $script:Whale.Visible) {
                [void][DshTodoTray.Win]::SetWindowPos($script:Whale.Handle, $hwndTop, 0, 0, 0, 0, 0x0013)
            }
            if ($null -ne $script:Bubble -and $script:Bubble.Visible) {
                [void][DshTodoTray.Win]::SetWindowPos($script:Bubble.Handle, $hwndTop, 0, 0, 0, 0, 0x0013)
            }
            if ([bool]$script:Pinned -and $null -ne $script:Form -and $script:Form.Visible) {
                [void][DshTodoTray.Win]::SetWindowPos($script:Form.Handle, $hwndTop, 0, 0, 0, 0, 0x0013)
            }
        } catch { }
    })
    $script:TopmostTimer.Start()

    # 0.3.1 · D2：右下角 18×18 缩放手柄（自画斜线，挂手动缩放）
    $grip = New-Object System.Windows.Forms.Panel
    $grip.Size = New-Object System.Drawing.Size(18, 18)
    $grip.Anchor = ([System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right)
    $grip.BackColor = [System.Drawing.Color]::White
    $grip.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
    $grip.Add_Paint({
        param($s, $e)
        try {
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 165, 170, 178), 1)
            try {
                for ($i = 4; $i -le 14; $i += 5) {
                    $e.Graphics.DrawLine($pen, ($i - 4), ($s.Height - 2), ($s.Width - 2), ($i - 4))
                }
            } finally { $pen.Dispose() }
        } catch { }
    })
    Add-PanelDragHandlers -Ctrl $grip -Mode 'size'
    $grip.Add_MouseEnter({ try { [System.Windows.Forms.Cursor]::Current = $script:DragGrip.Cursor } catch { } })
    $script:Form.Controls.Add($grip)
    $grip.BringToFront()
    $grip.Location = New-Object System.Drawing.Point(($script:Form.ClientSize.Width - 18), ($script:Form.ClientSize.Height - 18))
    $script:DragGrip = $grip

    # 0.3.0 · M8：子类化窗口过程（NCHITTEST 拖动/缩放、拦 Win+D 隐藏）
    Initialize-ShellNative
    try {
        $script:ShellHook = [DshTodoTray.ShellHook]::Hook($script:Form.Handle)
    } catch {
        $script:ShellHook = $null
        Write-Log ('窗口子类化失败（拖动/抗 Win+D 会退化为不可用）: ' + $_.Exception.Message) 'ERROR'
    }
    Initialize-Whale
    Set-PanelChrome 'none'
    # 0.3.32：所有按钮都建完之后再统一挂焦点清理
    #（0.3.30 挂得太早，编辑/新增/导出/刷新/设置 都在它之后才建，等于没挂）
    Register-ButtonFocusFix -Ctrl $script:Form
    Apply-PanelExStyle
}

function Initialize-Fonts {
    $script:FontTitle   = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Regular)
    $script:FontStrike  = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, ([System.Drawing.FontStyle]::Regular -bor [System.Drawing.FontStyle]::Strikeout))
    $script:FontHead    = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
    $script:FontMeta    = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.5, [System.Drawing.FontStyle]::Regular)
    $script:FontMetaHot = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.5, [System.Drawing.FontStyle]::Bold)
}

function New-HeaderPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panel.BackColor = [System.Drawing.Color]::White
    return $panel
}

function Show-Panel {
    param([switch]$Interactive, [switch]$FromWhale, [switch]$NoAnim)
    if ($null -eq $script:Form) { return }
    # 0.3.40：面板已经显示着、又被重显（典型：点导出后的黑色提示框）→ 沿用当前侧边模式。
    # 以前这里会把 $script:FromWhale 清成 false：收起箭头消失、3 秒自动收回也停（用户 2026-11-11 19:05）。
    $wasVisible = $script:Form.Visible
    $fw = [bool]$FromWhale
    if ($wasVisible -and (-not $FromWhale) -and [bool]$script:FromWhale) { $fw = $true }
    if ($null -eq $script:UiSettings) { $script:UiSettings = Get-UiSettings }
    $ui = $script:UiSettings
    if ($null -eq $script:WinCfg) { $script:WinCfg = Get-WindowSettings }
    $wc = $script:WinCfg
    $wa = Get-ScreenArea
    $size = Get-ClampedSize -W ([int]$wc.W) -H ([int]$wc.H)
    $wc.W = $size.W
    $wc.H = $size.H
    $x = [int]$wc.X
    $y = [int]$wc.Y
    $finalX = $x
    $animateOpen = $false
    # 出屏保护（换分辨率/拔显示器后不许弹到看不见的地方）
    if ($x -lt ($wa.Left - $wc.W + 80) -or $x -gt ($wa.Right - 80) -or $y -lt ($wa.Top - 40) -or $y -gt ($wa.Bottom - 80)) {
        $def = Get-DefaultWindowSettings
        $x = $def.X
        $y = $def.Y
        $wc.X = $x
        $wc.Y = $y
    }
    # 0.3.15：从小鲸鱼展开 → 面板贴着鲸鱼那条屏边（用户 2026-11-10：点小鲸鱼打开，窗口右侧紧贴侧边）
    if ($fw -and (-not [bool]$script:Pinned) -and ($null -ne $wc)) {
        $dockSide = [string]$wc.WhaleSide
        if ($dockSide -ne 'left') { $dockSide = 'right' }
        $wc.Edge = $dockSide
        if ($dockSide -eq 'right') { $x = $wa.Right - [int]$wc.W } else { $x = $wa.Left }
        $wc.X = $x
        $finalX = [int]$x
        $animateOpen = ((-not $NoAnim) -and (-not [bool]$script:AnimOff) -and ($null -ne $script:SlideTimer))
        if ($animateOpen) {
            # 0.3.21：从屏外滑入（右侧屏边外 / 左侧屏边外）
            if ($dockSide -eq 'right') { $x = [int]$wa.Right } else { $x = [int]($wa.Left - [int]$wc.W) }
        }
        # 0.3.18：纵向以鲸鱼中心对齐；鲸鱼靠上/靠下就夹到工作区顶/底（任务栏之上）
        $whaleCenter = [int]$wc.WhaleY + [int]($script:BarHeight / 2)
        if (($null -ne $script:Whale) -and $script:Whale.Visible) { $whaleCenter = [int]$script:Whale.Top + [int]($script:Whale.Height / 2) }
        $y = $whaleCenter - [int]($wc.H / 2)
        if ($y -lt $wa.Top) { $y = $wa.Top }
        if (($y + [int]$wc.H) -gt $wa.Bottom) { $y = $wa.Bottom - [int]$wc.H }
        $wc.Y = $y
    }
    $script:Form.Location = New-Object System.Drawing.Point($x, $y)
    $script:Form.ClientSize = New-Object System.Drawing.Size($wc.W, $wc.H)
    if ($fw) { [void](Save-WindowSettings -Settings $wc) }   # 贴边后的几何落盘（动画态也用目标几何）
    # 0.3.3：ClientSize 变了要显式重排，让底栏（Dock=Fill 的真实 Panel）跟着铺到窗口底沿；
    # 否则底栏与列表之间会留一条"没有子窗口"的缝（07 诊断里 H=560 少 40px / H=620 少 70px）。
    try { if ($null -ne $script:Layout) { $script:Layout.PerformLayout() } } catch { }
    Position-DragGrip
    $script:Form.TopMost = [bool]$ui.TopMost
    $script:JustDone.Clear()
    $script:DoneFadeAt.Clear()
    $script:PanelCollapsed = $false
    $script:FromWhale = $fw
    if (-not $fw) {
        # 0.3.31：普通打开（托盘/设置回显）不该带"展开后 3 秒自动收回"
        $script:PeekExpanded = $false
        $script:WhaleDeadline = $null
        if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Stop() } catch { } }
    }
    Hide-Bubble   # 0.3.17：主界面一出来就把冒泡停掉
    # 0.3.22：动画打开时先留着鲸鱼，等内容建好、真正开滑那一刻再藏（否则先消失等半天）
    if (-not $animateOpen) {
        if ($null -ne $script:Whale) { try { $script:Whale.Hide() } catch { } }
    }
    if (-not $script:Form.Visible) { $script:Form.Show() }
    Position-DragGrip
    Set-PanelChrome 'none'
    Apply-PanelExStyle
    try { $script:Form.Opacity = Get-PanelOpacityValue } catch { }
    # 0.3.3：Opacity 改完再补一次 layered 属性（Opacity=1.0 时 WinForms 自己不设 alpha，
    # 窗口就会退回"有 LAYERED 位、无属性"的点不到状态）
    Sync-PanelLayeredAlpha
    $swOpen = [System.Diagnostics.Stopwatch]::StartNew()
    if ($animateOpen) {
        # 0.3.24：先清成空白面板 → 滑入 → 180ms 后卷帘铺事项
        $script:RollPending = $true
        Clear-Rows
        if ($null -ne $script:OpenFillTimer) { $script:OpenFillTimer.Stop(); $script:OpenFillTimer.Start() }
    } else {
        Refresh-All
    }
    if ($script:HasNative) {
        try {
            # 置顶复核：TopMost 属性之外补一次 HWND_TOPMOST/NOTOPMOST，仍不抢焦点
            $insert = if ($ui.TopMost) { [IntPtr](-1) } else { [IntPtr](-2) }
            [void][DshTodoTray.Win]::SetWindowPos($script:Form.Handle, $insert, 0, 0, 0, 0, 0x0013)
        } catch { }
    }
    if ([bool]$script:Pinned) {
        # 钉住：保留穿透/悬停那一套；托盘 / 小鲸鱼点开时直接进交互态
        if ($Interactive) { Set-Interactive $true '托盘/小鲸鱼' -Focus } else { Set-Interactive $false '显示面板' }
        Start-StateTimers
        Start-AutoHide
    } else {
        # 0.3.25：贴着侧边的面板不需要穿透/悬停 —— 一直可点
        Set-Interactive $true '侧边面板'
        Stop-StateTimers
        Start-AutoHide
    }
    if ($animateOpen) {
        # 0.3.22：内容已就绪 → 这一刻藏鲸鱼，同时开始滑入；箭头等滑入开始后再摆，别在准备期间露在屏边
        if ($null -ne $script:Whale) { try { $script:Whale.Hide() } catch { } }
        $script:SlideThen = $null
        Start-SlideAnim -Ctrl $script:Form -FromX ([int]$x) -ToX $finalX -Ms 160
        Write-Log ('[PANEL] 展开耗时 ' + $swOpen.ElapsedMilliseconds + ' ms（起滑点）')
    }
    Update-CollapseChrome
}

function Hide-Panel {
    if ($null -eq $script:Form) { return }
    if ($script:SuppressDeactivate) { return }
    if ($script:ChildOpen -gt 0) { return }   # 小窗口开着：大面板不收
    if ($script:Form.Visible) {
        Stop-AutoHide
        Stop-StateTimers
        if ($null -ne $script:OpenFillTimer) { try { $script:OpenFillTimer.Stop() } catch { } }
        Stop-RowRoll
        $script:RollPending = $false
        if ($script:InteractMode) { Set-Interactive $false 'hide' }
        $script:PanelCollapsed = $false
        $script:PeekExpanded = $false
        $script:WhaleDeadline = $null
        # 关面板 = 撤销窗口结束（条目早就真删了）
        $script:PendingDeletes = @()
        if ($null -ne $script:PendingDeleteTimer) { try { $script:PendingDeleteTimer.Stop() } catch { } }
        if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Stop() } catch { } }
        if ($null -ne $script:Whale) { try { $script:Whale.Hide() } catch { } }
        Hide-CollapseTab
        $script:FromWhale = $false
        $script:SlideThen = $null
        # 收起时退出编辑态，下次打开回到常态样式
        if ($script:EditMode) {
            $script:EditMode = $false
            if ($null -ne $script:EditButton) { $script:EditButton.Text = '编辑' }
        }
        $script:AllowHide = $true
        if ($null -ne $script:ShellHook) { $script:ShellHook.AllowHide = $true }
        try { $script:Form.Hide() } finally {
            $script:AllowHide = $false
            if ($null -ne $script:ShellHook) { $script:ShellHook.AllowHide = $false }
        }
        $script:HideTime = Get-Date
    }
}

function Toggle-Panel {
    if ($script:PanelCollapsed) { Set-Collapsed $false '托盘图标' -FromWhale; return }
    if ($script:Form.Visible) {
        # 托盘左键 = 进交互态（Q1）；已经在交互态再点 = 收起
        if (-not $script:InteractMode) { Set-Interactive $true '托盘左键' -Focus; Start-StateTimers; return }
        Hide-Panel
        return
    }
    # 点托盘时窗口先失焦被收起；300ms 内不再弹回来，达到「再点一次收起」的手感
    if (((Get-Date) - $script:HideTime).TotalMilliseconds -lt 300) { return }
    Show-Panel -Interactive
}

#endregion

# ============================================================
#  M07 拖动与收边 —— 标题条拖动、缩放抓手、拖到边收成侧边条
# ============================================================
#region M07 拖动与收边
function Position-DragGrip {
    if ($null -eq $script:DragGrip -or $null -eq $script:Form) { return }
    $w = [int]$script:Form.ClientSize.Width
    $h = [int]$script:Form.ClientSize.Height
    $script:DragGrip.Location = New-Object System.Drawing.Point(($w - 18), ($h - 18))
    try { $script:DragGrip.BringToFront() } catch { }
}

function Add-PanelDragHandlers {
    # 只负责「起手」：真实位移/收边由 20ms 的 DragTimer 轮询（见上方状态机注释）
    param($Ctrl, [string]$Mode = 'move')
    if ($null -eq $Ctrl) { return }
    $Ctrl.Tag = $Mode
    $Ctrl.Add_MouseDown({
        param($s, $e)
        if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        if (-not [bool]$script:Pinned) { return }   # 0.3.25：未钉住的面板不拖
        $pt = $s.PointToScreen($e.Location)
        $m = 'move'
        if ($null -ne $s.Tag) { $m = [string]$s.Tag }
        Start-PanelDrag -Mode $m -X $pt.X -Y $pt.Y
    })
}

function Start-PanelDrag {
    param([string]$Mode = 'move', $X = $null, $Y = $null)
    if ($null -eq $script:Form) { return }
    if (-not $script:InteractMode) { return }   # 穿透态拖不动是设计（Q3）
    if ($null -ne $script:PanelDrag) { return }
    if ($null -eq $X -or $null -eq $Y) {
        if (-not ('DshTodoTray.Win3' -as [type])) { return }
        $p = [DshTodoTray.Win3]::Cursor()
        $X = $p.X
        $Y = $p.Y
    }
    $script:PanelDrag = @{
        Mode  = $Mode
        GrabX = [int]$X
        GrabY = [int]$Y
        OffX  = [int]$X - [int]$script:Form.Left
        OffY  = [int]$Y - [int]$script:Form.Top
        BaseW = [int]$script:Form.Width
        BaseH = [int]$script:Form.Height
        Phase = 'window'
        Edge  = 'none'
    }
    # 拖动期间别让悬停/自动隐藏插一脚
    Stop-StateTimers
    Stop-AutoHide
    if ($null -ne $script:DragTimer) { try { $script:DragTimer.Start() } catch { } }
    Write-Log ('[DRAG] 开始 ' + $Mode + ' @' + [int]$X + ',' + [int]$Y)
}

function Update-PanelDrag {
    # 不给坐标 = 定时器轮询真实鼠标（要判左键松开）；给坐标 = 自检/手动驱动，不判左键
    param($X = $null, $Y = $null)
    if ($null -eq $script:PanelDrag -or $null -eq $script:Form) { return }
    $manual = ($null -ne $X -and $null -ne $Y)
    if (-not $manual) {
        if (-not ('DshTodoTray.Win3' -as [type])) { End-PanelDrag; return }
        if (-not [DshTodoTray.Win3]::LeftDown()) { End-PanelDrag; return }
        $p = [DshTodoTray.Win3]::Cursor()
        $X = $p.X
        $Y = $p.Y
    }
    $d = $script:PanelDrag
    $x = [int]$X
    $y = [int]$Y

    if ([string]$d.Mode -eq 'size') {
        $sz = Get-ClampedSize -W ([int]$d.BaseW + $x - [int]$d.GrabX) -H ([int]$d.BaseH + $y - [int]$d.GrabY)
        $script:Form.Size = New-Object System.Drawing.Size($sz.W, $sz.H)
        return
    }

    $wa = Get-ScreenArea
    $left = $x - [int]$d.OffX
    $top = $y - [int]$d.OffY
    # 0.3.25：窗口不许出屏幕，碰到边就顶住（两边都顶死 = 不动）
    $clampedPos = Get-ClampedWindowPos -Left $left -Top $top -W ([int]$script:Form.Width) -H ([int]$script:Form.Height)
    $left = [int]$clampedPos.Left
    $top = [int]$clampedPos.Top

    if ([string]$d.Phase -eq 'bar') {
        # 还在侧边栏：窗口没真的出来，但按"虚拟窗口"离边的距离判脱边
        if ([string]$d.Edge -eq 'left') { $dist = $left - $wa.Left } else { $dist = $wa.Right - ($left + [int]$script:Form.Width) }
        if ($dist -ge [int]$script:EdgeLeavePx) {
            Exit-BarPhase -X $x -Y $y
        } else {
            # 0.3.19：位移 = 鼠标相对进入 bar 态时的偏移，条自己夹在 [顶, 底-条高]
            $baseTop = 0
            $baseY = 0
            if ($d.ContainsKey('BarBaseTop')) { $baseTop = [int]$d.BarBaseTop }
            if ($d.ContainsKey('BarBaseMouseY')) { $baseY = [int]$d.BarBaseMouseY }
            $newTop = $baseTop + ($y - $baseY)
            $topMax = [int]($wa.Bottom - [int]$script:BarHeight)
            if ($newTop -lt [int]$wa.Top) { $newTop = [int]$wa.Top }
            if ($newTop -gt $topMax) { $newTop = $topMax }
            $script:WinCfg.WhaleY = $newTop
            Set-WhalePosition
        }
        return
    }

    $script:Form.Location = New-Object System.Drawing.Point($left, $top)
    if (-not [bool]$script:Pinned) {
        $spot = Get-EdgeSpot -X $left -W ([int]$script:Form.Width) -Area $wa
        if ($spot.Distance -le [int]$script:EdgeTouchPx) {
            Enter-BarPhase -Edge $spot.Edge -X $x -Y $y
        }
    }
}

function Enter-BarPhase {
    # 窗口边碰到屏幕边：直接收成侧边栏，纵向跟着鼠标
    param([string]$Edge, [int]$X, [int]$Y)
    if ($null -eq $script:PanelDrag) { return }
    $script:PanelDrag.Phase = 'bar'
    $script:PanelDrag.Edge = $Edge
    $script:PanelCollapsed = $true
    $script:WinCfg.Edge = $Edge
    $script:WinCfg.WhaleSide = $Edge
    # 0.3.19：侧边条从「面板中心」起手，之后按鼠标位移走；鼠标可以更靠上/下，条自己夹在屏幕里
    $waBar = Get-ScreenArea
    $barBaseTop = [int]($script:Form.Top + [Math]::Floor($script:Form.Height / 2) - [int]($script:BarHeight / 2))
    $barTopMax = [int]($waBar.Bottom - [int]$script:BarHeight)
    if ($barBaseTop -lt [int]$waBar.Top) { $barBaseTop = [int]$waBar.Top }
    if ($barBaseTop -gt $barTopMax) { $barBaseTop = $barTopMax }
    $script:WinCfg.WhaleY = $barBaseTop
    $script:PanelDrag.BarBaseTop = $barBaseTop
    $script:PanelDrag.BarBaseMouseY = [int]$Y
    Set-WhalePosition
    Show-Whale
    Set-Interactive $false '拖动收成侧边栏'
    Stop-StateTimers
    Stop-AutoHide
    if ($script:Form.Visible) {
        $script:AllowHide = $true
        if ($null -ne $script:ShellHook) { $script:ShellHook.AllowHide = $true }
        try { $script:Form.Hide() } finally {
            $script:AllowHide = $false
            if ($null -ne $script:ShellHook) { $script:ShellHook.AllowHide = $false }
        }
    }
    Hide-CollapseTab          # 0.3.18：拖到边收起时，箭头不许留在原地
    $script:FromWhale = $false
    Write-Log ('[DRAG] 碰边 → 侧边栏 edge=' + $Edge + ' y=' + $script:WinCfg.WhaleY)
}

function Exit-BarPhase {
    # 按住不放把窗口拖离边：恢复成窗口，继续跟手
    param([int]$X, [int]$Y)
    if ($null -eq $script:PanelDrag -or $null -eq $script:Form) { return }
    $script:PanelDrag.Phase = 'window'
    $script:PanelCollapsed = $false
    $script:WinCfg.Edge = 'none'
    if ($null -ne $script:Whale) { try { $script:Whale.Hide() } catch { } }
    $wa = Get-ScreenArea
    $left = $X - [int]$script:PanelDrag.OffX
    $top = $Y - [int]$script:PanelDrag.OffY
    if ($top -lt $wa.Top) { $top = $wa.Top }
    if ($top -gt ($wa.Bottom - 60)) { $top = $wa.Bottom - 60 }
    $script:Form.Location = New-Object System.Drawing.Point($left, $top)
    if (-not $script:Form.Visible) { $script:Form.Show() }
    Set-Interactive $true '拖动恢复成窗口'
    Apply-PanelExStyle
    Start-StateTimers
    Update-CollapseChrome     # 0.3.18：拖出来是普通窗口 → 恢复 ×、收掉箭头
    Write-Log ('[DRAG] 脱边 → 窗口 x=' + $left + ' y=' + $top)
}

function End-PanelDrag {
    if ($null -eq $script:PanelDrag) { return }
    $d = $script:PanelDrag
    $script:PanelDrag = $null
    if ($null -ne $script:DragTimer) { try { $script:DragTimer.Stop() } catch { } }
    if ($null -eq $script:Form) { return }
    if ($null -eq $script:WinCfg) { $script:WinCfg = Get-WindowSettings }

    $mode = [string]$d.Mode
    if ($mode -eq 'size') {
        $script:WinCfg.W = [int]$script:Form.Width
        $script:WinCfg.H = [int]$script:Form.Height
    } elseif ([string]$d.Phase -eq 'bar') {
        Hide-CollapseTab      # 0.3.18：兜底，别留下箭头
        $script:FromWhale = $false
        $script:WinCfg.Collapsed = $true
        $script:WinCfg.Edge = [string]$d.Edge
        $script:WinCfg.WhaleSide = [string]$d.Edge
        if ($null -ne $script:Whale) { $script:WinCfg.WhaleY = [int]$script:Whale.Top }
        Write-Log ('[DRAG] 松手：侧边栏固定 edge=' + $d.Edge + ' y=' + $script:WinCfg.WhaleY)
    } else {
        $script:WinCfg.X = [int]$script:Form.Left
        $script:WinCfg.Y = [int]$script:Form.Top
        $script:WinCfg.W = [int]$script:Form.Width
        $script:WinCfg.H = [int]$script:Form.Height
        $script:WinCfg.Edge = 'none'
        $script:WinCfg.Collapsed = $false
        Write-Log ('[DRAG] 松手：窗口 ' + $script:Form.Left + ',' + $script:Form.Top + ' ' + $script:Form.Width + 'x' + $script:Form.Height)
    }
    [void](Save-WindowSettings -Settings $script:WinCfg)
    if ($script:Form.Visible) { Start-StateTimers; Start-AutoHide }
}

# ============================================================
#  0.3.6 · 拖动/缩放：一个 20ms 轮询状态机
#  为什么不用 MouseMove：收成侧边栏时窗口要 Hide，Capture 随之丢失，MouseMove 就不来了。
#  所以标题条/抓手只负责「起手」，之后每 20ms 读一次 GetCursorPos + 左键状态：
#      window 态：窗口跟手 → 边碰到屏幕边（≤10px）→ bar 态
#      bar   态：侧边栏跟手上下走 → 窗口离边 ≥60px → 回到 window 态
#      左键松开：落盘（bar 就固定在原地，没有"松手吸附"这一说了）
# ============================================================
function Get-EdgeSpot {
    # 窗口离哪条边更近（纯函数；负值 = 已经压出屏幕，便于自检）
    param([int]$X, [int]$W, [System.Drawing.Rectangle]$Area)
    $dl = $X - $Area.Left
    $dr = $Area.Right - ($X + $W)
    if ($dl -le $dr) { return [pscustomobject]@{ Edge = 'left'; Distance = $dl } }
    return [pscustomobject]@{ Edge = 'right'; Distance = $dr }
}

function Get-BarTop {
    # 侧边栏纵向位置：鼠标 Y 居中，夹在工作区内
    param([int]$Y, [System.Drawing.Rectangle]$Area)
    $top = $Y - [int]($script:BarHeight / 2)
    if ($top -lt $Area.Top) { $top = $Area.Top }
    if (($top + $script:BarHeight) -gt $Area.Bottom) { $top = $Area.Bottom - $script:BarHeight }
    return $top
}

#endregion

# ============================================================
#  M08 小鲸鱼与滑动动画 —— 小鲸鱼窗口、收起/展开、换边与滑入滑出
# ============================================================
#region M08 小鲸鱼与滑动动画
function Get-WhaleTailOffset {
    # 0.3.38：小鲸鱼摆尾幅度（像素，正=右摆 / 负=左摆）。T=0..1
    # 0.3.39：两摆 → 四摆（sin 8πT），时间从 700ms 拉到 1400ms，用户「看过去她都摇完了」。
    # 两端仍用 sin(πT) 包络收住，起止自然归 0。
    param([double]$T)
    if ($T -le 0 -or $T -ge 1) { return 0 }
    $env = [Math]::Sin([Math]::PI * $T)
    $wave = [Math]::Sin(8 * [Math]::PI * $T)
    return [int][Math]::Round(5.0 * $env * $wave)
}

function Start-WhaleWag {
    # 0.3.38：让小鲸鱼摆尾巴（用户 2026-11-11：DSH 那条会摆尾，托盘的也想要）。
    # 0.3.39：四摆 / 1400ms，并加「鼠标移到鲸鱼上也摇」——用户看过去时刚好能看到。
    param([int]$Ms = 1400)
    if ($null -eq $script:Whale -or -not $script:Whale.Visible) { return }
    if ($null -eq $script:WhaleWagTimer) {
        $script:WhaleWagTimer = New-Object System.Windows.Forms.Timer
        $script:WhaleWagTimer.Interval = 40
        $script:WhaleWagTimer.Add_Tick({
            try {
                if ($null -eq $script:WhaleWagStart) { $script:WhaleWagTimer.Stop(); return }
                $t = ((Get-Date) - $script:WhaleWagStart).TotalMilliseconds / [double]$script:WhaleWagMs
                if ($t -ge 1) {
                    $script:WhaleWagStart = $null
                    $script:WhaleWagOffset = 0
                    $script:WhaleWagTimer.Stop()
                } else {
                    $script:WhaleWagOffset = Get-WhaleTailOffset -T $t
                }
                if ($null -ne $script:Whale -and $script:Whale.Visible) { try { $script:Whale.Invalidate() } catch { } }
            } catch { }
        })
    }
    $script:WhaleWagMs = [int]$Ms
    $script:WhaleWagStart = Get-Date
    $script:WhaleWagTimer.Start()
}

function Initialize-Whale {
    if ($null -ne $script:Whale) { return }
    $whaleType = 'System.Windows.Forms.Form'
    if ('DshTodoTray.TrayForm' -as [type]) { $whaleType = 'DshTodoTray.TrayForm' }
    $w = New-Object $whaleType
    if ($whaleType -eq 'DshTodoTray.TrayForm') {
        $w.ClickThrough = $false   # 要点得到
        $w.NoActivate = $true      # 但不抢焦点（Q4）
    }
    $w.Text = '待办（点我展开）'
    $w.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $w.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $w.ShowInTaskbar = $false
    $w.MinimizeBox = $false
    $w.MaximizeBox = $false
    $w.TopMost = $true
    $w.ClientSize = New-Object System.Drawing.Size($script:BarWidth, $script:BarHeight)
    $w.BackColor = [System.Drawing.Color]::FromArgb(255, 64, 126, 214)
    $w.Cursor = [System.Windows.Forms.Cursors]::Hand
    # 矢量小鲸鱼（不用 emoji：字体/DPI 不同会变方块）
    $w.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        try {
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            $dark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 64, 126, 214))
            try {
                # 水柱
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
                try {
                    $g.DrawLine($pen, 12, 10, 12, 4)
                    $g.DrawLine($pen, 12, 6, 8, 2)
                    $g.DrawLine($pen, 12, 6, 16, 2)
                } finally { $pen.Dispose() }
                # 身体
                $g.FillEllipse($white, 2, 12, 20, 26)
                # 尾巴（0.3.38：跟着 $script:WhaleWagOffset 摆动）
                $wd = [int]$script:WhaleWagOffset
                $wb = [int][Math]::Round($wd * 0.3)
                $g.FillPolygon($white, [System.Drawing.Point[]]@(
                    (New-Object System.Drawing.Point((8 + $wb), 36)),
                    (New-Object System.Drawing.Point((16 + $wb), 36)),
                    (New-Object System.Drawing.Point((12 + $wd), (48 - [int]([Math]::Abs($wd) * 0.4))))
                ))
                # 眼睛
                $g.FillEllipse($dark, 14, 20, 4, 4)
            } finally { $white.Dispose(); $dark.Dispose() }
        } catch {
            try {
                $f = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
                $g.DrawString('鲸', $f, [System.Drawing.Brushes]::White, 2, 24)
                $f.Dispose()
            } catch { }
        }
    })
    # 0.3.14：小鲸鱼右键菜单（关闭小鲸鱼 / 退出程序都在这里）
    $wMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $miWShow = New-Object System.Windows.Forms.ToolStripMenuItem
    $miWShow.Text = '显示待办'
    $miWShow.Add_Click({ Show-Panel -Interactive })
    [void]$wMenu.Items.Add($miWShow)
    $miWAdd = New-Object System.Windows.Forms.ToolStripMenuItem
    $miWAdd.Text = '新增待办…'
    $miWAdd.Add_Click({ Show-AddDialog })
    [void]$wMenu.Items.Add($miWAdd)
    $miWNew = New-Object System.Windows.Forms.ToolStripMenuItem
    $miWNew.Text = '新建清单…'
    $miWNew.Add_Click({ Show-NewListDialog })
    [void]$wMenu.Items.Add($miWNew)
    $miWMgr = New-Object System.Windows.Forms.ToolStripMenuItem
    $miWMgr.Text = '清单管理…'
    $miWMgr.Add_Click({ Show-ListManager })
    [void]$wMenu.Items.Add($miWMgr)
    $miWSet = New-Object System.Windows.Forms.ToolStripMenuItem
    $miWSet.Text = '设置…'
    $miWSet.Add_Click({ Show-Settings })
    [void]$wMenu.Items.Add($miWSet)
    [void]$wMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $miWHide = New-Object System.Windows.Forms.ToolStripMenuItem
    $miWHide.Text = '关闭小鲸鱼'
    $miWHide.Add_Click({ Hide-Whale })
    [void]$wMenu.Items.Add($miWHide)
    $miWExit = New-Object System.Windows.Forms.ToolStripMenuItem
    $miWExit.Text = '退出待办托盘'
    $miWExit.Add_Click({ Exit-App })
    [void]$wMenu.Items.Add($miWExit)
    $script:WhaleMenu = $wMenu
    # 0.3.20：按住拖=定位，松手固定；位移 <3px 当单击=打开主界面；右键=菜单
    $w.Add_MouseDown({
        param($s, $e)
        if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        Start-WhaleDrag -Y ([System.Windows.Forms.Cursor]::Position.Y)
        try { $s.Capture = $true } catch { }
        try { $s.Cursor = [System.Windows.Forms.Cursors]::SizeNS } catch { }
    })
    $w.Add_MouseMove({
        param($s, $e)
        if ($null -eq $script:WhaleDrag) { return }
        Update-WhaleDrag -Y ([System.Windows.Forms.Cursor]::Position.Y)
    })
    $w.Add_MouseUp({
        param($s, $e)
        try { $s.Capture = $false } catch { }
        try { $s.Cursor = [System.Windows.Forms.Cursors]::Hand } catch { }
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) { End-WhaleDrag -RightButton $true; return }
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { End-WhaleDrag }
    })
    $w.Add_MouseEnter({ try { $script:Whale.BackColor = [System.Drawing.Color]::FromArgb(255, 88, 150, 232) } catch { }; Start-WhaleWag })
    $w.Add_MouseLeave({ try { $script:Whale.BackColor = [System.Drawing.Color]::FromArgb(255, 64, 126, 214) } catch { } })
    $w.Add_FormClosing({
        param($s, $e)
        if (-not $script:Exiting) { $e.Cancel = $true }
    })
    $script:Whale = $w

    # 独立小窗：TOOLWINDOW 不进 Alt+Tab，NOACTIVATE 不抢焦点
    if ('DshTodoTray.Win3' -as [type]) {
        try {
            $h = $w.Handle
            $ex = [DshTodoTray.Win3]::ExStyle($h)
            $ex = $ex -bor $script:ExToolWindow -bor $script:ExNoActivate -bor $script:ExLayered
            [void][DshTodoTray.Win3]::SetEx($h, $ex)
        } catch { }
    }
    # 0.3.4（T20261029-02 B-①）：只有 LAYERED 位不够，补属性；Show 时 Show-Whale 会再补一次
    [void](Set-WinAlpha -Hwnd $w.Handle -Opacity ([double]$w.Opacity))
}

function Set-WhalePosition {
    if ($null -eq $script:Whale) { return }
    if ($null -eq $script:WinCfg) { $script:WinCfg = Get-WindowSettings }
    $wa = Get-ScreenArea
    $x = $wa.Right - $script:BarWidth
    if ($script:WinCfg.WhaleSide -eq 'left') { $x = $wa.Left }
    $y = [int]$script:WinCfg.WhaleY
    if ($y -lt $wa.Top) { $y = $wa.Top }
    if ($y -gt ($wa.Bottom - $script:BarHeight)) { $y = $wa.Bottom - $script:BarHeight }
    $script:Whale.Location = New-Object System.Drawing.Point($x, $y)
}

function Show-Whale {
    if ($null -eq $script:Whale) { return }
    # 0.3.4（T20261029-02 B-②）：启动走 collapsed 分支也走这里；必须置位，
    # 否则 Set-Collapsed $false 第一句 `if (-not $script:PanelCollapsed) { return }` 直接吞掉点击。
    $script:PanelCollapsed = $true
    Set-WhalePosition
    # 0.3.37：以前只在「从隐藏变显示」时补一次 HWND_TOPMOST；已经显示着就不再抬，后被别的置顶层
    # 窗口（任务栏、全屏程序、小火箭之类）压上来就上不去了。改成每次 Show 都补一次。
    if (-not $script:Whale.Visible) { $script:Whale.Show() }
    if ('DshTodoTray.Win' -as [type]) {
        try { [void][DshTodoTray.Win]::SetWindowPos($script:Whale.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x0013) } catch { }
    }
    # 0.3.4（T20261029-02 B-①）：Show/TopMost 之后补 layered 属性，24×72 才会真的画出来。
    $alphaOk = Set-WinAlpha -Hwnd $script:Whale.Handle -Opacity ([double]$script:Whale.Opacity)
    Write-Log ('[WHALE] show layered set={0} alpha={1}' -f $alphaOk, [int][Math]::Round(([double]$script:Whale.Opacity) * 255))
    Start-WhaleWag   # 0.3.38：出现时摆两下尾巴
}

function Hide-Whale {
    # 小鲸鱼右键「关闭小鲸鱼」：只留托盘图标（不是退出程序）
    if ($null -eq $script:Whale) { return }
    try { $script:Whale.Hide() } catch { }
    $script:PanelCollapsed = $false
    $script:PeekExpanded = $false
    $script:WhaleDeadline = $null
    if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Stop() } catch { } }
    Write-Log '[WHALE] 关闭小鲸鱼（回托盘）'
}

function Set-Collapsed {
    param([bool]$On, [string]$Reason = '', [switch]$NoShow, [switch]$FromWhale, [switch]$NoAnim)
    if ($null -eq $script:Form) { return }
    if ($On) {
        if ($script:PanelCollapsed) { return }
        if ([bool]$script:Pinned) { return }   # 0.3.25：钉住的面板不收回侧边栏
        if ($null -ne $script:SlideThen) { return }   # 已经在收回动画里，别重复起
        # 0.3.21：先播缩回动画，动画结束再真正收起（-NoAnim 或 AnimOff 时直接收）
        if ((-not $NoShow) -and (-not $NoAnim) -and (-not [bool]$script:AnimOff) -and $script:Form.Visible) {
            $waC = Get-ScreenArea
            $sideC = 'right'
            if ([string]$script:WinCfg.Edge -eq 'left') { $sideC = 'left' }
            elseif ([string]$script:WinCfg.WhaleSide -eq 'left') { $sideC = 'left' }
            $toXC = [int]$waC.Right
            if ($sideC -eq 'left') { $toXC = [int]($waC.Left - [int]$script:Form.Width) }
            $script:SlideThen = @{ Kind = 'collapse'; Reason = $Reason; FromWhale = [bool]$FromWhale }
            Start-SlideAnim -Ctrl $script:Form -FromX ([int]$script:Form.Left) -ToX $toXC -Ms 140
            return
        }
        $script:PanelCollapsed = $true
        $script:WinCfg.Collapsed = $true
        # 0.3.20：小鲸鱼保持它自己的位置（用户 2026-11-10：拖到底就留在底部，不按窗口中心重算）
        if ([string]$script:WinCfg.Edge -ne 'none') { $script:WinCfg.WhaleSide = [string]$script:WinCfg.Edge }
        Save-PanelGeometry
        $script:PeekExpanded = $false
        $script:WhaleDeadline = $null
        if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Stop() } catch { } }
        Set-Interactive $false 'collapse'
        Stop-StateTimers
        Stop-AutoHide
        if ($null -ne $script:OpenFillTimer) { try { $script:OpenFillTimer.Stop() } catch { } }
        Stop-RowRoll
        $script:RollPending = $false
        Hide-CollapseTab
        $script:FromWhale = $false
        if (-not $NoShow -and $script:Form.Visible) {
            $script:AllowHide = $true
            if ($null -ne $script:ShellHook) { $script:ShellHook.AllowHide = $true }
            try { $script:Form.Hide() } finally {
                $script:AllowHide = $false
                if ($null -ne $script:ShellHook) { $script:ShellHook.AllowHide = $false }
            }
        }
        if (-not $NoShow) { Show-Whale }
        if (-not $NoShow) { Restart-BubbleSchedule }   # 0.3.17：回到小鲸鱼状态，冒泡重新起算
        Write-Log ('[WHALE] 收起到侧边（' + $Reason + '）')
    } else {
        if (-not $script:PanelCollapsed) { return }
        $script:PanelCollapsed = $false
        $script:WinCfg.Collapsed = $false
        [void](Save-WindowSettings -Settings $script:WinCfg)
        if (-not $NoShow -and $null -ne $script:Whale) { try { $script:Whale.Hide() } catch { } }
        if (-not $NoShow) { Show-Panel -Interactive -FromWhale:$FromWhale }
        if ([int]$script:WinCfg.AutoCollapseSeconds -gt 0 -and $script:WinCfg.Edge -ne 'none') {
            $script:PeekExpanded = $true
            $script:WhaleDeadline = (Get-Date).AddSeconds([int]$script:WinCfg.AutoCollapseSeconds)
            if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Start() } catch { } }
        }
        Write-Log ('[WHALE] 展开整窗（自动收回 ' + $script:WinCfg.AutoCollapseSeconds + ' 秒）')
    }
}

# 0.3.21：滑动动画（水平方向，ease-out）。Ctrl 可以是主窗体或小鲸鱼窗体。
function Start-SlideAnim {
    param($Ctrl, [int]$FromX, [int]$ToX, [int]$Ms = 140)
    if ($null -eq $Ctrl) { return }
    if ([bool]$script:AnimOff -or $null -eq $script:SlideTimer) {
        try { $Ctrl.Left = $ToX } catch { }
        return
    }
    $script:SlideJob = @{ Ctrl = $Ctrl; From = [int]$FromX; To = [int]$ToX; Start = (Get-Date); Ms = [Math]::Max(50, [int]$Ms) }
    try { $Ctrl.Left = [int]$FromX } catch { }
    $script:SlideTimer.Start()
}

function Update-WhaleSideFromX {
    # 0.3.21：鼠标 X 过屏幕中线 → 鲸鱼换到对应侧的边（带滑动动画）
    param([int]$X)
    if ($null -eq $script:Whale -or $null -eq $script:WinCfg) { return }
    $wa = Get-ScreenArea
    $side = 'right'
    if ($X -lt ($wa.Left + [int](($wa.Right - $wa.Left) / 2))) { $side = 'left' }
    if ($side -eq [string]$script:WinCfg.WhaleSide) { return }
    $script:WinCfg.WhaleSide = $side
    $targetX = [int]($wa.Right - [int]$script:BarWidth)
    if ($side -eq 'left') { $targetX = [int]$wa.Left }
    Start-SlideAnim -Ctrl $script:Whale -FromX ([int]$script:Whale.Left) -ToX $targetX -Ms 130
    Write-Log ('[WHALE] 换边 → ' + $side)
}

# 0.3.20：小鲸鱼拖拽（按住拖=定位、松手固定；位移 <3px 当单击=打开主界面）
function Start-WhaleDrag {
    param([int]$Y)
    if ($null -eq $script:Whale) { return }
    if ($null -eq $script:WinCfg) { $script:WinCfg = Get-WindowSettings }
    $script:WhaleDrag = @{ StartY = [int]$Y; BaseTop = [int]$script:Whale.Top; Moved = $false }
}

function Update-WhaleDrag {
    param([int]$Y)
    if ($null -eq $script:WhaleDrag -or $null -eq $script:Whale) { return }
    $dy = [int]$Y - [int]$script:WhaleDrag.StartY
    if ([Math]::Abs($dy) -ge 3) { $script:WhaleDrag.Moved = $true }
    Update-WhaleSideFromX -X ([System.Windows.Forms.Cursor]::Position.X)
    $wa = Get-ScreenArea
    $newTop = [int]$script:WhaleDrag.BaseTop + $dy
    if ($newTop -lt [int]$wa.Top) { $newTop = [int]$wa.Top }
    if (($newTop + [int]$script:BarHeight) -gt [int]$wa.Bottom) { $newTop = [int]($wa.Bottom - [int]$script:BarHeight) }
    if (($null -ne $script:SlideJob) -and ($script:SlideJob.Ctrl -eq $script:Whale)) {
        # X 正在换边动画里：只跟 Y，别把 X 拽回来
        $script:WinCfg.WhaleY = $newTop
        try { $script:Whale.Top = $newTop } catch { }
    } else {
        $script:WinCfg.WhaleY = $newTop
        Set-WhalePosition
    }
}

function End-WhaleDrag {
    param([bool]$RightButton = $false)
    if ($RightButton) {
        $script:WhaleDrag = $null
        try { $script:WhaleMenu.Show([System.Windows.Forms.Cursor]::Position) } catch { }
        return
    }
    if ($null -eq $script:WhaleDrag) { return }
    $moved = [bool]$script:WhaleDrag.Moved
    $script:WhaleDrag = $null
    if ($moved) {
        if (($null -ne $script:Whale) -and ($null -ne $script:WinCfg)) {
            $script:WinCfg.WhaleY = [int]$script:Whale.Top
            [void](Save-WindowSettings -Settings $script:WinCfg)
            Write-Log ('[WHALE] 拖动定位 y=' + [int]$script:WinCfg.WhaleY)
        }
    } else {
        Set-Collapsed $false '点小鲸鱼' -FromWhale
    }
}

#endregion

# ============================================================
#  M09 收起箭头 · 图钉 · 焦点 —— 侧向箭头、图钉、透明度口径、窗口夹边界、按钮焦点清理
# ============================================================
#region M09 收起箭头 · 图钉 · 焦点
function Initialize-CollapseTab {
    if ($null -ne $script:CollapseTab) { return }
    $t = 'System.Windows.Forms.Form'
    if ('DshTodoTray.TrayForm' -as [type]) { $t = 'DshTodoTray.TrayForm' }
    $f = New-Object $t
    if ($t -eq 'DshTodoTray.TrayForm') { $f.ClickThrough = $false; $f.NoActivate = $true }
    $f.Text = '收起侧边栏'
    $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $f.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $f.ShowInTaskbar = $false
    $f.MinimizeBox = $false
    $f.MaximizeBox = $false
    $f.TopMost = $true
    $f.ClientSize = New-Object System.Drawing.Size(18, 64)
    $f.BackColor = [System.Drawing.Color]::White
    $f.Cursor = [System.Windows.Forms.Cursors]::Hand
    $f.Add_Paint({
        param($s, $e)
        try {
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $w = [int]$s.ClientSize.Width
            $h = [int]$s.ClientSize.Height
            $bg = New-Object System.Drawing.SolidBrush($s.BackColor)
            $edge = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 201, 216, 238), 1)
            $arrow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 64, 126, 214))
            try {
                $g.FillRectangle($bg, 0, 0, $w, $h)
                $g.DrawRectangle($edge, 0, 0, ($w - 1), ($h - 1))
                $cy = [int]($h / 2)
                if ([string]$script:CollapseTabSide -eq 'right') {
                    $g.FillPolygon($arrow, [System.Drawing.Point[]]@(
                        (New-Object System.Drawing.Point(6, ($cy - 9))),
                        (New-Object System.Drawing.Point(6, ($cy + 9))),
                        (New-Object System.Drawing.Point(13, $cy))
                    ))
                } else {
                    $g.FillPolygon($arrow, [System.Drawing.Point[]]@(
                        (New-Object System.Drawing.Point(12, ($cy - 9))),
                        (New-Object System.Drawing.Point(12, ($cy + 9))),
                        (New-Object System.Drawing.Point(5, $cy))
                    ))
                }
            } finally { $bg.Dispose(); $edge.Dispose(); $arrow.Dispose() }
        } catch { }
    })
    $f.Add_MouseClick({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Set-Collapsed $true '收起箭头' }
    })
    $f.Add_MouseEnter({ try { $script:CollapseTab.BackColor = [System.Drawing.Color]::FromArgb(255, 238, 244, 253) } catch { } })
    $f.Add_MouseLeave({ try { $script:CollapseTab.BackColor = [System.Drawing.Color]::White } catch { } })
    $f.Add_FormClosing({
        param($s, $e)
        if (-not $script:Exiting) { $e.Cancel = $true }
    })
    $script:CollapseTab = $f
    if ('DshTodoTray.Win3' -as [type]) {
        try {
            $h = $f.Handle
            $ex = [DshTodoTray.Win3]::ExStyle($h)
            $ex = $ex -bor $script:ExToolWindow -bor $script:ExNoActivate -bor $script:ExLayered
            [void][DshTodoTray.Win3]::SetEx($h, $ex)
        } catch { }
    }
}

function Position-CollapseTab {
    if ($null -eq $script:CollapseTab -or $null -eq $script:Form) { return }
    if (-not $script:FromWhale -or -not $script:Form.Visible) { return }
    $wa = Get-ScreenArea
    $tabW = [int]$script:CollapseTab.Width
    $tabH = [int]$script:CollapseTab.Height
    # 0.3.16：按面板在屏幕哪半边决定箭头贴哪条内沿、朝哪边（用户 2026-11-10 定）
    # 右侧边栏（面板在右半边）→ 箭头贴面板左沿外面、朝右（收起方向就是往右贴边）
    # 左侧边栏（面板在左半边）→ 箭头贴面板右沿外面、朝左
    $panelMid = $script:Form.Left + [int]($script:Form.Width / 2)
    $screenMid = $wa.Left + [int](($wa.Right - $wa.Left) / 2)
    $side = 'right'
    if ($panelMid -lt $screenMid) { $side = 'left' }
    if ($side -eq 'right') {
        $x = $script:Form.Left - $tabW
        if ($x -lt $wa.Left) { $x = $script:Form.Left }   # 左边没空间：退回贴面板内侧左沿
    } else {
        $x = $script:Form.Left + [int]$script:Form.Width
        if (($x + $tabW) -gt $wa.Right) { $x = $script:Form.Left + [int]$script:Form.Width - $tabW }   # 右边没空间：贴内侧右沿
    }
    $y = $script:Form.Top + [int](($script:Form.Height - $tabH) / 2)
    if (($x + $tabW) -gt $wa.Right) { $x = $wa.Right - $tabW }
    if ($x -lt $wa.Left) { $x = $wa.Left }
    if ($y -lt $wa.Top) { $y = $wa.Top }
    if (($y + $tabH) -gt $wa.Bottom) { $y = $wa.Bottom - $tabH }
    $script:CollapseTab.Location = New-Object System.Drawing.Point($x, $y)
    if ($side -ne [string]$script:CollapseTabSide) {
        $script:CollapseTabSide = $side
        try { $script:CollapseTab.Invalidate() } catch { }
    }
}

function Show-CollapseTab {
    Initialize-CollapseTab
    if ($null -eq $script:CollapseTab) { return }
    Position-CollapseTab
    if (-not $script:CollapseTab.Visible) {
        $script:CollapseTab.Show()
        if ('DshTodoTray.Win' -as [type]) {
            try { [void][DshTodoTray.Win]::SetWindowPos($script:CollapseTab.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x0013) } catch { }
        }
    }
    [void](Set-WinAlpha -Hwnd $script:CollapseTab.Handle -Opacity ([double]$script:CollapseTab.Opacity))
    Write-Log ('[TAB] 收起箭头显示 side=' + [string]$script:CollapseTabSide)
}

function Hide-CollapseTab {
    if ($null -ne $script:CollapseTab -and $script:CollapseTab.Visible) {
        try { $script:CollapseTab.Hide() } catch { }
    }
}

function Update-CollapseChrome {
    # 0.3.25：钉住 → 出 ×、不出箭头；未钉住且从侧边展开 → 出箭头、不出 ×
    $pinned = [bool]$script:Pinned
    $fromWhale = [bool]$script:FromWhale
    $showArrow = ((-not $pinned) -and $fromWhale)
    if ($null -ne $script:BtnClose) { try { $script:BtnClose.Visible = ($pinned -or (-not $fromWhale)) } catch { } }
    if ($null -ne $script:BtnPin) { try { $script:BtnPin.Visible = $true; $script:BtnPin.Invalidate() } catch { } }
    # 0.3.14：箭头首次创建/显示会泵消息，期间压住 Deactivate 并把积压消息消化掉，
    # 否则面板会在箭头刚出来的这一下把自己当"失焦"收起来（真机点小鲸鱼展开会闪没）
    $prevSuppress = [bool]$script:SuppressDeactivate
    $script:SuppressDeactivate = $true
    try {
        if ($showArrow -and ($null -ne $script:Form) -and $script:Form.Visible) {
            Show-CollapseTab
            # 只在「显示箭头」这条路上消化积压消息；收起路径不泵消息，
            # 否则拖动收边（Exit-BarPhase）时 DoEvents 会让拖拽定时器把会话结束掉。
            try { [System.Windows.Forms.Application]::DoEvents() } catch { }
        } else {
            Hide-CollapseTab
        }
    } finally {
        $script:SuppressDeactivate = $prevSuppress
    }
}

# 0.3.25 · 图钉 / 拖拽边界
function Save-PinState {
    param([bool]$On)
    $cfg = Get-Config
    if ($null -eq $cfg) { return $false }
    $ui = Get-Prop $cfg 'ui' $null
    if ($null -eq $ui) { $ui = [ordered]@{ mode = 'auto'; hideSeconds = 15; opacity = 100; topmost = $true } }
    Set-Prop $ui 'pinned' $On
    Set-Prop $cfg 'ui' $ui
    try {
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfg) + "`n")
        return $true
    } catch {
        Write-Log ('保存图钉状态失败: ' + $_.Exception.Message) 'ERROR'
        return $false
    }
}

function Toggle-Pin {
    if ($null -eq $script:Form) { return }
    $script:Pinned = -not [bool]$script:Pinned
    if ($null -ne $script:UiSettings) { try { $script:UiSettings.Pinned = $script:Pinned } catch { } }
    [void](Save-PinState -On ([bool]$script:Pinned))
    if ([bool]$script:Pinned) {
        # 钉住：留在当前位置不再收回；开穿透（悬停 0.6s 才可点）+ 允许拖动
        $script:FromWhale = $false
        $script:PeekExpanded = $false
        $script:WhaleDeadline = $null
        if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Stop() } catch { } }
        $script:WinCfg.Edge = 'none'
        $script:WinCfg.Collapsed = $false
        [void](Save-WindowSettings -Settings $script:WinCfg)
        if ($null -ne $script:BtnClose) { try { $script:BtnClose.Visible = $true } catch { } }
        Hide-CollapseTab
        Set-Interactive $false '钉住'
        try { $script:Form.Opacity = Get-PanelOpacityValue } catch { }
        Sync-PanelLayeredAlpha
        Start-StateTimers
        Start-AutoHide
        Write-Log '[PANEL] 图钉：已固定（穿透 + 可拖动）'
    } else {
        Write-Log '[PANEL] 图钉：取消固定，收回侧边栏'
        Set-Collapsed $true '取消图钉'
    }
    Update-PinVisual
}

function Update-PinVisual {
    if ($null -ne $script:BtnPin) { try { $script:BtnPin.Invalidate() } catch { } }
    if ($null -ne $script:PinTip -and $null -ne $script:BtnPin) {
        $t = '固定面板（钉住后不收回侧边栏，可拖动）'
        if ([bool]$script:Pinned) { $t = '取消固定（收回侧边栏）' }
        try { $script:PinTip.SetToolTip($script:BtnPin, $t) } catch { }
    }
    Set-PanelCursor
}

# 0.3.29：透明度只属于钉住模式；侧边展开的面板恒 100%
function Get-PanelOpacityValue {
    if (-not [bool]$script:Pinned) { return 1.0 }
    $op = 100
    if ($null -ne $script:UiSettings) { $op = [int]$script:UiSettings.Opacity }
    return [Math]::Max(0.3, [Math]::Min(1.0, ([double]$op / 100.0)))
}

# 0.3.25：把窗口夹在屏幕工作区内（碰到边顶住；比屏幕还大就两头都顶死）
function Get-ClampedWindowPos {
    param([int]$Left, [int]$Top, [int]$W, [int]$H)
    $wa = Get-ScreenArea
    $maxL = [int]($wa.Right - $W)
    if ($maxL -lt [int]$wa.Left) { $maxL = [int]$wa.Left }
    $maxT = [int]($wa.Bottom - $H)
    if ($maxT -lt [int]$wa.Top) { $maxT = [int]$wa.Top }
    $l = [int]$Left
    $t = [int]$Top
    if ($l -lt [int]$wa.Left) { $l = [int]$wa.Left }
    if ($l -gt $maxL) { $l = $maxL }
    if ($t -lt [int]$wa.Top) { $t = [int]$wa.Top }
    if ($t -gt $maxT) { $t = $maxT }
    return [pscustomobject]@{ Left = $l; Top = $t }
}

function Set-PanelCursor {
    $c = [System.Windows.Forms.Cursors]::Default
    if ([bool]$script:Pinned) { $c = [System.Windows.Forms.Cursors]::SizeAll }
    try { if ($null -ne $script:HeadPanel) { $script:HeadPanel.Cursor = $c } } catch { }
    try { if ($null -ne $script:LblHeader) { $script:LblHeader.Cursor = $c } } catch { }
}

# 0.3.30：按钮点完别留焦点黑框
function Clear-FocusCue {
    # 0.3.32：清「按钮所属窗体」的焦点，弹窗里的按钮也能用
    param($Ctrl)
    $f = $script:Form
    if ($null -ne $Ctrl) { try { $f = $Ctrl.FindForm() } catch { } }
    if ($null -eq $f) { return }
    try { $f.ActiveControl = $null } catch { }
}

function Register-ButtonFocusFix {
    param($Ctrl)
    if ($null -eq $Ctrl) { return }
    foreach ($c in @($Ctrl.Controls)) {
        if ($c -is [System.Windows.Forms.Button]) {
            try { $c.Add_Click({ param($s, $e) Clear-FocusCue -Ctrl $s }) } catch { }
        }
        Register-ButtonFocusFix -Ctrl $c
    }
}

#endregion

# ============================================================
#  M10 冒泡 —— 小鲸鱼旁边的待办气泡：轮播、外观、置顶、显示 6 秒
# ============================================================
#region M10 冒泡
function Test-BubbleContext {
    # 0.3.17（用户 2026-11-10）：只有小鲸鱼（收起侧边）状态才冒泡；
    # 主界面开着不冒、面板和小鲸鱼都关着也不冒。
    if ($null -ne $script:SelfTestForceBubble) { return [bool]$script:SelfTestForceBubble }   # 自检钩子
    $panelShown = ($null -ne $script:Form) -and $script:Form.Visible
    $whaleShown = ($null -ne $script:Whale) -and $script:Whale.Visible
    return ($whaleShown -and (-not $panelShown))
}

function Get-BubbleEdgeColor {
    # 0.3.37：冒泡边框色按优先级走（以前统一 1px 浅灰蓝，几乎看不见）
    param([int]$Prio = 0)
    if ($Prio -ge 3) { return [System.Drawing.Color]::FromArgb(255, 209, 52, 56) }   # 3★ 红
    if ($Prio -eq 2) { return [System.Drawing.Color]::FromArgb(255, 235, 150, 0) }   # 2★ 橙
    return [System.Drawing.Color]::FromArgb(255, 96, 140, 205)                       # 普通蓝
}

function Initialize-Bubble {
    if ($null -ne $script:Bubble) { return }
    $t = 'System.Windows.Forms.Form'
    if ('DshTodoTray.TrayForm' -as [type]) { $t = 'DshTodoTray.TrayForm' }
    $f = New-Object $t
    if ($t -eq 'DshTodoTray.TrayForm') { $f.ClickThrough = $true; $f.NoActivate = $true }
    $f.Text = '待办冒泡'
    $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $f.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $f.ShowInTaskbar = $false
    $f.MinimizeBox = $false
    $f.MaximizeBox = $false
    $f.TopMost = $true
    $f.ClientSize = New-Object System.Drawing.Size(260, 88)
    $f.BackColor = [System.Drawing.Color]::White
    $f.Opacity = 1.0
    $f.Add_Paint({
        param($s, $e)
        try {
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
            $w = [int]$s.ClientSize.Width
            $h = [int]$s.ClientSize.Height
            $r = 12
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $fill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
            # 0.3.37：边框从 1px 浅灰蓝 → 2px 按星级上色（普通蓝 / 2★ 橙 / 3★ 红），更显眼
            $edge = New-Object System.Drawing.Pen((Get-BubbleEdgeColor -Prio ([int]$script:BubblePrio)), 2)
            # 2px 描边把路径内缩 1px，否则外半边会被窗体 Region 裁掉
            $bx = 1; $by = 1; $bw = $w - 2; $bh = $h - 2
            try {
                $path.AddArc($bx, $by, ($r * 2), ($r * 2), 180, 90)
                $path.AddArc(($bx + $bw - $r * 2), $by, ($r * 2), ($r * 2), 270, 90)
                $path.AddArc(($bx + $bw - $r * 2), ($by + $bh - $r * 2), ($r * 2), ($r * 2), 0, 90)
                $path.AddArc($bx, ($by + $bh - $r * 2), ($r * 2), ($r * 2), 90, 90)
                $path.CloseFigure()
                $g.FillPath($fill, $path)
                $g.DrawPath($edge, $path)
            } finally {
                $path.Dispose(); $fill.Dispose(); $edge.Dispose()
            }
            # 左侧色条：3★ 红 / 2★ 黄 / 普通灰
            $c = [System.Drawing.Color]::FromArgb(255, 154, 164, 178)
            if ([int]$script:BubblePrio -ge 3) { $c = [System.Drawing.Color]::FromArgb(255, 209, 52, 56) }
            elseif ([int]$script:BubblePrio -eq 2) { $c = [System.Drawing.Color]::FromArgb(255, 255, 185, 0) }
            $bar = New-Object System.Drawing.SolidBrush($c)
            try { $g.FillRectangle($bar, 14, 16, 4, ($h - 32)) } finally { $bar.Dispose() }
            # 标题（超出省略）
            $tf = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5, [System.Drawing.FontStyle]::Bold)
            $tb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 34, 49, 74))
            try {
                $rect = New-Object System.Drawing.RectangleF(30, 13, ($w - 46), ($h - 38))
                $sf = New-Object System.Drawing.StringFormat
                $sf.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
                $g.DrawString([string]$script:BubbleText, $tf, $tb, $rect, $sf)
                $sf.Dispose()
            } finally { $tf.Dispose(); $tb.Dispose() }
            # 角标
            $cf = New-Object System.Drawing.Font('Microsoft YaHei UI', 7.5)
            $cb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 140, 146, 154))
            try {
                $cap = '待办'
                if ([int]$script:BubblePrio -ge 3) { $cap = '3★ 紧急' } elseif ([int]$script:BubblePrio -eq 2) { $cap = '2★ 重要' }
                $g.DrawString($cap, $cf, $cb, (New-Object System.Drawing.PointF(30, ($h - 24))))
            } finally { $cf.Dispose(); $cb.Dispose() }
        } catch { }
    })
    $script:Bubble = $f
    [void]$f.Handle
    Set-BubbleRegion
    Apply-BubbleExStyle
}

# ============================================================
#  0.3.11 · 小鲸鱼冒泡
#  每隔一段随机时间（15~N 秒，N = 设置里的「最长间隔」，上限 60）在鲸鱼旁边冒一个气泡，
#  依次显示 3★ → 2★ → 普通 的待办标题，每个 6 秒（$script:BubbleSeconds，后续可改）。
#  气泡不透明、圆角、鼠标完全穿透：LAYERED|TRANSPARENT|NOACTIVATE|TOOLWINDOW
# ============================================================
function Set-BubbleRegion {
    if ($null -eq $script:Bubble) { return }
    $r = 12
    $w = [int]$script:Bubble.Width
    $h = [int]$script:Bubble.Height
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    try {
        $p.AddArc(0, 0, ($r * 2), ($r * 2), 180, 90)
        $p.AddArc(($w - $r * 2), 0, ($r * 2), ($r * 2), 270, 90)
        $p.AddArc(($w - $r * 2), ($h - $r * 2), ($r * 2), ($r * 2), 0, 90)
        $p.AddArc(0, ($h - $r * 2), ($r * 2), ($r * 2), 90, 90)
        $p.CloseFigure()
        $script:Bubble.Region = New-Object System.Drawing.Region($p)
    } finally { $p.Dispose() }
}

function Apply-BubbleExStyle {
    if ($null -eq $script:Bubble) { return }
    if (-not ('DshTodoTray.Win3' -as [type])) { return }
    try {
        $h = $script:Bubble.Handle
        $ex = [DshTodoTray.Win3]::ExStyle($h)
        $ex = $ex -bor $script:ExLayered -bor $script:ExTransparent -bor $script:ExNoActivate -bor $script:ExToolWindow
        [void][DshTodoTray.Win3]::SetEx($h, $ex)
        # 不透明：alpha 固定 255（LAYERED 在这里只是为了圆角 Region 和穿透）
        [void](Set-WinAlpha -Hwnd $h -Opacity 1.0)
    } catch { }
}

function Set-BubblePosition {
    # 贴着鲸鱼（鲸鱼收起时）/ 贴着面板（面板展开时）冒出来
    if ($null -eq $script:Bubble) { return }
    $wa = Get-ScreenArea
    $anchor = $null
    if ($null -ne $script:Whale -and $script:Whale.Visible) { $anchor = $script:Whale.Bounds }
    elseif ($null -ne $script:Form -and $script:Form.Visible) { $anchor = $script:Form.Bounds }
    if ($null -eq $anchor) { return }
    $side = 'right'
    if ($null -ne $script:WinCfg) { $side = [string]$script:WinCfg.WhaleSide }
    if ($side -eq 'left') { $x = [int]$anchor.Right + 10 }
    else { $x = [int]$anchor.Left - 10 - [int]$script:Bubble.Width }
    $y = [int]$anchor.Top + [int](($anchor.Height - [int]$script:Bubble.Height) / 2)
    if ($x -lt $wa.Left) { $x = $wa.Left + 8 }
    if (($x + $script:Bubble.Width) -gt $wa.Right) { $x = $wa.Right - $script:Bubble.Width - 8 }
    if ($y -lt $wa.Top) { $y = $wa.Top }
    if (($y + $script:Bubble.Height) -gt $wa.Bottom) { $y = $wa.Bottom - $script:Bubble.Height }
    $script:Bubble.Location = New-Object System.Drawing.Point($x, $y)
}

function Get-BubbleIntervalSeconds {
    # 最长间隔 N（10~60，取设置值）；实际间隔在 15~N 之间随机，不超过 1 分钟
    $max = 60
    if ($null -ne $script:UiSettings) { $max = [int]$script:UiSettings.BubbleMaxSeconds }
    if ($max -lt 10) { $max = 10 }
    if ($max -gt 60) { $max = 60 }
    $min = 15
    if ($max -le $min) { return $max }
    return [int](Get-Random -Minimum $min -Maximum ($max + 1))
}

function Restart-BubbleSchedule {
    $script:BubbleIndex = 0
    Hide-Bubble
    $script:BubbleNextAt = (Get-Date).AddSeconds((Get-BubbleIntervalSeconds))
    if ($null -ne $script:BubbleTimer) { try { $script:BubbleTimer.Start() } catch { } }
}

function Get-BubbleEntry {
    # Load-State 已按 3★→2★→1★ 排好，这里按顺序轮播，跑到头再从头
    # 0.3.12：跟着主界面选中的清单走——全部清单(-1) = 所有清单轮流；选中某个 = 只轮这个清单
    $state = Load-State
    $listIdx = [int]$script:FilterListIndex
    $items = @($state.Entries | Where-Object {
        ([string]$_.Status -ne 'done') -and (($listIdx -lt 0) -or ([int]$_.ListIndex -eq $listIdx))
    })
    if ($items.Count -eq 0) { return $null }
    if ($script:BubbleIndex -lt 0 -or $script:BubbleIndex -ge $items.Count) { $script:BubbleIndex = 0 }
    $e = $items[$script:BubbleIndex]
    $script:BubbleIndex++
    if ($script:BubbleIndex -ge $items.Count) { $script:BubbleIndex = 0 }
    return $e
}

function Show-Bubble {
    param($Entry)
    if ($null -eq $Entry) { return }
    Initialize-Bubble
    if ($null -eq $script:Bubble) { return }
    $script:BubbleText = [string]$Entry.Title
    $script:BubblePrio = [int]$Entry.Prio
    Set-BubblePosition
    $script:Bubble.Invalidate()
    if (-not $script:Bubble.Visible) {
        $script:Bubble.Show()
        Apply-BubbleExStyle
        Set-BubbleRegion
    }
    # 0.3.33：全屏程序（置顶）会压住冒泡——和小鲸鱼/面板一样，显示后显式补一次 HWND_TOPMOST。
    # 不激活、不改大小位置：SWP_NOSIZE(1)|SWP_NOMOVE(2)|SWP_NOACTIVATE(0x10)
    try { $script:Bubble.TopMost = $true } catch { }
    if ('DshTodoTray.Win' -as [type]) {
        try { [void][DshTodoTray.Win]::SetWindowPos($script:Bubble.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x0013) } catch { }
    }
    $script:BubbleHideAt = (Get-Date).AddSeconds([int]$script:BubbleSeconds)
    Write-Log ('[BUBBLE] 冒一个：' + $script:BubbleText + '（' + $script:BubblePrio + '★）')
    Start-WhaleWag   # 0.3.38：冒泡时鲸鱼摆摆尾巴（它不是触发的直接原因，只是陪着动一下）
}

function Hide-Bubble {
    $script:BubbleHideAt = $null
    if ($null -ne $script:Bubble -and $script:Bubble.Visible) {
        try { $script:Bubble.Hide() } catch { }
        Write-Log '[BUBBLE] 收起'
    }
}

#endregion

# ============================================================
#  M11 托盘图标 —— GDI 画未完成条数图标、悬停提示
# ============================================================
#region M11 托盘图标
function New-TrayIconObject {
    param([int]$Pending)
    $size = 32
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $g.Clear([System.Drawing.Color]::Transparent)
        $rect = New-Object System.Drawing.Rectangle(1, 1, 30, 30)

        if ($Pending -le 0) {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 128, 138, 148))
            try { $g.FillEllipse($brush, $rect) } finally { $brush.Dispose() }
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 3.2)
            try {
                $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
                $pts = [System.Drawing.PointF[]]@(
                    (New-Object System.Drawing.PointF(9.5, 16.5)),
                    (New-Object System.Drawing.PointF(14.0, 21.0)),
                    (New-Object System.Drawing.PointF(22.5, 11.5))
                )
                $g.DrawLines($pen, $pts)
            } finally { $pen.Dispose() }
        } else {
            $color = [System.Drawing.Color]::FromArgb(255, 232, 124, 20)
            if ($Pending -ge 10) { $color = [System.Drawing.Color]::FromArgb(255, 214, 58, 58) }
            $brush = New-Object System.Drawing.SolidBrush($color)
            try { $g.FillEllipse($brush, $rect) } finally { $brush.Dispose() }

            $text = [string]$Pending
            if ($Pending -gt 99) { $text = '99' }
            $px = 20.0
            if ($text.Length -ge 2) { $px = 15.5 }
            $font = New-Object System.Drawing.Font('Segoe UI', $px, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $sf = New-Object System.Drawing.StringFormat
            try {
                $sf.Alignment     = [System.Drawing.StringAlignment]::Center
                $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
                $textRect = New-Object System.Drawing.RectangleF(0, -0.5, 32, 32)
                $g.DrawString($text, $font, [System.Drawing.Brushes]::White, $textRect, $sf)
            } finally { $sf.Dispose(); $font.Dispose() }
        }
    } finally {
        $g.Dispose()
    }

    $hicon = $bmp.GetHicon()
    $icon  = [System.Drawing.Icon]::FromHandle($hicon)
    $bmp.Dispose()
    return [pscustomobject]@{ Icon = $icon; Handle = $hicon }
}

function Update-TrayIcon {
    param($State)
    if ($null -eq $script:Notify) { return }
    $made = New-TrayIconObject -Pending ([int]$State.Pending)

    $oldIcon = $script:Notify.Icon
    $script:Notify.Icon = $made.Icon
    if ($null -ne $oldIcon) { $oldIcon.Dispose() }

    if ($script:IconHandle -ne [IntPtr]::Zero) { [void]$script:OldIconHandles.Add($script:IconHandle) }
    $script:IconHandle = $made.Handle
    while ($script:OldIconHandles.Count -gt 2) {
        $h = $script:OldIconHandles[0]
        $script:OldIconHandles.RemoveAt(0)
        if ($script:HasNative) { [void][DshTodoTray.Native]::DestroyIcon($h) }
    }

    $tip = ('待办 {0} 条' -f $State.Pending)
    if ($State.Overdue -gt 0) { $tip += ('（逾期 {0}）' -f $State.Overdue) }
    if ($null -ne $State.NextDue) { $tip += ('｜最近到期 ' + $State.NextDue.ToString('MM-dd HH:mm')) }
    if ($tip.Length -gt 60) { $tip = $tip.Substring(0, 60) }
    try { $script:Notify.Text = $tip } catch { }
    $script:LastPending = [int]$State.Pending
}

#endregion

# ============================================================
#  M12 列表行与卷帘 —— 行控件工厂、卷帘逐行铺开、编辑态拖动、状态刷新
# ============================================================
#region M12 列表行与卷帘
function New-EntryRow {
    param($Entry, [int]$RowWidth, [bool]$ShowList, [bool]$EditMode = $false)

    $row = New-Object System.Windows.Forms.Panel
    $row.Size = New-Object System.Drawing.Size($RowWidth, 46)
    $isDone = ($Entry.Status -eq 'done')
    # R5：常态下星级只用底色 + 左侧竖条体现；编辑态才显示 3★ 字样（M3）
    $prio = 1
    if ($null -ne $Entry.PSObject.Properties['Prio']) { $prio = [int]$Entry.Prio }
    if ($prio -lt 1 -or $prio -gt 3) { $prio = 1 }
    $baseColor = [System.Drawing.Color]::White
    $barColor = [System.Drawing.Color]::Empty
    if ($prio -eq 3) { $baseColor = [System.Drawing.Color]::FromArgb(255, 253, 231, 233); $barColor = [System.Drawing.Color]::FromArgb(255, 209, 52, 56) }
    elseif ($prio -eq 2) { $baseColor = [System.Drawing.Color]::FromArgb(255, 255, 244, 206); $barColor = [System.Drawing.Color]::FromArgb(255, 255, 185, 0) }
    $row.BackColor = $baseColor
    $row | Add-Member -NotePropertyName BaseColor -NotePropertyValue $baseColor -Force
    $row | Add-Member -NotePropertyName Entry -NotePropertyValue $Entry -Force
    $row.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 1)
    if ($barColor -ne [System.Drawing.Color]::Empty) {
        $bar = New-Object System.Windows.Forms.Panel
        $bar.BackColor = $barColor
        $bar.Dock = [System.Windows.Forms.DockStyle]::Left
        $bar.Width = 3
        $bar.Tag = 'prio-bar'
        $row.Controls.Add($bar)
    }
    $row.Cursor = [System.Windows.Forms.Cursors]::Hand
    $row.Add_MouseEnter({ param($s, $e) Set-RowHover -Ctrl $s -On $true })
    $row.Add_MouseLeave({ param($s, $e) Set-RowHover -Ctrl $s -On $false })
    $row.Add_Paint({
        param($s, $e)
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 236, 238, 242), 1)
        try { $e.Graphics.DrawLine($pen, 0, ($s.Height - 1), $s.Width, ($s.Height - 1)) } finally { $pen.Dispose() }
    })

    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Size = New-Object System.Drawing.Size(18, 18)
    $cb.Location = New-Object System.Drawing.Point(12, 15)
    $cb.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cb.Text = ''
    $cb.Checked = ($Entry.Status -eq 'done')
    $cb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cb.Tag = [pscustomobject]@{ ListIndex = $Entry.ListIndex; ItemId = $Entry.ItemId }
    $cb.Add_Click({ param($s, $e) On-CheckChanged -Sender $s })
    $cb.Visible = (-not $EditMode)   # 编辑态：每行是 ☰ 标题 3★ [⚙] [🗑]，不放复选框
    $row.Controls.Add($cb)

    $titleX = 38
    if ($EditMode) { $titleX = 34 }
    $titleW = $RowWidth - $titleX - 10
    if ($EditMode) { $titleW = $RowWidth - $titleX - 132 }

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Entry.Title
    $lbl.AutoSize = $false
    $lbl.AutoEllipsis = $true
    $lbl.Location = New-Object System.Drawing.Point($titleX, 7)
    $lbl.Size = New-Object System.Drawing.Size($titleW, 20)
    $lbl.Font = $script:FontTitle
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 32, 36, 42)
    if ($isDone) {
        $lbl.Font = $script:FontStrike
        $lbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 150, 156, 162)
    }
    $lbl.Add_MouseEnter({ param($s, $e) Set-RowHover -Ctrl $s -On $true })
    $lbl.Add_MouseLeave({ param($s, $e) Set-RowHover -Ctrl $s -On $false })
    $row.Controls.Add($lbl)

    $parts = @()
    if ($ShowList) { $parts += ('[' + $Entry.ListName + ']') }
    if (-not $EditMode) {
        # 编辑态隐藏「到期/逾期」（界面示意 §9 M1）
        if ($isDone) {
            # P1：已完成的不再强调「到期/逾期」，改成显示完成时间
            if ($null -ne $Entry.DoneAt) { $parts += ('完成 ' + $Entry.DoneAt.ToString('MM-dd HH:mm')) }
        }
        elseif ($Entry.Overdue -and $null -ne $Entry.DueDate) { $parts += ('逾期 ' + $Entry.DueDate.ToString('MM-dd HH:mm')) }
        elseif ($null -ne $Entry.DueDate) { $parts += ('到期 ' + $Entry.DueDate.ToString('MM-dd HH:mm')) }
    }
    if ($Entry.Tags.Count -gt 0) { $parts += ('#' + ($Entry.Tags -join ' #')) }

    $meta = New-Object System.Windows.Forms.Label
    $meta.Text = ($parts -join '  ·  ')
    $meta.AutoSize = $false
    $meta.AutoEllipsis = $true
    $meta.Location = New-Object System.Drawing.Point($titleX, 27)
    $meta.Size = New-Object System.Drawing.Size($titleW, 16)
    $meta.Font = $script:FontMeta
    $meta.ForeColor = [System.Drawing.Color]::FromArgb(255, 148, 154, 162)
    if ($Entry.Overdue -and -not $isDone -and -not $EditMode) {
        $meta.Font = $script:FontMetaHot
        $meta.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 40, 40)
    }
    $meta.Add_MouseEnter({ param($s, $e) Set-RowHover -Ctrl $s -On $true })
    $meta.Add_MouseLeave({ param($s, $e) Set-RowHover -Ctrl $s -On $false })
    $row.Controls.Add($meta)

    if (-not $EditMode) {
        # P2：整行可点——点标题、副行、行内空白都等同勾选（复选框自己走自己的 Click）
        $row.Tag = $cb
        $lbl.Tag = $cb
        $meta.Tag = $cb
        $lbl.Cursor = [System.Windows.Forms.Cursors]::Hand
        $meta.Cursor = [System.Windows.Forms.Cursors]::Hand
        $row.Add_Click({ param($s, $e) Toggle-RowCheck -Box $s.Tag })
        $lbl.Add_Click({ param($s, $e) Toggle-RowCheck -Box $s.Tag })
        $meta.Add_Click({ param($s, $e) Toggle-RowCheck -Box $s.Tag })
    } else {
        # 编辑态：点行不再勾选，避免误操作
        $row.Cursor = [System.Windows.Forms.Cursors]::Default
        $lbl.Cursor = [System.Windows.Forms.Cursors]::Default
        $meta.Cursor = [System.Windows.Forms.Cursors]::Default

        $handle = New-Object System.Windows.Forms.Label
        $handle.Text = [string][char]0x2630
        $handle.AutoSize = $false
        $handle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $handle.Location = New-Object System.Drawing.Point(6, 10)
        $handle.Size = New-Object System.Drawing.Size(22, 26)
        $handle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11)
        $handle.ForeColor = [System.Drawing.Color]::FromArgb(255, 110, 116, 124)
        $handle.Cursor = [System.Windows.Forms.Cursors]::SizeAll
        $handle.Tag = [pscustomobject]@{ Entry = $Entry; Row = $row }
        $handle.Add_MouseDown({ param($s, $e) Start-RowDrag -Sender $s })
        $handle.Add_MouseMove({ param($s, $e) Update-RowDrag -Sender $s })
        $handle.Add_MouseUp({ param($s, $e) End-RowDrag -Sender $s })
        $row.Controls.Add($handle)

        $starColor = [System.Drawing.Color]::FromArgb(255, 138, 143, 150)
        if ($prio -eq 3) { $starColor = [System.Drawing.Color]::FromArgb(255, 209, 52, 56) }
        elseif ($prio -eq 2) { $starColor = [System.Drawing.Color]::FromArgb(255, 160, 110, 0) }
        $star = New-Object System.Windows.Forms.Label
        $star.Text = ('{0}★' -f $prio)
        $star.AutoSize = $false
        $star.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
        $star.Font = $script:FontMetaHot
        $star.ForeColor = $starColor
        $star.Location = New-Object System.Drawing.Point(($RowWidth - 128), 10)
        $star.Size = New-Object System.Drawing.Size(36, 22)
        $row.Controls.Add($star)

        $btnGear = New-Object System.Windows.Forms.Button
        $btnGear.Text = [string][char]0x2699
        $btnGear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnGear.FlatAppearance.BorderSize = 0
        $btnGear.Font = New-Object System.Drawing.Font('Segoe UI Symbol', 10)
        $btnGear.Size = New-Object System.Drawing.Size(28, 26)
        $btnGear.Location = New-Object System.Drawing.Point(($RowWidth - 92), 8)
        $btnGear.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btnGear.Tag = $Entry
        $btnGear.Add_Click({ param($s, $e) Show-EditDialog -Entry $s.Tag })
        $row.Controls.Add($btnGear)

        $btnDel = New-Object System.Windows.Forms.Button
        $btnDel.Text = '🗑'
        $btnDel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnDel.FlatAppearance.BorderSize = 0
        $btnDel.Font = New-Object System.Drawing.Font('Segoe UI Emoji', 9)
        $btnDel.Size = New-Object System.Drawing.Size(28, 26)
        $btnDel.Location = New-Object System.Drawing.Point(($RowWidth - 60), 8)
        $btnDel.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btnDel.Tag = $Entry
        $btnDel.Add_Click({ param($s, $e) Invoke-DeleteEntry -Entry $s.Tag })
        $row.Controls.Add($btnDel)
    }

    return $row
}

function New-WarnRow {
    param([string]$Text, [int]$RowWidth)
    $row = New-Object System.Windows.Forms.Panel
    $row.Size = New-Object System.Drawing.Size($RowWidth, 40)
    $row.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 249, 235)
    $row.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 2)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = ('⚠ ' + $Text)
    $lbl.AutoSize = $false
    $lbl.AutoEllipsis = $true
    $lbl.Location = New-Object System.Drawing.Point(8, 6)
    $lbl.Size = New-Object System.Drawing.Size(($RowWidth - 16), 30)
    $lbl.Font = $script:FontMeta
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 90, 0)
    $row.Controls.Add($lbl)
    return $row
}

function New-DeletedRow {
    # 0.3.9：已删除但还在 15 秒撤销窗口里的条目 —— 下划线 + 灰色 + 撤销按钮
    param($Pending, [int]$RowWidth)
    $row = New-Object System.Windows.Forms.Panel
    $row.Size = New-Object System.Drawing.Size($RowWidth, 42)
    $row.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 1)
    $row.BackColor = [System.Drawing.Color]::FromArgb(255, 244, 244, 244)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = ('已删除：' + [string]$Pending.Title)
    $lbl.AutoSize = $false
    $lbl.AutoEllipsis = $true
    $lbl.Location = New-Object System.Drawing.Point(12, 11)
    $lbl.Size = New-Object System.Drawing.Size(($RowWidth - 112), 22)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 130, 136, 144)
    $lbl.Font = New-Object System.Drawing.Font($script:FontMeta.FontFamily, 9, [System.Drawing.FontStyle]::Underline)
    $row.Controls.Add($lbl)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = '撤销'
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0
    $btn.Font = $script:FontMeta
    $btn.ForeColor = [System.Drawing.Color]::FromArgb(255, 64, 126, 214)
    $btn.Size = New-Object System.Drawing.Size(56, 24)
    $btn.Location = New-Object System.Drawing.Point(($RowWidth - 64), 9)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Tag = [string]$Pending.Key
    $btn.Add_Click({ param($s, $e) Invoke-UndoDelete -Key ([string]$s.Tag) })
    $row.Controls.Add($btn)
    return $row
}

function New-EmptyLabel {
    param([int]$RowWidth, [string]$Text = '没有未完成的待办')    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.AutoSize = $false
    $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $lbl.Size = New-Object System.Drawing.Size($RowWidth, 120)
    $lbl.Margin = New-Object System.Windows.Forms.Padding(0, 24, 0, 0)
    $lbl.Font = $script:FontTitle
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 150, 156, 162)
    return $lbl
}

function Get-RowSpecs {
    # 0.3.24：只算「该有哪些行」，不造控件（同步建行和卷帘建行共用这一份口径）
    param($State)
    $flow = $script:Flow
    $scroll = [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth
    $rowW = $flow.ClientSize.Width - $flow.Padding.Horizontal - $scroll - 2
    if ($rowW -lt 220) { $rowW = 360 }

    $specs = @()
    if ($State.Errors.Count -gt 0) {
        foreach ($err in $State.Errors) { $specs += @{ Kind = 'warn'; Text = $err } }
    }
    $shown = @(Get-FilteredEntries -State $State)
    $filtering = (([int]$script:FilterListIndex -ge 0) -or (-not [string]::IsNullOrWhiteSpace($script:FilterText)))
    if ($shown.Count -eq 0) {
        $emptyText = '没有未完成的待办'
        if ($filtering -and @($State.Entries).Count -gt 0) { $emptyText = '没有匹配的待办' }
        $specs += @{ Kind = 'empty'; Text = $emptyText }
    } else {
        $showList = (@($State.Lists).Count -gt 1)
        foreach ($en in $shown) { $specs += @{ Kind = 'entry'; Entry = $en; ShowList = $showList } }
    }
    # 0.3.9：撤销窗口内的「已删除」行（数据已经删了，这里只是给一次反悔机会）
    foreach ($pd in @($script:PendingDeletes)) { $specs += @{ Kind = 'deleted'; Pending = $pd } }
    return [pscustomobject]@{ RowW = $rowW; Specs = $specs }
}

function Get-BlendColor {
    # 0.3.25：两色之间插值（t=0..1）
    param([System.Drawing.Color]$From, [System.Drawing.Color]$To, [double]$T)
    if ($T -lt 0) { $T = 0 }
    if ($T -gt 1) { $T = 1 }
    $r = [int]($From.R + ($To.R - $From.R) * $T)
    $g = [int]($From.G + ($To.G - $From.G) * $T)
    $b = [int]($From.B + ($To.B - $From.B) * $T)
    return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
}

function Add-RowSpec {
    # 0.3.24：按规格造一行并加到列表；-Fade 时先浅一档，交给 RollTimer 淡入（0.3.25）
    param($Spec, [int]$RowWidth, [switch]$Fade)
    if ($null -eq $script:Flow -or $null -eq $Spec) { return }
    switch ([string]$Spec.Kind) {
        'warn'    { $script:Flow.Controls.Add((New-WarnRow -Text ([string]$Spec.Text) -RowWidth $RowWidth)) }
        'empty'   { $script:Flow.Controls.Add((New-EmptyLabel -RowWidth $RowWidth -Text ([string]$Spec.Text))) }
        'deleted' { $script:Flow.Controls.Add((New-DeletedRow -Pending $Spec.Pending -RowWidth $RowWidth)) }
        default   { $script:Flow.Controls.Add((New-EntryRow -Entry $Spec.Entry -RowWidth $RowWidth -ShowList ([bool]$Spec.ShowList) -EditMode ([bool]$script:EditMode))) }
    }
    if ($Fade -and ($script:Flow.Controls.Count -gt 0)) {
        $row = $script:Flow.Controls[$script:Flow.Controls.Count - 1]
        $baseProp = $row.PSObject.Properties['BaseColor']
        if ($null -ne $baseProp -and $null -ne $baseProp.Value) {
            $to = [System.Drawing.Color]$baseProp.Value
            $from = Get-BlendColor -From $to -To ([System.Drawing.Color]::White) -T 0.55
            try { $row.BackColor = $from } catch { }
            [void]$script:FadeRows.Add(@{ Row = $row; From = $from; To = $to; Step = 0 })
        }
    }
    # 0.3.30：行内按钮（撤销/齿轮/删除）也不留焦点黑框
    if ($script:Flow.Controls.Count -gt 0) {
        Register-ButtonFocusFix -Ctrl $script:Flow.Controls[$script:Flow.Controls.Count - 1]
    }
}

function Clear-Rows {
    if ($null -eq $script:Flow) { return }
    $old = @($script:Flow.Controls)
    $script:Flow.Controls.Clear()
    foreach ($c in $old) { try { $c.Dispose() } catch { } }
}

function Build-Rows {
    param($State)
    if ($null -eq $script:Flow) { return }
    Stop-RowRoll
    $flow = $script:Flow
    $flow.SuspendLayout()
    try {
        Clear-Rows
        $pkg = Get-RowSpecs -State $State
        foreach ($sp in @($pkg.Specs)) { Add-RowSpec -Spec $sp -RowWidth ([int]$pkg.RowW) }
    } finally {
        $flow.ResumeLayout()
    }
}

function Start-RowRoll {
    param($State)
    if ($null -eq $script:Flow) { return }
    Stop-RowRoll
    $pkg = Get-RowSpecs -State $State
    $script:RollWidth = [int]$pkg.RowW
    $script:RollQueue = @($pkg.Specs)
    $script:RollIndex = 0
    $script:FadeRows.Clear()
    $flow = $script:Flow
    $flow.SuspendLayout()
    try { Clear-Rows } finally { $flow.ResumeLayout() }
    if ($script:RollQueue.Count -eq 0) { return }
    if ($null -eq $script:RollTimer) { Build-Rows -State $State; return }
    $script:RollTimer.Start()
}

function Step-RowRoll {
    # 返回本拍加了几行；卷帘定时器每拍调它（0.3.25：顺带推进淡入）
    param([int]$Max = 1)
    if ($null -eq $script:Flow) { return 0 }
    $added = 0
    while (($added -lt $Max) -and ([int]$script:RollIndex -lt @($script:RollQueue).Count)) {
        Add-RowSpec -Spec $script:RollQueue[[int]$script:RollIndex] -RowWidth ([int]$script:RollWidth) -Fade
        $script:RollIndex++
        $added++
    }
    # 淡入：8 拍从浅色到原色
    for ($i = @($script:FadeRows).Count - 1; $i -ge 0; $i--) {
        $fr = $script:FadeRows[$i]
        $fr.Step++
        $t = [Math]::Min(1.0, ([double]$fr.Step / [double][Math]::Max(1, [int]$script:RollFadeSteps)))
        try { $fr.Row.BackColor = (Get-BlendColor -From $fr.From -To $fr.To -T $t) } catch { }
        if ($t -ge 1) { try { $script:FadeRows.RemoveAt($i) } catch { } }
    }
    if (([int]$script:RollIndex -ge @($script:RollQueue).Count) -and (@($script:FadeRows).Count -eq 0)) {
        if ($null -ne $script:RollTimer) { try { $script:RollTimer.Stop() } catch { } }
        $script:RollQueue = @()
        $script:RollIndex = 0
    }
    return $added
}

# 0.3.24 · 卷帘：清空后每拍补几行，看起来从上到下一个一个显出来
function Stop-RowRoll {
    if ($null -ne $script:RollTimer) { try { $script:RollTimer.Stop() } catch { } }
    # 没淡完的行直接落到目标色，别留在浅色
    foreach ($fr in @($script:FadeRows)) {
        try { $fr.Row.BackColor = $fr.To } catch { }
    }
    $script:FadeRows.Clear()
    $script:RollQueue = @()
    $script:RollIndex = 0
}

function Set-RowHover {
    param($Ctrl, [bool]$On)
    $row = $Ctrl
    if ($Ctrl -isnot [System.Windows.Forms.Panel]) { $row = $Ctrl.Parent }
    if ($null -eq $row) { return }
    if ($row -isnot [System.Windows.Forms.Panel]) { return }
    # R5：行底色按星级，悬停只在底色上压暗一点，别把 3★/2★ 的色块刷成白色
    $base = [System.Drawing.Color]::White
    $prop = $row.PSObject.Properties['BaseColor']
    if ($null -ne $prop -and $null -ne $prop.Value) { $base = $prop.Value }
    if ($On) {
        $r = [Math]::Max(0, [int]$base.R - 10)
        $g = [Math]::Max(0, [int]$base.G - 10)
        $b = [Math]::Max(0, [int]$base.B - 10)
        $row.BackColor = [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
    } else {
        $row.BackColor = $base
    }
}

function Toggle-RowCheck {
    param($Box)
    if ($null -eq $Box) { return }
    if ($Box -isnot [System.Windows.Forms.CheckBox]) { return }
    $Box.Checked = -not $Box.Checked
    On-CheckChanged -Sender $Box
}

function Toggle-EditMode {
    $script:EditMode = -not $script:EditMode
    if ($null -ne $script:EditButton) {
        if ($script:EditMode) { $script:EditButton.Text = '完成' } else { $script:EditButton.Text = '编辑' }
    }
    $script:DragEntry = $null
    $script:DragTargetIndex = -1
    if ($null -ne $script:Form -and $script:Form.Visible) { Refresh-All }
    if ($script:EditMode) { Stop-AutoHide } else { Start-AutoHide }
    Write-Log ('编辑态 -> ' + $script:EditMode)
}

function Start-RowDrag {
    param($Sender)
    if ($null -eq $Sender -or $null -eq $Sender.Tag) { return }
    $script:DragEntry = $Sender.Tag.Entry
    $script:DragValid = $true
    $script:DragTargetIndex = -1
    try { $Sender.Capture = $true } catch { }
    $Sender.Cursor = [System.Windows.Forms.Cursors]::SizeNS
}

function Update-RowDrag {
    param($Sender)
    if ($null -eq $script:DragEntry -or $null -eq $script:Flow) { return }
    $pt = $script:Flow.PointToClient([System.Windows.Forms.Cursor]::Position)
    $targetRow = $null
    foreach ($c in $script:Flow.Controls) {
        if ($c -is [System.Windows.Forms.Panel] -and $c.Bounds.Contains($pt)) { $targetRow = $c; break }
    }
    if ($null -eq $targetRow) {
        $Sender.Cursor = [System.Windows.Forms.Cursors]::No
        $script:DragValid = $false
        $script:DragTargetIndex = -1
        return
    }
    $te = $null
    if ($null -ne $targetRow.PSObject.Properties['Entry']) { $te = $targetRow.Entry }
    if ($null -eq $te) {
        $Sender.Cursor = [System.Windows.Forms.Cursors]::No
        $script:DragValid = $false
        $script:DragTargetIndex = -1
        return
    }
    # Q1：跨星组不允许 —— 光标变禁止，松手回原位
    if ([int]$te.Prio -ne [int]$script:DragEntry.Prio) {
        $Sender.Cursor = [System.Windows.Forms.Cursors]::No
        $script:DragValid = $false
        $script:DragTargetIndex = -1
        $script:DragTargetPrio = [int]$te.Prio
        return
    }
    $Sender.Cursor = [System.Windows.Forms.Cursors]::SizeNS
    $script:DragValid = $true
    $idx = 0
    foreach ($c in $script:Flow.Controls) {
        if ($c -eq $targetRow) { break }
        if ($null -ne $c.PSObject.Properties['Entry'] -and [int]$c.Entry.Prio -eq [int]$script:DragEntry.Prio) { $idx++ }
    }
    $script:DragTargetIndex = $idx
}

function End-RowDrag {
    param($Sender)
    if ($null -ne $Sender) { try { $Sender.Capture = $false } catch { } }
    $entry = $script:DragEntry
    $valid = $script:DragValid
    $idx = $script:DragTargetIndex
    $script:DragEntry = $null
    $script:DragTargetIndex = -1
    if ($null -eq $entry) { return }
    if (-not $valid) {
        # 河豚 3.3 没拍到提示条：加一行日志，让「确实生效」有据可查
        Write-Log ('拖动被拒：跨星组 from=' + [int]$entry.Prio + '星 to=' + [int]$script:DragTargetPrio + '星')
        Show-Toast -Title '不能跨星组拖动' -Body '只能在同一个星级内排序；想换组请点 ⚙ 改星级'
        return
    }
    if ($idx -lt 0) { return }
    [void](Move-TodoGroupItem -ListIndex $entry.ListIndex -ItemId $entry.ItemId -TargetIndex $idx)
    Refresh-All
}

function Update-Status {
    param($State)
    Update-TrayIcon -State $State
    if ($null -eq $script:LblHeader) { return }
    $text = ('待办 · {0} 项未完成' -f $State.Pending)
    if (@($State.Lists).Count -gt 1) { $text += ('（{0} 份清单）' -f @($State.Lists).Count) }
    $script:LblHeader.Text = $text
    if ($State.Overdue -gt 0) {
        $script:LblHeader.Text += ('　逾期 {0}' -f $State.Overdue)
        $script:LblHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 40, 40)
    } else {
        $script:LblHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 30, 34, 40)
    }
    if ($null -ne $script:LblFoot) {
        $script:LblFoot.Text = ('{0} · {1}' -f $script:AppVersion, $script:Stage)
    }
}

function Refresh-All {
    try {
        Sync-ListCombo     # 0.3.12：外部加了清单，下拉跟着变
        $state = Load-State
        Update-Status -State $state
        if ($null -ne $script:Form -and $script:Form.Visible) { Build-Rows -State $state }
        $script:LastStamp = Get-DataStamp
    } catch {
        Write-Log ('刷新失败 :: ' + $_.Exception.ToString()) 'ERROR'
    }
}

function Watch-Data {
    try {
        $stamp = Get-DataStamp
        if ($stamp -ne $script:LastStamp) {
            $script:JustDone.Clear()
            [void](Update-LegacyFields)
            Refresh-All
        }
        if (((Get-Date) - $script:LastReminderCheck).TotalSeconds -ge 20) {
            $script:LastReminderCheck = Get-Date
            Invoke-Reminders
        }
    } catch {
        Write-Log ('轮询失败 :: ' + $_.Exception.Message) 'ERROR'
    }
}

function On-CheckChanged {
    param($Sender)
    $tag = $Sender.Tag
    if ($null -eq $tag) { return }
    $itemId = [string]$tag.ItemId
    $key = ('{0}|{1}' -f [int]$tag.ListIndex, $itemId)
    $want = [bool]$Sender.Checked
    $ok = Set-ItemStatus -ListIndex ([int]$tag.ListIndex) -ItemId $itemId -Done $want
    if ($ok) {
        if ($want) {
            $script:JustDone[$key] = $true
            # R14：勾完保留 5 秒（划线可见），之后从列表淡出，但数据永久保留（status=done + done_at）
            $script:DoneFadeAt[$key] = (Get-Date).AddSeconds(5)
            if ($null -ne $script:DoneFadeTimer) { $script:DoneFadeTimer.Start() }
        } else {
            $script:JustDone.Remove($key)
            $script:DoneFadeAt.Remove($key)
        }
    } else {
        $Sender.Checked = -not $want
    }
    Write-Log ('勾选事件 {0} -> {1} / 结果 {2}' -f $itemId, $want, $(if ($ok) { 'ok' } else { 'fail' }))
    $script:LastStamp = Get-DataStamp
    if ($null -ne $script:RefreshTimer) { $script:RefreshTimer.Stop(); $script:RefreshTimer.Start() }
}

#endregion

# ============================================================
#  M13 删除 · 撤销 · 编辑 —— 二次确认、真删、15 秒撤销、编辑弹窗入口
# ============================================================
#region M13 删除 · 撤销 · 编辑
# 0.3.9：确认框改用系统 MessageBox —— 自绘弹窗叠在 TopMost 面板上偶发点不到按钮，
# 日志坐实「点了删除但 Tag 没置位 → 未确认」。MessageBox 是系统模态框，不会被压住。
function Confirm-Delete {
    param([string]$Title)
    if ($null -ne $script:SelfTestConfirmResult) { return [bool]$script:SelfTestConfirmResult }   # 自检钩子
    $msg = '删除「' + $Title + '」？' + "`r`n" + '删除后 15 秒内可以点「撤销」恢复。'
    $r = [System.Windows.Forms.MessageBox]::Show(
        $script:Form, $msg, '删除待办',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning,
        [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
    Write-Log ('[DELETE] 确认框结果 ' + $r)
    return ($r -eq [System.Windows.Forms.DialogResult]::Yes)
}

# 真正执行删除（与确认/撤销解耦，自检可直接调它断言「条目真的没了 + 日志有记录」）
function Invoke-DeleteConfirmed {
    param($Entry)
    if ($null -eq $Entry) { return $false }
    $lists = @(Get-Lists)
    if ($Entry.ListIndex -lt 0 -or $Entry.ListIndex -ge $lists.Count) {
        Write-Log ('[DELETE] ListIndex 越界：' + $Entry.ListIndex + ' / 清单数 ' + $lists.Count) 'ERROR'
        return $false
    }
    $ok = Remove-TodoItem -Path $lists[$Entry.ListIndex].Path -ItemId $Entry.ItemId
    Write-Log ('删除条目 ' + $Entry.ItemId + ' / ' + $Entry.Title + ' / 结果 ' + $ok)
    if ($ok) {
        $script:JustDone.Remove(('{0}|{1}' -f $Entry.ListIndex, $Entry.ItemId))
        Refresh-All
    }
    return $ok
}

# 删除前留一份条目原文，撤销时按原字段写回
function Get-ListItemRaw {
    param([int]$ListIndex, [string]$ItemId)
    $lists = @(Get-Lists)
    if ($ListIndex -lt 0 -or $ListIndex -ge $lists.Count) { return $null }
    $doc = Read-JsonFile $lists[$ListIndex].Path
    if ($null -eq $doc) { return $null }
    return (@(Get-Prop $doc 'items' @()) | Where-Object { [string](Get-Prop $_ 'id' '') -eq $ItemId } | Select-Object -First 1)
}

function Invoke-UndoDelete {
    param([string]$Key)
    $idx = -1
    for ($i = 0; $i -lt $script:PendingDeletes.Count; $i++) {
        if ([string]$script:PendingDeletes[$i].Key -eq $Key) { $idx = $i; break }
    }
    if ($idx -lt 0) { return }
    $p = $script:PendingDeletes[$idx]
    $lists = @(Get-Lists)
    if ($p.ListIndex -ge 0 -and $p.ListIndex -lt $lists.Count -and $null -ne $p.Raw) {
        $path = $lists[$p.ListIndex].Path
        $doc = Read-JsonFile $path
        if ($null -ne $doc) {
            $items = @(Get-Prop $doc 'items' @())
            $items += $p.Raw
            Set-Prop $doc 'items' $items
            [void](Save-TodoDoc -Doc $doc -Path $path)
            Write-Log ('[DELETE] 撤销删除 ' + $p.ItemId + ' / ' + $p.Title)
        }
    }
    $script:PendingDeletes = @($script:PendingDeletes | Where-Object { [string]$_.Key -ne $Key })
    Refresh-All
}

function Invoke-DeleteEntry {
    param($Entry)
    if ($null -eq $Entry) { Write-Log '[DELETE] 空条目，忽略' 'WARN'; return }
    Write-Log ('[DELETE] 点删除 id=' + $Entry.ItemId + ' list=' + $Entry.ListIndex + ' title=' + $Entry.Title)
    try {
        if (-not (Confirm-Delete -Title ([string]$Entry.Title))) {
            Write-Log '[DELETE] 未确认，取消'
            return
        }
        $raw = Get-ListItemRaw -ListIndex ([int]$Entry.ListIndex) -ItemId ([string]$Entry.ItemId)
        $ok = Invoke-DeleteConfirmed -Entry $Entry
        Write-Log ('[DELETE] 执行结果 ' + $ok)
        if ($ok -and $null -ne $raw) {
            $key = ('{0}|{1}' -f [int]$Entry.ListIndex, [string]$Entry.ItemId)
            $script:PendingDeletes = @($script:PendingDeletes | Where-Object { [string]$_.Key -ne $key })
            $script:PendingDeletes += [pscustomobject]@{
                Key       = $key
                ListIndex = [int]$Entry.ListIndex
                ItemId    = [string]$Entry.ItemId
                Title     = [string]$Entry.Title
                Raw       = $raw
                At        = (Get-Date)
            }
            if ($null -ne $script:PendingDeleteTimer) { try { $script:PendingDeleteTimer.Start() } catch { } }
            Refresh-All
        }
    } catch {
        Write-Log ('[DELETE] 异常: ' + $_.Exception.ToString()) 'ERROR'
    }
}

function Show-EditDialog {
    param($Entry)
    if ($null -eq $Entry) { return }
    $dlg = New-AddDialog -EditEntry $Entry
    $script:SuppressDeactivate = $true
    Enter-ChildWindow
    $res = $null
    try {
        [void]$dlg.ShowDialog($script:Form)
        $res = $dlg.Tag
    } finally {
        $script:SuppressDeactivate = $false
        try { $dlg.Dispose() } catch { }
        Exit-ChildWindow
    }
    if ($res -eq 'ok') {
        $script:JustDone.Clear()
        Refresh-All
    }
}

#endregion

# ============================================================
#  M14 多清单 —— 清单下拉、新建/改名/移除、清单管理窗
# ============================================================
#region M14 多清单
# ============================================================
#  0.3.12 · 多清单：清单下拉重建 + 新建清单
#  用户 2026-11-09：①清单要能新建（原来没有入口）
#                  ②冒泡要跟主界面选中的清单走（见 Get-BubbleEntry）
# ============================================================
function Update-ListCombo {
    param([int]$ListIndex = -2)   # -2 保持当前；-1 全部清单；>=0 第 N 个清单
    if ($null -eq $script:CbList) { return }
    $lists = @(Get-Lists)
    $keep = [int]$script:FilterListIndex
    if ($ListIndex -ne -2) { $keep = $ListIndex }
    $script:SuppressListCombo = $true
    try {
        $script:CbList.Items.Clear()
        [void]$script:CbList.Items.Add('全部清单')
        foreach ($l in $lists) { [void]$script:CbList.Items.Add([string]$l.Name) }
        [void]$script:CbList.Items.Add('＋ 新建清单…')
        [void]$script:CbList.Items.Add('⚙ 清单管理…')
        $script:ListComboSig = (@($lists | ForEach-Object { [string]$_.Name }) -join '|')
        $idx = 0
        if ($keep -ge 0 -and $keep -lt $lists.Count) { $idx = $keep + 1 }
        $script:CbList.SelectedIndex = $idx
        $script:FilterListIndex = $idx - 1
    } finally {
        $script:SuppressListCombo = $false
    }
}

function Sync-ListCombo {
    # 外部改了 config（CLI / agent 加、删、改名清单）时下拉自动跟上；
    # 0.3.13 起比对「名字签名」，重名以外的任何变化都会重画，没变就不动、不打断当前选择
    if ($null -eq $script:CbList) { return }
    $lists = @(Get-Lists)
    $sig = (@($lists | ForEach-Object { [string]$_.Name }) -join '|')
    if ($sig -ne [string]$script:ListComboSig) { Update-ListCombo }
    elseif ([int]$script:FilterListIndex -ge $lists.Count) { Update-ListCombo }
}

function Add-TrayList {
    # 在 $Folder 下建 .todo\todos.json 并登记进 config.lists；成功返回 ''，失败返回中文原因。
    # 只建数据文件，不碰 AGENTS.md / .todo\AGENT.md（要 agent 协作仍走 todo.cmd init）。
    param([string]$Name, [string]$Folder)
    $Name = ([string]$Name).Trim()
    $Folder = ([string]$Folder).Trim()
    if ([string]::IsNullOrWhiteSpace($Name)) { return '清单名不能为空' }
    if ($Name.Length -gt 40) { return '清单名太长（最多 40 字）' }
    if ([string]::IsNullOrWhiteSpace($Folder)) { return '请先选一个文件夹' }
    if (-not (Test-Path -LiteralPath $Folder)) { return ('文件夹不存在：' + $Folder) }
    try { $ws = [System.IO.Path]::GetFullPath($Folder) } catch { return '文件夹路径看不懂' }
    if (-not (Test-Path -LiteralPath $ws -PathType Container)) { return '选中的不是文件夹' }
    $todoDir = Join-Path $ws '.todo'
    $todosPath = Join-Path $todoDir 'todos.json'
    $lists = @(Get-Lists)
    foreach ($l in $lists) {
        if ([string]$l.Name -eq $Name) { return ('清单名重复：' + $Name) }
        if ([string]::Equals([string]$l.Path, $todosPath, [System.StringComparison]::OrdinalIgnoreCase)) { return '这个文件夹已经是清单了' }
    }
    if (Test-Path -LiteralPath $todosPath) { return '这个文件夹下已经有 .todo\todos.json' }

    $id = 'list' + (Get-PathHash $ws)
    try {
        if (-not (Test-Path -LiteralPath $todoDir)) { New-Item -ItemType Directory -Path $todoDir -Force | Out-Null }
        $doc = [ordered]@{ version = 1; scope = $id; name = $Name; updatedAt = (Get-NowStamp); items = @() }
        Save-TextAtomic -Path $todosPath -Text ((ConvertTo-JsonText $doc) + "`n")
    } catch {
        Write-Log ('[LIST] 新建清单：建数据文件失败 ' + $todosPath + ' :: ' + $_.Exception.Message) 'ERROR'
        return '建数据文件失败，详见日志'
    }

    $cfg = Get-Config
    if ($null -eq $cfg) { $cfg = [ordered]@{ version = 1; autostart = $false } }
    $raw = @()
    $cfgNames = @($cfg.PSObject.Properties | ForEach-Object { $_.Name })
    if ($cfgNames -contains 'lists') { $raw = @($cfg.lists) }
    elseif ($cfgNames -contains 'scopes') { $raw = @($cfg.scopes) }
    $raw += [ordered]@{ id = $id; name = $Name; dir = $ws; todos = $todosPath }
    Set-Prop $cfg 'lists' @($raw)
    Set-Prop $cfg 'version' 1
    try {
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfg) + "`n")
    } catch {
        Write-Log ('[LIST] 新建清单：写配置失败 :: ' + $_.Exception.Message) 'ERROR'
        return '保存配置失败，详见日志'
    }
    Write-Log ('[LIST] 新建清单：' + $Name + ' → ' + $todosPath)
    return ''
}

function New-ListDialog {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = '新建清单'
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.ShowInTaskbar = $false
    $dlg.TopMost = $true
    $dlg.ClientSize = New-Object System.Drawing.Size(420, 196)
    $dlg.Font = $script:FontTitle
    # 控件放 script 作用域：脚本块闭包不保留函数局部变量
    $script:DlgNewListForm = $dlg
    $script:DlgNewListName = $null
    $script:DlgNewListFolder = $null
    $script:DlgNewListErr = $null

    $lbName = New-Object System.Windows.Forms.Label
    $lbName.Text = '清单名'
    $lbName.AutoSize = $false
    $lbName.Location = New-Object System.Drawing.Point(16, 18)
    $lbName.Size = New-Object System.Drawing.Size(52, 22)
    $dlg.Controls.Add($lbName)

    $tbName = New-Object System.Windows.Forms.TextBox
    $tbName.Location = New-Object System.Drawing.Point(72, 15)
    $tbName.Size = New-Object System.Drawing.Size(330, 24)
    $dlg.Controls.Add($tbName)
    $script:DlgNewListName = $tbName

    $lbFolder = New-Object System.Windows.Forms.Label
    $lbFolder.Text = '文件夹'
    $lbFolder.AutoSize = $false
    $lbFolder.Location = New-Object System.Drawing.Point(16, 58)
    $lbFolder.Size = New-Object System.Drawing.Size(52, 22)
    $dlg.Controls.Add($lbFolder)

    $tbFolder = New-Object System.Windows.Forms.TextBox
    $tbFolder.Location = New-Object System.Drawing.Point(72, 55)
    $tbFolder.Size = New-Object System.Drawing.Size(246, 24)
    $tbFolder.ReadOnly = $true
    $tbFolder.BackColor = [System.Drawing.Color]::White
    $dlg.Controls.Add($tbFolder)
    $script:DlgNewListFolder = $tbFolder

    $btnPick = New-Object System.Windows.Forms.Button
    $btnPick.Text = '选择…'
    $btnPick.Location = New-Object System.Drawing.Point(326, 54)
    $btnPick.Size = New-Object System.Drawing.Size(76, 26)
    $btnPick.Add_Click({
        $fb = New-Object System.Windows.Forms.FolderBrowserDialog
        $fb.Description = '选一个文件夹作为新清单的工作区（会在里面建 .todo\todos.json）'
        $fb.ShowNewFolderButton = $true
        try {
            $cur = [string]$script:DlgNewListFolder.Text
            if (-not [string]::IsNullOrWhiteSpace($cur) -and (Test-Path -LiteralPath $cur)) { $fb.SelectedPath = $cur }
        } catch { }
        if ($fb.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:DlgNewListFolder.Text = [string]$fb.SelectedPath
            if ([string]::IsNullOrWhiteSpace([string]$script:DlgNewListName.Text)) {
                $leaf = Split-Path -Leaf ([string]$fb.SelectedPath)
                if (-not [string]::IsNullOrWhiteSpace($leaf)) { $script:DlgNewListName.Text = $leaf }
            }
        }
    })
    $dlg.Controls.Add($btnPick)

    $lbHint = New-Object System.Windows.Forms.Label
    $lbHint.Text = '会在所选文件夹下建 .todo\todos.json（不动 AGENTS.md）'
    $lbHint.AutoSize = $false
    $lbHint.Font = $script:FontMeta
    $lbHint.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 146, 154)
    $lbHint.Location = New-Object System.Drawing.Point(72, 82)
    $lbHint.Size = New-Object System.Drawing.Size(330, 18)
    $dlg.Controls.Add($lbHint)

    $lbErr = New-Object System.Windows.Forms.Label
    $lbErr.Text = ''
    $lbErr.AutoSize = $false
    $lbErr.Font = $script:FontMeta
    $lbErr.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 40, 40)
    $lbErr.Location = New-Object System.Drawing.Point(16, 112)
    $lbErr.Size = New-Object System.Drawing.Size(388, 20)
    $dlg.Controls.Add($lbErr)
    $script:DlgNewListErr = $lbErr

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = '新建'
    $btnOk.Location = New-Object System.Drawing.Point(246, 146)
    $btnOk.Size = New-Object System.Drawing.Size(80, 28)
    $btnOk.Add_Click({
        $err = Add-TrayList -Name ([string]$script:DlgNewListName.Text) -Folder ([string]$script:DlgNewListFolder.Text)
        if (-not [string]::IsNullOrWhiteSpace($err)) { $script:DlgNewListErr.Text = $err; return }
        $script:DlgNewListForm.Tag = 'ok'
        $script:DlgNewListForm.Close()
    })
    $dlg.Controls.Add($btnOk)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = '取消'
    $btnCancel.Location = New-Object System.Drawing.Point(332, 146)
    $btnCancel.Size = New-Object System.Drawing.Size(72, 28)
    $btnCancel.Add_Click({ $script:DlgNewListForm.Close() })
    $dlg.Controls.Add($btnCancel)

    $dlg.AcceptButton = $btnOk
    $dlg.CancelButton = $btnCancel
    return $dlg
}

function Show-NewListDialog {
    if ($null -ne $script:DlgNewListForm -and -not $script:DlgNewListForm.IsDisposed) { return }   # 防重复弹
    $dlg = New-ListDialog
    $script:SuppressDeactivate = $true
    Enter-ChildWindow
    $result = $null
    try {
        if ($null -ne $script:Form) { [void]$dlg.ShowDialog($script:Form) } else { [void]$dlg.ShowDialog() }
        $result = $dlg.Tag
    } finally {
        $script:SuppressDeactivate = $false
        try { $dlg.Dispose() } catch { }
        $script:DlgNewListForm = $null
        Exit-ChildWindow
    }
    if ($result -eq 'ok') {
        $lists = @(Get-Lists)
        $target = [Math]::Max(0, $lists.Count - 1)
        Update-ListCombo -ListIndex $target
        $script:JustDone.Clear()
        Refresh-All
        Restart-BubbleSchedule
        if ($lists.Count -gt 0) { Write-Log ('[LIST] 已切到新清单：' + [string]$lists[$target].Name) }
    }
}

function Get-RawListsKey {
    # config 里清单数组的键名（lists 优先，兼容旧 scopes）；找不到返回 ''
    $cfg = Get-Config
    if ($null -eq $cfg) { return '' }
    $names = @($cfg.PSObject.Properties | ForEach-Object { $_.Name })
    if ($names -contains 'lists') { return 'lists' }
    if ($names -contains 'scopes') { return 'scopes' }
    return ''
}

function Confirm-RemoveList {
    param([string]$Name, [string]$Path)
    if ($null -ne $script:SelfTestConfirmResult) { return [bool]$script:SelfTestConfirmResult }   # 自检钩子
    $msg = '从托盘移除清单「' + $Name + '」？' + "`r`n`r`n" +
        '只是从清单下拉里去掉，数据文件保留：' + "`r`n" + $Path + "`r`n`r`n" +
        '要彻底删除请自己删这个文件。'
    $r = [System.Windows.Forms.MessageBox]::Show($script:Form, $msg, '移除清单',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning,
        [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
    Write-Log ('[LIST] 移除确认框结果 ' + $r)
    return ($r -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Rename-TrayList {
    # 改清单名：config.lists[].name + 该清单数据文件里的 name（scope/id 不动）。成功 ''，失败中文原因。
    param([string]$Id, [string]$Name)
    $Name = ([string]$Name).Trim()
    if ([string]::IsNullOrWhiteSpace($Name)) { return '清单名不能为空' }
    if ($Name.Length -gt 40) { return '清单名太长（最多 40 字）' }
    $lists = @(Get-Lists)
    $hit = @($lists | Where-Object { [string]$_.Id -eq $Id })
    if ($hit.Count -eq 0) { return '找不到这个清单' }
    foreach ($l in $lists) {
        if (([string]$l.Id -ne $Id) -and ([string]$l.Name -eq $Name)) { return ('清单名重复：' + $Name) }
    }
    $cfg = Get-Config
    $key = Get-RawListsKey
    if ($null -eq $cfg -or [string]::IsNullOrWhiteSpace($key)) { return '读不到配置里的清单' }
    $raw = @($cfg.$key)
    $newRaw = @()
    $done = $false
    foreach ($r in $raw) {
        if ($null -eq $r) { $newRaw += $r; continue }
        if ([string](Get-Prop $r 'id' '') -eq $Id) { Set-Prop $r 'name' $Name; $done = $true }
        $newRaw += $r
    }
    if (-not $done) { return '配置里找不到这个清单（id 对不上）' }
    Set-Prop $cfg $key @($newRaw)
    try {
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfg) + "`n")
    } catch {
        Write-Log ('[LIST] 改名：写配置失败 :: ' + $_.Exception.Message) 'ERROR'
        return '保存配置失败，详见日志'
    }
    # 数据文件里的 name 也同步（文件不在/读不出就跳过，不影响用）
    $docPath = [string]$hit[0].Path
    if (Test-Path -LiteralPath $docPath) {
        $doc = Read-JsonFile $docPath
        if ($null -ne $doc) {
            Set-Prop $doc 'name' $Name
            try {
                Save-TextAtomic -Path $docPath -Text ((ConvertTo-JsonText $doc) + "`n")
            } catch {
                Write-Log ('[LIST] 改名：数据文件 name 没写进去 :: ' + $_.Exception.Message) 'WARN'
            }
        }
    }
    Write-Log ('[LIST] 改名：' + $Id + ' → ' + $Name)
    return ''
}

function Remove-TrayList {
    # 只从 config.lists 移除（数据文件原地保留）。成功 ''，失败中文原因。
    param([string]$Id)
    $lists = @(Get-Lists)
    if ($lists.Count -le 1) { return '至少保留一个清单' }
    $hit = @($lists | Where-Object { [string]$_.Id -eq $Id })
    if ($hit.Count -eq 0) { return '找不到这个清单' }
    $cfg = Get-Config
    $key = Get-RawListsKey
    if ($null -eq $cfg -or [string]::IsNullOrWhiteSpace($key)) { return '读不到配置里的清单' }
    $raw = @($cfg.$key)
    $newRaw = @()
    $removed = 0
    foreach ($r in $raw) {
        if ($null -ne $r -and [string](Get-Prop $r 'id' '') -eq $Id) { $removed++; continue }
        $newRaw += $r
    }
    if ($removed -eq 0) { return '配置里找不到这个清单（id 对不上）' }
    if ($newRaw.Count -eq 0) { return '至少保留一个清单' }
    Set-Prop $cfg $key @($newRaw)
    try {
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfg) + "`n")
    } catch {
        Write-Log ('[LIST] 移除：写配置失败 :: ' + $_.Exception.Message) 'ERROR'
        return '保存配置失败，详见日志'
    }
    Write-Log ('[LIST] 移除：' + [string]$hit[0].Name + '（数据文件保留：' + [string]$hit[0].Path + '）')
    return ''
}

function Update-ListManagerList {
    param([int]$KeepIndex = 0)
    if ($null -eq $script:DlgMgrList) { return }
    $lists = @(Get-Lists)
    $script:DlgMgrList.Items.Clear()
    foreach ($l in $lists) { [void]$script:DlgMgrList.Items.Add([string]$l.Name) }
    if ($lists.Count -eq 0) { return }
    if ($KeepIndex -lt 0) { $KeepIndex = 0 }
    if ($KeepIndex -ge $lists.Count) { $KeepIndex = $lists.Count - 1 }
    $script:DlgMgrList.SelectedIndex = $KeepIndex
}

function New-ListManagerDialog {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = '清单管理'
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.ShowInTaskbar = $false
    $dlg.TopMost = $true
    $dlg.ClientSize = New-Object System.Drawing.Size(420, 316)
    $dlg.Font = $script:FontTitle
    $script:DlgMgrForm = $dlg
    $script:DlgMgrList = $null
    $script:DlgMgrName = $null
    $script:DlgMgrPath = $null
    $script:DlgMgrErr = $null

    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Location = New-Object System.Drawing.Point(16, 14)
    $lb.Size = New-Object System.Drawing.Size(388, 140)
    $lb.Font = $script:FontTitle
    $dlg.Controls.Add($lb)
    $script:DlgMgrList = $lb

    $lbPath = New-Object System.Windows.Forms.Label
    $lbPath.Text = ''
    $lbPath.AutoSize = $false
    $lbPath.Font = $script:FontMeta
    $lbPath.ForeColor = [System.Drawing.Color]::FromArgb(255, 120, 126, 134)
    $lbPath.Location = New-Object System.Drawing.Point(16, 158)
    $lbPath.Size = New-Object System.Drawing.Size(388, 18)
    $dlg.Controls.Add($lbPath)
    $script:DlgMgrPath = $lbPath

    $lbName = New-Object System.Windows.Forms.Label
    $lbName.Text = '名称'
    $lbName.AutoSize = $false
    $lbName.Location = New-Object System.Drawing.Point(16, 190)
    $lbName.Size = New-Object System.Drawing.Size(52, 22)
    $dlg.Controls.Add($lbName)

    $tbName = New-Object System.Windows.Forms.TextBox
    $tbName.Location = New-Object System.Drawing.Point(72, 187)
    $tbName.Size = New-Object System.Drawing.Size(240, 24)
    $dlg.Controls.Add($tbName)
    $script:DlgMgrName = $tbName

    $btnRename = New-Object System.Windows.Forms.Button
    $btnRename.Text = '改名'
    $btnRename.Location = New-Object System.Drawing.Point(320, 186)
    $btnRename.Size = New-Object System.Drawing.Size(84, 26)
    $btnRename.Add_Click({
        $i = [int]$script:DlgMgrList.SelectedIndex
        $listsNow = @(Get-Lists)
        if ($i -lt 0 -or $i -ge $listsNow.Count) { return }
        $err = Rename-TrayList -Id ([string]$listsNow[$i].Id) -Name ([string]$script:DlgMgrName.Text)
        if (-not [string]::IsNullOrWhiteSpace($err)) { $script:DlgMgrErr.Text = $err; return }
        $script:DlgMgrErr.Text = ''
        Update-ListManagerList -KeepIndex $i
        Update-ListCombo
        Refresh-All
    })
    $dlg.Controls.Add($btnRename)

    $lbHint = New-Object System.Windows.Forms.Label
    $lbHint.Text = '「移除」只是从托盘清单下拉里去掉，数据文件保留（想删自己删）'
    $lbHint.AutoSize = $false
    $lbHint.Font = $script:FontMeta
    $lbHint.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 146, 154)
    $lbHint.Location = New-Object System.Drawing.Point(16, 222)
    $lbHint.Size = New-Object System.Drawing.Size(388, 18)
    $dlg.Controls.Add($lbHint)

    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Text = '移除'
    $btnRemove.Location = New-Object System.Drawing.Point(16, 248)
    $btnRemove.Size = New-Object System.Drawing.Size(96, 28)
    $btnRemove.Add_Click({
        $i = [int]$script:DlgMgrList.SelectedIndex
        $listsNow = @(Get-Lists)
        if ($i -lt 0 -or $i -ge $listsNow.Count) { return }
        $target = $listsNow[$i]
        if (-not (Confirm-RemoveList -Name ([string]$target.Name) -Path ([string]$target.Path))) { return }
        $err = Remove-TrayList -Id ([string]$target.Id)
        if (-not [string]::IsNullOrWhiteSpace($err)) { $script:DlgMgrErr.Text = $err; return }
        $script:DlgMgrErr.Text = ''
        $after = @(Get-Lists)
        $sel = [int]$script:FilterListIndex
        if ($sel -eq $i) { $sel = -1 }
        elseif ($sel -gt $i) { $sel = $sel - 1 }
        if ($sel -ge $after.Count) { $sel = -1 }
        $keep = $i
        if ($keep -ge $after.Count) { $keep = $after.Count - 1 }
        if ($keep -lt 0) { $keep = 0 }
        Update-ListManagerList -KeepIndex $keep
        Update-ListCombo -ListIndex $sel
        $script:JustDone.Clear()
        Refresh-All
        Restart-BubbleSchedule
    })
    $dlg.Controls.Add($btnRemove)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = '关闭'
    $btnClose.Location = New-Object System.Drawing.Point(320, 248)
    $btnClose.Size = New-Object System.Drawing.Size(84, 28)
    $btnClose.Add_Click({ $script:DlgMgrForm.Close() })
    $dlg.Controls.Add($btnClose)

    $lbErr = New-Object System.Windows.Forms.Label
    $lbErr.Text = ''
    $lbErr.AutoSize = $false
    $lbErr.Font = $script:FontMeta
    $lbErr.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 40, 40)
    $lbErr.Location = New-Object System.Drawing.Point(120, 252)
    $lbErr.Size = New-Object System.Drawing.Size(196, 20)
    $dlg.Controls.Add($lbErr)
    $script:DlgMgrErr = $lbErr

    $lb.Add_SelectedIndexChanged({
        $i = [int]$script:DlgMgrList.SelectedIndex
        $listsNow = @(Get-Lists)
        if ($i -lt 0 -or $i -ge $listsNow.Count) { return }
        $script:DlgMgrName.Text = [string]$listsNow[$i].Name
        $script:DlgMgrPath.Text = '数据文件：' + [string]$listsNow[$i].Path
        $script:DlgMgrErr.Text = ''
    })

    $dlg.CancelButton = $btnClose
    Update-ListManagerList -KeepIndex 0
    return $dlg
}

function Show-ListManager {
    if ($null -ne $script:DlgMgrForm -and -not $script:DlgMgrForm.IsDisposed) { return }   # 防重复弹
    $dlg = New-ListManagerDialog
    $script:SuppressDeactivate = $true
    Enter-ChildWindow
    try {
        if ($null -ne $script:Form) { [void]$dlg.ShowDialog($script:Form) } else { [void]$dlg.ShowDialog() }
    } finally {
        $script:SuppressDeactivate = $false
        try { $dlg.Dispose() } catch { }
        $script:DlgMgrForm = $null
        Exit-ChildWindow
    }
}

#endregion

# ============================================================
#  M15 弹窗 · 设置 · 导出 · 提醒 —— 新增窗、设置窗、导出菜单、Toast、到期提醒
# ============================================================
#region M15 弹窗 · 设置 · 导出 · 提醒
function New-AddDialog {
    param($EditEntry = $null)
    $isEdit = ($null -ne $EditEntry)
    $lists = @(Get-Lists)
    $dlg = New-Object System.Windows.Forms.Form
    if ($isEdit) { $dlg.Text = '编辑待办' } else { $dlg.Text = '新增待办' }
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.ShowInTaskbar = $false
    $dlg.TopMost = $true
    $dlg.ClientSize = New-Object System.Drawing.Size(400, 274)
    $dlg.Font = $script:FontTitle
    # 控件放到 script 作用域：脚本块闭包不保留函数局部变量，靠局部变量点「确定」会炸
    $script:DlgForm = $dlg
    $script:DlgList = $null
    $script:DlgEditEntry = $EditEntry

    $lb1 = New-Object System.Windows.Forms.Label
    $lb1.Text = '标题'
    $lb1.AutoSize = $false
    $lb1.Location = New-Object System.Drawing.Point(16, 18)
    $lb1.Size = New-Object System.Drawing.Size(46, 22)
    $dlg.Controls.Add($lb1)

    $tbTitle = New-Object System.Windows.Forms.TextBox
    $tbTitle.Location = New-Object System.Drawing.Point(66, 15)
    $tbTitle.Size = New-Object System.Drawing.Size(310, 24)
    if ($isEdit) { $tbTitle.Text = [string]$EditEntry.Title }
    $dlg.Controls.Add($tbTitle)
    $script:DlgTitle = $tbTitle

    $lb2 = New-Object System.Windows.Forms.Label
    $lb2.Text = '到期'
    $lb2.AutoSize = $false
    $lb2.Location = New-Object System.Drawing.Point(16, 56)
    $lb2.Size = New-Object System.Drawing.Size(46, 22)
    $dlg.Controls.Add($lb2)

    $tbDue = New-Object System.Windows.Forms.TextBox
    $tbDue.Location = New-Object System.Drawing.Point(66, 53)
    $tbDue.Size = New-Object System.Drawing.Size(310, 24)
    $tbDue.ImeMode = [System.Windows.Forms.ImeMode]::Disable
    if ($isEdit) { $tbDue.Text = [string]$EditEntry.DueText }
    $dlg.Controls.Add($tbDue)
    $script:DlgDue = $tbDue

    $lbHint = New-Object System.Windows.Forms.Label
    $lbHint.Text = '可留空。例：2026-10-28 21:00 或 10-28 21:00'
    $lbHint.AutoSize = $false
    $lbHint.Font = $script:FontMeta
    $lbHint.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 146, 154)
    $lbHint.Location = New-Object System.Drawing.Point(66, 80)
    $lbHint.Size = New-Object System.Drawing.Size(310, 18)
    $dlg.Controls.Add($lbHint)

    # --- R5/R6 紧急程度（星星只在弹窗里出现）---
    $lbPrio = New-Object System.Windows.Forms.Label
    $lbPrio.Text = '紧急'
    $lbPrio.AutoSize = $false
    $lbPrio.Location = New-Object System.Drawing.Point(16, 110)
    $lbPrio.Size = New-Object System.Drawing.Size(46, 22)
    $dlg.Controls.Add($lbPrio)

    $rbPrio1 = New-Object System.Windows.Forms.RadioButton
    $rbPrio1.Text = '1★ 默认'
    $rbPrio1.AutoSize = $false
    $rbPrio1.Location = New-Object System.Drawing.Point(66, 106)
    $rbPrio1.Size = New-Object System.Drawing.Size(82, 22)
    $rbPrio1.Checked = $true
    $dlg.Controls.Add($rbPrio1)
    $script:DlgPrio1 = $rbPrio1

    $rbPrio2 = New-Object System.Windows.Forms.RadioButton
    $rbPrio2.Text = '2★ 黄'
    $rbPrio2.AutoSize = $false
    $rbPrio2.Location = New-Object System.Drawing.Point(154, 106)
    $rbPrio2.Size = New-Object System.Drawing.Size(78, 22)
    $dlg.Controls.Add($rbPrio2)
    $script:DlgPrio2 = $rbPrio2

    $rbPrio3 = New-Object System.Windows.Forms.RadioButton
    $rbPrio3.Text = '3★ 红'
    $rbPrio3.AutoSize = $false
    $rbPrio3.Location = New-Object System.Drawing.Point(238, 106)
    $rbPrio3.Size = New-Object System.Drawing.Size(78, 22)
    $dlg.Controls.Add($rbPrio3)
    $script:DlgPrio3 = $rbPrio3

    # 名额满了就置灰 + 黄字给原因（Q2：不允许超限）
    $usage = Get-PrioUsage
    if ($isEdit -and [string]$EditEntry.Status -ne 'done') {
        # 编辑自己时先把它占的名额还回去，否则「改成原星级」也会被判满
        $oldP = [int]$EditEntry.Prio
        if ($oldP -ge 1 -and $oldP -le 3) { $usage[$oldP] = [Math]::Max(0, [int]$usage[$oldP] - 1) }
    }
    $quotaNotes = @()
    if ([int]$usage[3] -ge 1) {
        $rbPrio3.Enabled = $false
        $quotaNotes += '3★ 只能 1 个'
    }
    if ([int]$usage[2] -ge 2) {
        $rbPrio2.Enabled = $false
        $quotaNotes += '2★ 最多 2 个'
    }
    $quotaText = ''
    if ($quotaNotes.Count -gt 0) { $quotaText = ($quotaNotes -join '；') + '，请先取消现有的' }
    $lbQuota = New-Object System.Windows.Forms.Label
    $lbQuota.Text = $quotaText
    $lbQuota.AutoSize = $false
    $lbQuota.Font = $script:FontMeta
    $lbQuota.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 110, 0)
    $lbQuota.Location = New-Object System.Drawing.Point(16, 132)
    $lbQuota.Size = New-Object System.Drawing.Size(368, 18)
    $dlg.Controls.Add($lbQuota)

    if ($isEdit) {
        $want = [int]$EditEntry.Prio
        if ($want -eq 3 -and $rbPrio3.Enabled) { $rbPrio3.Checked = $true }
        elseif ($want -eq 2 -and $rbPrio2.Enabled) { $rbPrio2.Checked = $true }
        else { $rbPrio1.Checked = $true }
    }

    $cbList = $null
    $y = 166
    if ($lists.Count -gt 1) {
        $lb3 = New-Object System.Windows.Forms.Label
        $lb3.Text = '清单'
        $lb3.AutoSize = $false
        $lb3.Location = New-Object System.Drawing.Point(16, 166)
        $lb3.Size = New-Object System.Drawing.Size(46, 22)
        $dlg.Controls.Add($lb3)

        $cbList = New-Object System.Windows.Forms.ComboBox
        $cbList.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $cbList.Location = New-Object System.Drawing.Point(66, 163)
        $cbList.Size = New-Object System.Drawing.Size(310, 24)
        foreach ($l in $lists) { [void]$cbList.Items.Add($l.Name) }
        $idx0 = 0
        if ([int]$script:FilterListIndex -ge 0 -and [int]$script:FilterListIndex -lt $lists.Count) { $idx0 = [int]$script:FilterListIndex }
        if ($isEdit) { $idx0 = [Math]::Max(0, [Math]::Min([int]$EditEntry.ListIndex, $lists.Count - 1)) }
        $cbList.SelectedIndex = $idx0
        if ($isEdit) { $cbList.Enabled = $false }   # M3：编辑只改标题/到期/星级，不搬清单
        $dlg.Controls.Add($cbList)
        $script:DlgList = $cbList
        $y = 202
    }

    $lbErr = New-Object System.Windows.Forms.Label
    $lbErr.Text = ''
    $lbErr.AutoSize = $false
    $lbErr.Font = $script:FontMeta
    $lbErr.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 40, 40)
    $lbErr.Location = New-Object System.Drawing.Point(16, ($y + 2))
    $lbErr.Size = New-Object System.Drawing.Size(360, 20)
    $dlg.Controls.Add($lbErr)
    $script:DlgErr = $lbErr

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = '确定'
    $btnOk.Location = New-Object System.Drawing.Point(212, ($y + 28))
    $btnOk.Size = New-Object System.Drawing.Size(78, 28)
    $btnOk.Add_Click({
        if ([string]::IsNullOrWhiteSpace($script:DlgTitle.Text)) { $script:DlgErr.Text = '标题不能为空'; return }
        $due = $script:DlgDue.Text.Trim()
        if ($due -ne '') {
            $dd = ConvertTo-DateOrNull $due
            if ($null -eq $dd) { $script:DlgErr.Text = '到期时间看不懂，例：2026-10-28 21:00'; return }
            $due = $dd.ToString('yyyy-MM-dd HH:mm')
        }
        $target = 0
        if ($null -ne $script:DlgList) { $target = [int]$script:DlgList.SelectedIndex }
        # R6：保存时再判一次名额，防止 UI 被绕过
        $prio = 1
        if ($null -ne $script:DlgPrio3 -and $script:DlgPrio3.Checked) { $prio = 3 }
        elseif ($null -ne $script:DlgPrio2 -and $script:DlgPrio2.Checked) { $prio = 2 }
        $editEntry = $script:DlgEditEntry
        if ($null -ne $editEntry) {
            # 编辑：由 Update-TodoItem 内部按「排除自己」判名额
            $okAdd = Update-TodoItem -ListIndex ([int]$editEntry.ListIndex) -ItemId ([string]$editEntry.ItemId) -Title $script:DlgTitle.Text -DueText $due -Prio $prio
            if (-not $okAdd) { $script:DlgErr.Text = '保存失败（可能名额已满，详见日志）'; return }
        } else {
            $usage = Get-PrioUsage
            if ($prio -eq 3 -and [int]$usage[3] -ge 1) { $script:DlgErr.Text = '3★ 名额已满，请先取消现有的'; return }
            if ($prio -eq 2 -and [int]$usage[2] -ge 2) { $script:DlgErr.Text = '2★ 名额已满，请先取消现有的'; return }
            $okAdd = Add-TodoItem -ListIndex $target -Title $script:DlgTitle.Text -DueText $due -Prio $prio
            if (-not $okAdd) { $script:DlgErr.Text = '写入失败，详见 todo-tray.log'; return }
        }
        $script:DlgForm.Tag = 'ok'
        $script:DlgForm.Close()
    })
    $dlg.Controls.Add($btnOk)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = '取消'
    $btnCancel.Location = New-Object System.Drawing.Point(300, ($y + 28))
    $btnCancel.Size = New-Object System.Drawing.Size(76, 28)
    $btnCancel.Add_Click({ $script:DlgForm.Close() })
    $dlg.Controls.Add($btnCancel)

    $dlg.AcceptButton = $btnOk
    $dlg.CancelButton = $btnCancel
    return $dlg
}

function Show-AddDialog {
    if ($null -eq $script:Form) { return }
    $dlg = New-AddDialog
    $script:SuppressDeactivate = $true
    Enter-ChildWindow
    $result = $null
    try {
        [void]$dlg.ShowDialog($script:Form)
        $result = $dlg.Tag
    } finally {
        $script:SuppressDeactivate = $false
        try { $dlg.Dispose() } catch { }
        Exit-ChildWindow
    }
    if ($result -eq 'ok') {
        $script:JustDone.Clear()
        Refresh-All
    }
}

# ============================================================
#  0.2.0 · R3 设置窗（显示 / 行为 / 数据）
#  打开时暂停自动隐藏；点「关闭」保存并立即生效。
# ============================================================
function New-SettingsDialog {
    if ($null -eq $script:UiSettings) { $script:UiSettings = Get-UiSettings }
    $ui = $script:UiSettings

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = '设置'
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.ShowInTaskbar = $false
    $dlg.TopMost = $true
    $dlg.ClientSize = New-Object System.Drawing.Size(420, 494)
    $dlg.Font = $script:FontTitle
    $script:SettingsForm = $dlg

    $lbShow = New-Object System.Windows.Forms.Label
    $lbShow.Text = '显示'
    $lbShow.AutoSize = $false
    $lbShow.Font = $script:FontHead
    $lbShow.Location = New-Object System.Drawing.Point(16, 10)
    $lbShow.Size = New-Object System.Drawing.Size(80, 22)
    $dlg.Controls.Add($lbShow)

    $rbAlways = New-Object System.Windows.Forms.RadioButton
    $rbAlways.Text = '常驻悬浮（固定右上角、置顶、不自动隐藏）'
    $rbAlways.AutoSize = $false
    $rbAlways.Location = New-Object System.Drawing.Point(28, 38)
    $rbAlways.Size = New-Object System.Drawing.Size(370, 22)
    $rbAlways.Checked = ($ui.Mode -eq 'always')
    $dlg.Controls.Add($rbAlways)
    $script:SetModeAlways = $rbAlways

    $rbAuto = New-Object System.Windows.Forms.RadioButton
    $rbAuto.Text = 'N 秒后自动隐藏'
    $rbAuto.AutoSize = $false
    $rbAuto.Location = New-Object System.Drawing.Point(28, 64)
    $rbAuto.Size = New-Object System.Drawing.Size(180, 22)
    $rbAuto.Checked = ($ui.Mode -eq 'auto')
    $dlg.Controls.Add($rbAuto)
    $script:SetModeAuto = $rbAuto

    $lbHide = New-Object System.Windows.Forms.Label
    $lbHide.Text = '隐藏时间'
    $lbHide.AutoSize = $false
    $lbHide.Location = New-Object System.Drawing.Point(28, 100)
    $lbHide.Size = New-Object System.Drawing.Size(70, 20)
    $dlg.Controls.Add($lbHide)

    $cbHide = New-Object System.Windows.Forms.ComboBox
    $cbHide.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cbHide.Location = New-Object System.Drawing.Point(104, 96)
    $cbHide.Size = New-Object System.Drawing.Size(96, 24)
    foreach ($n in 5, 15, 30, 60) { [void]$cbHide.Items.Add(('{0} 秒' -f $n)) }
    $selIdx = 1
    switch ([int]$ui.HideSeconds) { 5 { $selIdx = 0 } 15 { $selIdx = 1 } 30 { $selIdx = 2 } 60 { $selIdx = 3 } }
    $cbHide.SelectedIndex = $selIdx
    $cbHide.Enabled = ($ui.Mode -eq 'auto')
    $dlg.Controls.Add($cbHide)
    $script:SetHide = $cbHide

    # 0.3.0 · M7：小鲸鱼展开后自动收回（0 = 只手动收）
    if ($null -eq $script:WinCfg) { $script:WinCfg = Get-WindowSettings }
    $lbPeek = New-Object System.Windows.Forms.Label
    $lbPeek.Text = '侧边收回'
    $lbPeek.AutoSize = $false
    $lbPeek.Location = New-Object System.Drawing.Point(212, 100)
    $lbPeek.Size = New-Object System.Drawing.Size(84, 20)
    $dlg.Controls.Add($lbPeek)

    $cbPeek = New-Object System.Windows.Forms.ComboBox
    $cbPeek.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cbPeek.Location = New-Object System.Drawing.Point(300, 96)
    $cbPeek.Size = New-Object System.Drawing.Size(104, 24)
    [void]$cbPeek.Items.Add('0 秒（只手动）')
    [void]$cbPeek.Items.Add('3 秒')
    [void]$cbPeek.Items.Add('10 秒')
    $peekIdx = 1
    switch ([int]$script:WinCfg.AutoCollapseSeconds) { 0 { $peekIdx = 0 } 3 { $peekIdx = 1 } 10 { $peekIdx = 2 } }
    $cbPeek.SelectedIndex = $peekIdx
    $dlg.Controls.Add($cbPeek)
    $script:SetPeek = $cbPeek

    $lbOp = New-Object System.Windows.Forms.Label
    $lbOp.Text = '透明度'
    $lbOp.AutoSize = $false
    $lbOp.Location = New-Object System.Drawing.Point(28, 142)
    $lbOp.Size = New-Object System.Drawing.Size(62, 20)
    $dlg.Controls.Add($lbOp)

    $tbOp = New-Object System.Windows.Forms.TrackBar
    $tbOp.Minimum = 30
    $tbOp.Maximum = 100
    $tbOp.SmallChange = 1
    $tbOp.LargeChange = 5
    $tbOp.TickStyle = [System.Windows.Forms.TickStyle]::None
    $tbOp.Location = New-Object System.Drawing.Point(96, 132)
    $tbOp.Size = New-Object System.Drawing.Size(230, 42)
    $tbOp.Value = [Math]::Max(30, [Math]::Min(100, [int]$ui.Opacity))
    $dlg.Controls.Add($tbOp)
    $script:SetOpacity = $tbOp

    $lbOpVal = New-Object System.Windows.Forms.Label
    $lbOpVal.Text = ('{0}%' -f $tbOp.Value)
    $lbOpVal.AutoSize = $false
    $lbOpVal.Location = New-Object System.Drawing.Point(330, 140)
    $lbOpVal.Size = New-Object System.Drawing.Size(56, 20)
    $dlg.Controls.Add($lbOpVal)
    $script:SetOpacityLbl = $lbOpVal

    $cbTop = New-Object System.Windows.Forms.CheckBox
    $cbTop.Text = '置顶：浮在所有窗口之上'
    $cbTop.AutoSize = $false
    $cbTop.Location = New-Object System.Drawing.Point(28, 186)
    $cbTop.Size = New-Object System.Drawing.Size(330, 22)
    $cbTop.Checked = [bool]$ui.TopMost
    $dlg.Controls.Add($cbTop)
    $script:SetTop = $cbTop

    $line1 = New-Object System.Windows.Forms.Panel
    $line1.BackColor = [System.Drawing.Color]::FromArgb(255, 232, 235, 240)
    $line1.Location = New-Object System.Drawing.Point(0, 216)
    $line1.Size = New-Object System.Drawing.Size(420, 1)
    $dlg.Controls.Add($line1)

    $lbBeh = New-Object System.Windows.Forms.Label
    $lbBeh.Text = '行为'
    $lbBeh.AutoSize = $false
    $lbBeh.Font = $script:FontHead
    $lbBeh.Location = New-Object System.Drawing.Point(16, 222)
    $lbBeh.Size = New-Object System.Drawing.Size(80, 22)
    $dlg.Controls.Add($lbBeh)

    $cbClose = New-Object System.Windows.Forms.CheckBox
    $cbClose.Text = '点 × 只收界面，托盘继续（固定行为）'
    $cbClose.AutoSize = $false
    $cbClose.Location = New-Object System.Drawing.Point(28, 248)
    $cbClose.Size = New-Object System.Drawing.Size(350, 22)
    $cbClose.Checked = $true
    $cbClose.Enabled = $false
    $dlg.Controls.Add($cbClose)

    $cbAutostart = New-Object System.Windows.Forms.CheckBox
    $cbAutostart.Text = '开机自启（默认开，只写启动文件夹，不碰注册表）'
    $cbAutostart.AutoSize = $false
    $cbAutostart.Location = New-Object System.Drawing.Point(28, 274)
    $cbAutostart.Size = New-Object System.Drawing.Size(370, 22)
    $cbAutostart.Checked = (Test-Autostart)
    $dlg.Controls.Add($cbAutostart)
    $script:SetAutostart = $cbAutostart

    # ---------- 0.3.11 · 小鲸鱼冒泡 ----------
    $lineB = New-Object System.Windows.Forms.Panel
    $lineB.BackColor = [System.Drawing.Color]::FromArgb(255, 232, 235, 240)
    $lineB.Location = New-Object System.Drawing.Point(0, 304)
    $lineB.Size = New-Object System.Drawing.Size(420, 1)
    $dlg.Controls.Add($lineB)

    $lbBub = New-Object System.Windows.Forms.Label
    $lbBub.Text = '小鲸鱼冒泡'
    $lbBub.AutoSize = $false
    $lbBub.Font = $script:FontHead
    $lbBub.Location = New-Object System.Drawing.Point(16, 310)
    $lbBub.Size = New-Object System.Drawing.Size(120, 22)
    $dlg.Controls.Add($lbBub)

    $cbBub = New-Object System.Windows.Forms.CheckBox
    $cbBub.Text = '冒泡提醒（显示待办标题）'
    $cbBub.AutoSize = $false
    $cbBub.Location = New-Object System.Drawing.Point(28, 336)
    $cbBub.Size = New-Object System.Drawing.Size(330, 22)
    $cbBub.Checked = [bool]$ui.BubbleEnabled
    $dlg.Controls.Add($cbBub)
    $script:SetBubble = $cbBub

    $lbBubMax = New-Object System.Windows.Forms.Label
    $lbBubMax.Text = '最长间隔'
    $lbBubMax.AutoSize = $false
    $lbBubMax.Location = New-Object System.Drawing.Point(28, 368)
    $lbBubMax.Size = New-Object System.Drawing.Size(70, 20)
    $dlg.Controls.Add($lbBubMax)

    $cbBubMax = New-Object System.Windows.Forms.ComboBox
    $cbBubMax.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cbBubMax.Location = New-Object System.Drawing.Point(104, 364)
    $cbBubMax.Size = New-Object System.Drawing.Size(96, 24)
    foreach ($n in 15, 30, 45, 60) { [void]$cbBubMax.Items.Add(('{0} 秒' -f $n)) }
    $bubIdx = 3
    switch ([int]$ui.BubbleMaxSeconds) { 15 { $bubIdx = 0 } 30 { $bubIdx = 1 } 45 { $bubIdx = 2 } 60 { $bubIdx = 3 } }
    $cbBubMax.SelectedIndex = $bubIdx
    $cbBubMax.Enabled = [bool]$ui.BubbleEnabled
    $dlg.Controls.Add($cbBubMax)
    $script:SetBubbleMax = $cbBubMax

    $lbBubTip = New-Object System.Windows.Forms.Label
    $lbBubTip.Text = '随机间隔冒一个，每个 6 秒'
    $lbBubTip.AutoSize = $false
    $lbBubTip.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 146, 154)
    $lbBubTip.Location = New-Object System.Drawing.Point(212, 368)
    $lbBubTip.Size = New-Object System.Drawing.Size(190, 20)
    $dlg.Controls.Add($lbBubTip)

    $line2 = New-Object System.Windows.Forms.Panel
    $line2.BackColor = [System.Drawing.Color]::FromArgb(255, 232, 235, 240)
    $line2.Location = New-Object System.Drawing.Point(0, 386)
    $line2.Size = New-Object System.Drawing.Size(420, 1)
    $dlg.Controls.Add($line2)

    $lbData = New-Object System.Windows.Forms.Label
    $lbData.Text = '数据'
    $lbData.AutoSize = $false
    $lbData.Font = $script:FontHead
    $lbData.Location = New-Object System.Drawing.Point(16, 392)
    $lbData.Size = New-Object System.Drawing.Size(80, 22)
    $dlg.Controls.Add($lbData)

    $lnkFolder = New-Object System.Windows.Forms.LinkLabel
    $lnkFolder.Text = '打开数据文件夹'
    $lnkFolder.AutoSize = $false
    $lnkFolder.Location = New-Object System.Drawing.Point(28, 418)
    $lnkFolder.Size = New-Object System.Drawing.Size(150, 20)
    $lnkFolder.LinkColor = [System.Drawing.Color]::FromArgb(255, 60, 120, 200)
    $lnkFolder.Add_LinkClicked({
        try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $script:BaseDir) } catch { }
    })
    $dlg.Controls.Add($lnkFolder)

    # 0.3.27：悬停进交互时间（毫秒，临时可调）
    $lbHover = New-Object System.Windows.Forms.Label
    $lbHover.Text = '悬停进交互'
    $lbHover.AutoSize = $false
    $lbHover.Location = New-Object System.Drawing.Point(184, 420)
    $lbHover.Size = New-Object System.Drawing.Size(80, 20)
    $dlg.Controls.Add($lbHover)

    $tbHover = New-Object System.Windows.Forms.TextBox
    $tbHover.Location = New-Object System.Drawing.Point(266, 416)
    $tbHover.Size = New-Object System.Drawing.Size(64, 24)
    $tbHover.Text = [string]([int]$ui.HoverMs)
    $tbHover.ImeMode = [System.Windows.Forms.ImeMode]::Disable
    $dlg.Controls.Add($tbHover)
    $script:SetHoverMs = $tbHover

    $lbHoverMs = New-Object System.Windows.Forms.Label
    $lbHoverMs.Text = '毫秒'
    $lbHoverMs.AutoSize = $false
    $lbHoverMs.Location = New-Object System.Drawing.Point(334, 420)
    $lbHoverMs.Size = New-Object System.Drawing.Size(40, 20)
    $dlg.Controls.Add($lbHoverMs)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = '关闭'
    $btnClose.Location = New-Object System.Drawing.Point(322, 452)
    $btnClose.Size = New-Object System.Drawing.Size(80, 28)
    $btnClose.Add_Click({
        $mode = 'auto'
        if ($null -ne $script:SetModeAlways -and $script:SetModeAlways.Checked) { $mode = 'always' }
        $hs = 15
        try { $hs = [int](([string]$script:SetHide.SelectedItem) -replace '[^0-9]', '') } catch { }
        if (@(5, 15, 30, 60) -notcontains $hs) { $hs = 15 }
        $op = 100
        if ($null -ne $script:SetOpacity) { $op = [int]$script:SetOpacity.Value }
        if ($op -lt 30) { $op = 30 }
        if ($op -gt 100) { $op = 100 }
        $top = $true
        if ($null -ne $script:SetTop) { $top = [bool]$script:SetTop.Checked }
        $wantAuto = $false
        if ($null -ne $script:SetAutostart) { $wantAuto = [bool]$script:SetAutostart.Checked }
        if ($wantAuto -ne (Test-Autostart)) { [void](Set-Autostart -On $wantAuto) }
        # 0.3.11：冒泡开关 + 最长间隔
        $bubOn = $true
        if ($null -ne $script:SetBubble) { $bubOn = [bool]$script:SetBubble.Checked }
        $bubMax = 60
        if ($null -ne $script:SetBubbleMax -and $script:SetBubbleMax.SelectedIndex -ge 0) {
            $bubMax = @(15, 30, 45, 60)[[int]$script:SetBubbleMax.SelectedIndex]
        }
        $hoverMs = 1500
        if ($null -ne $script:SetHoverMs) {
            try { $hoverMs = [int]([string]$script:SetHoverMs.Text).Trim() } catch { $hoverMs = 1500 }
        }
        if ($hoverMs -lt 200) { $hoverMs = 200 }
        if ($hoverMs -gt 5000) { $hoverMs = 5000 }
        $okSave = Save-UiSettings -Settings ([pscustomobject]@{
            Mode = $mode; HideSeconds = $hs; Opacity = $op; TopMost = $top
            BubbleEnabled = $bubOn; BubbleMaxSeconds = $bubMax
            HoverMs = $hoverMs
        })
        # 0.3.0 · M7：侧边收回秒数存在 ui.window 里
        if ($null -ne $script:SetPeek -and $script:SetPeek.SelectedIndex -ge 0) {
            $acs = @(0, 3, 10)[[int]$script:SetPeek.SelectedIndex]
            if ($null -eq $script:WinCfg) { $script:WinCfg = Get-WindowSettings }
            if ([int]$script:WinCfg.AutoCollapseSeconds -ne [int]$acs) {
                $script:WinCfg.AutoCollapseSeconds = [int]$acs
                [void](Save-WindowSettings -Settings $script:WinCfg)
            }
        }
        if ($okSave -and $null -ne $script:SettingsForm) { $script:SettingsForm.Tag = 'ok' }
        if ($null -ne $script:SettingsForm) { $script:SettingsForm.Close() }
    })
    $dlg.Controls.Add($btnClose)
    $script:SetBtnClose = $btnClose
    $dlg.AcceptButton = $btnClose
    $dlg.CancelButton = $btnClose

    $script:SetModeAlways.Add_CheckedChanged({ if ($null -ne $script:SetHide) { $script:SetHide.Enabled = -not $script:SetModeAlways.Checked } })
    $script:SetModeAuto.Add_CheckedChanged({ if ($null -ne $script:SetHide) { $script:SetHide.Enabled = $script:SetModeAuto.Checked } })
    $script:SetBubble.Add_CheckedChanged({ if ($null -ne $script:SetBubbleMax) { $script:SetBubbleMax.Enabled = [bool]$script:SetBubble.Checked } })
    $tbOp.Add_ValueChanged({ if ($null -ne $script:SetOpacityLbl -and $null -ne $script:SetOpacity) { $script:SetOpacityLbl.Text = ('{0}%' -f $script:SetOpacity.Value) } })

    return $dlg
}

function Show-Settings {
    if ($null -eq $script:Form) { return }
    $dlg = New-SettingsDialog
    $script:SuppressDeactivate = $true
    Enter-ChildWindow
    $result = $null
    try {
        [void]$dlg.ShowDialog($script:Form)
        $result = $dlg.Tag
    } finally {
        $script:SuppressDeactivate = $false
        $script:SettingsForm = $null
        try { $dlg.Dispose() } catch { }
        Exit-ChildWindow
    }
    if ($result -eq 'ok') {
        # 0.3.32：带上原来的 -FromWhale（-NoAnim 不重播滑入），否则箭头被当成普通窗口收掉、3 秒倒计时也被清
        if ($null -ne $script:UiSettings -and $script:UiSettings.Mode -eq 'always') { Show-Panel -NoAnim -FromWhale:$script:FromWhale }
        else { Apply-UiSettings }
    } elseif ($null -ne $script:Form -and $script:Form.Visible) {
        Start-AutoHide
    }
}

# ============================================================
#  0.2.3 · M4 导出（R12/R13/R14）
#  底栏「导出 ▾」→ 小窗：导出已完成 (N) / 导出全部 (N) + 格式 CSV/Excel
# ============================================================
function Invoke-Export {
    param([string]$Kind = 'done', [string]$Format = 'csv', [string]$Dir = '', [switch]$DisableXlsxForTest)
    $rows = @(Get-ExportRows -DoneOnly:($Kind -eq 'done'))
    if ($rows.Count -eq 0) {
        Show-Toast -Title '没有可导出的条目' -Body ('「' + $(if ($Kind -eq 'done') { '已完成' } else { '全部' }) + '」是 0 条')
        return
    }
    # 0.2.3：统一走 Export-TodoTable，xlsx 不可用时它自己回落 CSV
    $res = Export-TodoTable -Kind $Kind -Format $Format -Dir $Dir -DisableXlsxForTest:$DisableXlsxForTest
    Write-Log ('导出完成：' + $res.Path + '（' + $rows.Count + ' 条 / ' + $res.Format + '）')
    $title = ('已导出 ' + $rows.Count + ' 条（' + $res.Format.ToUpper() + '）')
    if ($res.Fallback) { $title = '本机没有 Excel/WPS，已导出 CSV' }
    Show-Toast -Title $title -Body $res.Path
}

function New-ExportMenuForm {
    param($Anchor)
    $doneCount = @(Get-ExportRows -DoneOnly).Count
    $allCount = @(Get-ExportRows).Count
    $hasExcel = (Test-Path 'Registry::HKEY_CLASSES_ROOT\Excel.Application')

    $f = New-Object System.Windows.Forms.Form
    $f.Text = '导出'
    $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
    $f.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.ShowInTaskbar = $false
    $f.TopMost = $true
    $f.ClientSize = New-Object System.Drawing.Size(280, 168)
    $f.Font = $script:FontTitle
    $f.Tag = 'export-menu'
    $script:ExportForm = $f
    $script:ExportKind = 'done'
    $script:ExportFormat = 'csv'

    $btnDone = New-Object System.Windows.Forms.Button
    $btnDone.Text = ('导出已完成事项（{0}）' -f $doneCount)
    $btnDone.Location = New-Object System.Drawing.Point(12, 12)
    $btnDone.Size = New-Object System.Drawing.Size(256, 30)
    $btnDone.Add_Click({ $script:ExportKind = 'done'; Invoke-Export -Kind 'done' -Format $script:ExportFormat -DisableXlsxForTest:([bool]$script:DisableXlsxForTest); $script:ExportForm.Close() })
    $f.Controls.Add($btnDone)

    $btnAll = New-Object System.Windows.Forms.Button
    $btnAll.Text = ('导出全部清单（{0}）' -f $allCount)
    $btnAll.Location = New-Object System.Drawing.Point(12, 48)
    $btnAll.Size = New-Object System.Drawing.Size(256, 30)
    $btnAll.Add_Click({ $script:ExportKind = 'all'; Invoke-Export -Kind 'all' -Format $script:ExportFormat -DisableXlsxForTest:([bool]$script:DisableXlsxForTest); $script:ExportForm.Close() })
    $f.Controls.Add($btnAll)

    $line = New-Object System.Windows.Forms.Panel
    $line.BackColor = [System.Drawing.Color]::FromArgb(255, 232, 235, 240)
    $line.Location = New-Object System.Drawing.Point(0, 90)
    $line.Size = New-Object System.Drawing.Size(280, 1)
    $f.Controls.Add($line)

    $lbFmt = New-Object System.Windows.Forms.Label
    $lbFmt.Text = '格式'
    $lbFmt.AutoSize = $false
    $lbFmt.Location = New-Object System.Drawing.Point(14, 102)
    $lbFmt.Size = New-Object System.Drawing.Size(40, 20)
    $f.Controls.Add($lbFmt)

    $rbCsv = New-Object System.Windows.Forms.RadioButton
    $rbCsv.Text = 'CSV'
    $rbCsv.AutoSize = $false
    $rbCsv.Location = New-Object System.Drawing.Point(60, 100)
    $rbCsv.Size = New-Object System.Drawing.Size(60, 22)
    $rbCsv.Checked = $true
    # 0.2.3a：handler 里不能用函数局部变量（函数返回后是 null），用 sender
    $rbCsv.Add_CheckedChanged({ param($s, $e) if ($s.Checked) { $script:ExportFormat = 'csv' } })
    $f.Controls.Add($rbCsv)
    $script:ExportCsvRadio = $rbCsv

    $rbXlsx = New-Object System.Windows.Forms.RadioButton
    $rbXlsx.Text = 'Excel'
    $rbXlsx.AutoSize = $false
    $rbXlsx.Location = New-Object System.Drawing.Point(126, 100)
    $rbXlsx.Size = New-Object System.Drawing.Size(70, 22)
    $rbXlsx.Enabled = $hasExcel
    $rbXlsx.Add_CheckedChanged({ param($s, $e) if ($s.Checked) { $script:ExportFormat = 'xlsx' } })
    $f.Controls.Add($rbXlsx)
    $script:ExportXlsxRadio = $rbXlsx

    $lbNote = New-Object System.Windows.Forms.Label
    $lbNote.Text = '保存到：文档\待办导出\（CSV 为 UTF-8 带 BOM，Excel 双击不乱码）'
    $lbNote.AutoSize = $false
    $lbNote.Font = $script:FontMeta
    $lbNote.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 146, 154)
    $lbNote.Location = New-Object System.Drawing.Point(14, 126)
    $lbNote.Size = New-Object System.Drawing.Size(254, 32)
    $f.Controls.Add($lbNote)

    if ($null -ne $Anchor -and $null -ne $Anchor.PSObject.Properties['Bounds']) {
        $p = $Anchor.PointToScreen((New-Object System.Drawing.Point(0, $Anchor.Height)))
        $x = $p.X
        $y = $p.Y - $f.Height - 4
        $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        if ($x -lt $wa.Left) { $x = $wa.Left }
        if ($x + $f.Width -gt $wa.Right) { $x = $wa.Right - $f.Width }
        if ($y -lt $wa.Top) { $y = $wa.Top }
        $f.Location = New-Object System.Drawing.Point($x, $y)
    }
    return $f
}

function Show-ExportMenu {
    param($Anchor)
    if ($null -eq $script:Form) { return }
    if ($null -ne $script:ExportForm -and -not $script:ExportForm.IsDisposed) {
        $script:ExportForm.Close()
        return
    }
    $f = New-ExportMenuForm -Anchor $Anchor
    $f.Add_Deactivate({ if ($null -ne $script:ExportForm -and -not $script:ExportForm.IsDisposed) { $script:ExportForm.Close() } })
    $f.Add_FormClosed({ Exit-ChildWindow })
    Enter-ChildWindow
    try { $f.Show() } catch { Exit-ChildWindow; throw }
}

# ============================================================
#  v1-b+：自绘置顶提醒小窗（替代 ShowBalloonTip）
#  Win11 26200 + PS5.1 上气球会被系统吞掉，只能用自己画的窗口。
# ============================================================
function Initialize-Toast {
    if ($null -ne $script:Toast -and -not $script:Toast.IsDisposed) { return }
    $f = New-Object System.Windows.Forms.Form
    $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $f.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $f.ShowInTaskbar = $false
    $f.TopMost = $true
    $f.BackColor = [System.Drawing.Color]::FromArgb(255, 38, 42, 50)
    $f.Size = New-Object System.Drawing.Size(380, 116)
    $f.Cursor = [System.Windows.Forms.Cursors]::Hand

    $bar = New-Object System.Windows.Forms.Panel
    $bar.BackColor = [System.Drawing.Color]::FromArgb(255, 232, 124, 20)
    $bar.Location = New-Object System.Drawing.Point(0, 0)
    $bar.Size = New-Object System.Drawing.Size(4, 116)
    $f.Controls.Add($bar)

    $lbTitle = New-Object System.Windows.Forms.Label
    $lbTitle.AutoSize = $false
    $lbTitle.Location = New-Object System.Drawing.Point(18, 14)
    $lbTitle.Size = New-Object System.Drawing.Size(344, 24)
    $lbTitle.Font = $script:FontHead
    $lbTitle.ForeColor = [System.Drawing.Color]::White
    $lbTitle.BackColor = [System.Drawing.Color]::FromArgb(255, 38, 42, 50)
    $f.Controls.Add($lbTitle)

    $lbBody = New-Object System.Windows.Forms.Label
    $lbBody.AutoSize = $false
    $lbBody.Location = New-Object System.Drawing.Point(18, 40)
    $lbBody.Size = New-Object System.Drawing.Size(344, 64)
    $lbBody.Font = $script:FontTitle
    $lbBody.ForeColor = [System.Drawing.Color]::FromArgb(255, 222, 227, 235)
    $lbBody.BackColor = [System.Drawing.Color]::FromArgb(255, 38, 42, 50)
    $f.Controls.Add($lbBody)

    # 0.3.40：原来点提示框直接 Show-Panel（不带 -FromWhale），面板已显示时会把侧边模式清掉
    #（收起箭头消失 + 3 秒自动收回停）。改走 Open-PanelFromToast，只按当前状态恢复。
    $f.Add_Click({ Open-PanelFromToast })
    $lbTitle.Add_Click({ Open-PanelFromToast })
    $lbBody.Add_Click({ Open-PanelFromToast })

    $script:Toast = $f
    $script:ToastTitle = $lbTitle
    $script:ToastBody = $lbBody

    $script:ToastTimer = New-Object System.Windows.Forms.Timer
    $script:ToastTimer.Interval = 8000
    $script:ToastTimer.Add_Tick({ $script:ToastTimer.Stop(); Hide-Toast })

    # 先建句柄再加 WS_EX_NOACTIVATE：弹窗不抢键盘焦点
    $f.CreateControl()
    if ($script:HasNative) {
        try { [DshTodoTray.Win]::MakeNoActivate($f.Handle) } catch { }
    }
}

function Show-Toast {
    param([string]$Title, [string]$Body)
    Initialize-Toast
    $script:ToastTitle.Text = $Title
    $script:ToastBody.Text = $Body
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $x = $wa.Right - $script:Toast.Width - 16
    # 默认右上角：右下角常被系统「激活 Windows」水印盖住，字会发糊（P7）
    $y = $wa.Top + 16
    if ($null -ne $script:Form -and $script:Form.Visible) {
        $y = $wa.Bottom - $script:Toast.Height - 16
    }
    $script:Toast.Location = New-Object System.Drawing.Point($x, $y)
    $script:Toast.Show()
    if ($script:HasNative) {
        try {
            # HWND_TOPMOST + NOSIZE + NOMOVE + NOACTIVATE
            [void][DshTodoTray.Win]::SetWindowPos($script:Toast.Handle, [IntPtr](-1), $x, $y, 0, 0, 0x0013)
        } catch { }
    }
    $script:ToastTimer.Stop()
    $script:ToastTimer.Start()
}

function Hide-Toast {
    if ($null -eq $script:Toast) { return }
    try { $script:ToastTimer.Stop() } catch { }
    try { if ($script:Toast.Visible) { $script:Toast.Hide() } } catch { }
}

# 0.3.40：点黑色提示框 = 「把面板叫回来」，不是「重新开一个面板」。
# 面板已经显示着（导出提示框就是在面板开着时弹的）时，绝不能重排/重显——
# 那会把 $script:FromWhale 和 3 秒倒计时一起清掉，收起箭头就没了（用户 2026-11-11 19:05 报的 BUG）。
function Open-PanelFromToast {
    Hide-Toast
    if ($null -eq $script:Form) { return }
    if ($script:Form.Visible) {
        # 已显示：保持原样，只补一次置顶 + 按当前模式补箭头/倒计时
        if ($script:HasNative) {
            try {
                $insert = [IntPtr](-2)
                if ($null -ne $script:UiSettings -and [bool]$script:UiSettings.TopMost) { $insert = [IntPtr](-1) }
                [void][DshTodoTray.Win]::SetWindowPos($script:Form.Handle, $insert, 0, 0, 0, 0, 0x0013)
            } catch { }
        }
        Update-CollapseChrome
        Restart-PeekCountdown
        Write-Log ('[TOAST] 点提示框：面板已显示，保持原模式（fromWhale={0}）' -f [bool]$script:FromWhale)
        return
    }
    if ($script:PanelCollapsed) {
        Write-Log '[TOAST] 点提示框：从侧边展开面板'
        Set-Collapsed $false '点提示框' -FromWhale
        return
    }
    Write-Log '[TOAST] 点提示框：面板已隐藏 → 重新显示'
    Show-Panel -FromWhale:([string]$script:WinCfg.Edge -ne 'none')
}

function Get-NotifySettings {
    $ahead = 0
    $missed = $true
    $enabled = $true
    $cfg = Get-Config
    if ($null -ne $cfg) {
        $n = Get-Prop $cfg 'notify' $null
        if ($null -ne $n) {
            $ahead = [int](Get-Prop $n 'aheadMinutes' 0)
            $missed = [bool](Get-Prop $n 'missedOnStartup' $true)
            $enabled = [bool](Get-Prop $n 'enabled' $true)
        }
    }
    if ($ahead -lt 0) { $ahead = 0 }
    if ($ahead -gt 1440) { $ahead = 1440 }
    return [pscustomobject]@{ AheadMinutes = $ahead; MissedOnStartup = $missed; Enabled = $enabled }
}

function Get-NotifyStatePath {
    return (Join-Path $script:BaseDir 'state.json')
}

function Initialize-NotifyState {
    $script:Reminded = @{}
    $path = Get-NotifyStatePath
    if (-not (Test-Path -LiteralPath $path)) { return }
    $doc = Read-JsonFile $path
    if ($null -eq $doc) { return }
    $map = Get-Prop $doc 'reminded' $null
    if ($null -eq $map) { return }
    foreach ($prop in $map.PSObject.Properties) { $script:Reminded[$prop.Name] = [string]$prop.Value }
}

function Save-NotifyState {
    $map = [ordered]@{}
    foreach ($k in @($script:Reminded.Keys | Sort-Object)) { $map[[string]$k] = [string]$script:Reminded[$k] }
    $doc = [ordered]@{ version = 1; updatedAt = (Get-NowStamp); reminded = $map }
    try {
        Save-TextAtomic -Path (Get-NotifyStatePath) -Text ((ConvertTo-JsonText $doc) + "`n")
    } catch {
        Write-Log ('提醒状态写盘失败: ' + $_.Exception.Message) 'WARN'
    }
}

# 只算「该弹的」，不产生副作用（自检直接调它）
function Get-DueChecks {
    $settings = Get-NotifySettings
    if (-not $settings.Enabled) { return @() }
    $now = Get-Date
    $out = @()
    foreach ($l in @(Get-Lists)) {
        if (-not (Test-Path -LiteralPath $l.Path)) { continue }
        $doc = Read-JsonFile $l.Path
        if ($null -eq $doc) { continue }
        foreach ($it in @(Get-Prop $doc 'items' @())) {
            if ($null -eq $it) { continue }
            if ([string](Get-Prop $it 'status' 'todo') -eq 'done') { continue }
            $dueText = [string](Get-Prop $it 'due' '')
            if ([string]::IsNullOrWhiteSpace($dueText)) { continue }
            $dd = ConvertTo-DateOrNull $dueText
            if ($null -eq $dd) { continue }
            $trigger = $dd.AddMinutes(-1 * $settings.AheadMinutes)
            if ($now -lt $trigger) { continue }
            $key = ('{0}|{1}' -f $l.Index, [string](Get-Prop $it 'id' ''))
            if ($script:Reminded.ContainsKey($key) -and $script:Reminded[$key] -eq $dueText) { continue }
            $out += [pscustomobject]@{ Key = $key; Title = [string](Get-Prop $it 'title' ''); Due = $dd; DueText = $dueText }
        }
    }
    return $out
}

function Show-DueBalloon {
    param($Items, [switch]$Startup)
    $arr = @($Items)
    if ($arr.Count -eq 0) { return }
    $title = '待办到期'
    if ($arr.Count -eq 1) {
        $text = ('{0}（{1}）' -f $arr[0].Title, $arr[0].Due.ToString('MM-dd HH:mm'))
    } else {
        $title = ('有 {0} 条待办到期' -f $arr.Count)
        $head = @($arr | Select-Object -First 3 | ForEach-Object { $_.Title })
        $text = ($head -join '、')
        if ($arr.Count -gt 3) { $text += (' 等 {0} 条' -f $arr.Count) }
    }
    if ($Startup) { $title = '补提醒 · ' + $title }
    if ($text.Length -gt 200) { $text = $text.Substring(0, 200) }
    Show-Toast -Title $title -Body $text
    Write-Log ('到期提醒: ' + $title + ' / ' + $text)
}

function Invoke-Reminders {
    param([switch]$Startup)
    try {
        $due = @(Get-DueChecks)
        if ($due.Count -eq 0) { return }
        foreach ($d in $due) { $script:Reminded[$d.Key] = $d.DueText }
        Save-NotifyState
        Show-DueBalloon -Items $due -Startup:$Startup
    } catch {
        Write-Log ('提醒检查失败: ' + $_.Exception.Message) 'ERROR'
    }
}

#endregion

# ============================================================
#  M16 启动项与过滤 —— 开机自启（只写启动文件夹）、搜索/清单过滤
# ============================================================
#region M16 启动项与过滤
function Get-AutostartPath {
    $startup = [Environment]::GetFolderPath('Startup')
    if ([string]::IsNullOrWhiteSpace($startup)) { return '' }
    return (Join-Path $startup 'dsh-todo-tray.cmd')
}

function Test-Autostart {
    $path = Get-AutostartPath
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    return (Test-Path -LiteralPath $path)
}

function Set-Autostart {
    param([bool]$On)
    $path = Get-AutostartPath
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    try {
        if ($On) {
            # 0.2.0：自启也走 .vbs（wscript 宿主），否则登录时同样会留黑框
            # 2026-11-15 开源仓库布局：todo-tray.ps1 在 src\，启动器在 scripts\
            # 先找同目录（开发目录仍扁平），再找 ..\scripts，都没有才退回 powershell 直启
            $vbs = Join-Path (Split-Path -Parent $script:ScriptPath) 'start-todo-tray.vbs'
            if (-not (Test-Path -LiteralPath $vbs)) {
                $parentDir = Split-Path -Parent (Split-Path -Parent $script:ScriptPath)
                $alt = Join-Path $parentDir 'scripts'
                $alt = Join-Path $alt 'start-todo-tray.vbs'
                if (Test-Path -LiteralPath $alt) { $vbs = $alt }
            }
            $cmd = '@echo off' + "`r`n"
            if (Test-Path -LiteralPath $vbs) {
                $cmd += 'wscript.exe "' + $vbs + '"'
            } else {
                $cmd += 'start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $script:ScriptPath + '"'
            }
            if (-not [string]::IsNullOrWhiteSpace($script:ConfigPath)) {
                $cmd += ' -ConfigPath "' + $script:ConfigPath + '"'
            }
            $cmd += "`r`n"
            [System.IO.File]::WriteAllText($path, $cmd, [System.Text.Encoding]::Default)
        } else {
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
        }
        $cfg = Get-Config
        if ($null -ne $cfg) {
            Set-Prop $cfg 'autostart' ([bool]$On)
            Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfg) + "`n")
        }
        Write-Log ('开机自启 -> ' + $On + ' / ' + $path)
        return $true
    } catch {
        Write-Log ('开机自启设置失败: ' + $_.Exception.Message) 'ERROR'
        return $false
    }
}

function Ensure-AutostartFromConfig {
    # 0.3.36：config 里 autostart=true 但「启动」文件夹里没有启动项（首次运行 / 被删）→ 补建一个。
    # 只在缺失时补，autostart=false 时不主动删（删启动项是用户在设置里取消勾选的事）。
    try {
        $cfg = Get-Config
        if ($null -eq $cfg) { return }
        if (-not [bool](Get-Prop $cfg 'autostart' $false)) { return }
        if (Test-Autostart) { return }
        [void](Set-Autostart -On $true)
    } catch {
        Write-Log ('开机自启补建失败: ' + $_.Exception.Message) 'ERROR'
    }
}

function Test-FilterMatch {
    param($Entry)
    if ([string]::IsNullOrWhiteSpace($script:FilterText)) { return $true }
    $q = $script:FilterText.Trim()
    if ([string]::IsNullOrWhiteSpace($q)) { return $true }
    if ([string]$Entry.Title -like ('*' + $q + '*')) { return $true }
    if ([string]$Entry.ListName -like ('*' + $q + '*')) { return $true }
    foreach ($tag in @($Entry.Tags)) {
        if ([string]$tag -like ('*' + $q + '*')) { return $true }
    }
    return $false
}

function Get-FilteredEntries {
    param($State)
    $listIdx = [int]$script:FilterListIndex
    $out = @()
    foreach ($en in @($State.Entries)) {
        if ($listIdx -ge 0 -and [int]$en.ListIndex -ne $listIdx) { continue }
        if (-not (Test-FilterMatch -Entry $en)) { continue }
        $out += $en
    }
    return $out
}

#endregion

# ============================================================
#  M17 小窗 · 计时 · 退出 —— 子窗口计数、自动隐藏、展开后 3 秒收回、退出
# ============================================================
#region M17 小窗 · 计时 · 退出
function Enter-ChildWindow {
    $script:ChildOpen++
    Stop-AutoHide
    Stop-StateTimers
    # 0.3.32：小窗期间只是「暂停」自动收回，关窗后由 Exit-ChildWindow 按 FromWhale 重新排程
    $script:PeekExpanded = $false
    $script:WhaleDeadline = $null
    if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Stop() } catch { } }
    Hide-Bubble
    Write-Log ('[CHILD] 打开小窗，计数=' + $script:ChildOpen)
}

function Exit-ChildWindow {
    if ($script:ChildOpen -gt 0) { $script:ChildOpen-- }
    Write-Log ('[CHILD] 关掉小窗，计数=' + $script:ChildOpen)
    if ($script:ChildOpen -gt 0) { return }
    if ($null -eq $script:Form -or -not $script:Form.Visible) { return }
    Restart-PeekCountdown
    # 0.3.32：小窗期间倒计时被清空，关窗要按「从小鲸鱼展开」重新排 3 秒（用户 2026-11-10 要求恢复）
    if ([bool]$script:FromWhale -and ($null -ne $script:WinCfg) -and ([string]$script:WinCfg.Edge -ne 'none')) {
        $secsPeek = [int]$script:WinCfg.AutoCollapseSeconds
        if ($secsPeek -gt 0) {
            $script:PeekExpanded = $true
            $script:WhaleDeadline = (Get-Date).AddSeconds($secsPeek)
            if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Start() } catch { } }
        }
    }
    # 0.3.32：小窗关掉后把侧向收起箭头补回来（0.3.31 起被当成普通窗口只剩 ×）
    Update-CollapseChrome
    Start-StateTimers
    Start-AutoHide
}

# 0.3.6：小窗口（新增/编辑/删除确认/设置/导出）打开期间，大面板保持显示、也不倒计时；
# 小窗口关掉之后才重新起算（用户 2026-11-09 定的口径）。
# 0.3.8：鼠标在面板里的时候不倒计时（用户 2026-11-09：点行、改东西时不该被收回）
function Test-PointerInPanel {
    if ($null -ne $script:SelfTestPointerInside) { return [bool]$script:SelfTestPointerInside }
    if ($null -eq $script:Form -or -not $script:Form.Visible) { return $false }
    if (-not ('DshTodoTray.Win3' -as [type])) { return $false }
    $p = [DshTodoTray.Win3]::Cursor()
    return (Test-PointInForm -X ([int]$p.X) -Y ([int]$p.Y))
}

# 小鲸鱼「展开后 N 秒自动收回」从零重新计时（鼠标离开面板 / 小窗关掉时调）
function Restart-PeekCountdown {
    if ($null -eq $script:WhaleDeadline -or $null -eq $script:WinCfg) { return }
    $secs = [int]$script:WinCfg.AutoCollapseSeconds
    if ($secs -le 0) { return }
    $script:WhaleDeadline = (Get-Date).AddSeconds($secs)
    if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Start() } catch { } }
}

function Start-AutoHide {
    if ($null -eq $script:Form -or -not $script:Form.Visible) { return }
    if ($null -eq $script:UiSettings) { $script:UiSettings = Get-UiSettings }
    Stop-AutoHide
    if ($script:ChildOpen -gt 0) { return }                 # 小窗口开着：不倒计时
    if (Test-PointerInPanel) { return }                     # 鼠标在面板里：不倒计时
    if ($script:UiSettings.Mode -eq 'always') { return }   # 常驻：不自动隐藏
    if ($script:EditMode) { return }                        # 编辑态：别在拖/删时自动收起
    if ($null -eq $script:AutoHideTimer) { return }
    $script:AutoHideTimer.Interval = [Math]::Max(1, [int]$script:UiSettings.HideSeconds) * 1000
    $script:AutoHideTimer.Start()
}

function Stop-AutoHide {
    if ($null -ne $script:AutoHideTimer) { try { $script:AutoHideTimer.Stop() } catch { } }
    if ($null -ne $script:FadeTimer) { try { $script:FadeTimer.Stop() } catch { } }
    if ($null -ne $script:Form) {
        # 0.3.30：透明度按模式取（未钉住恒 100%），别在这里把侧边面板又改回配置值
        try { $script:Form.Opacity = Get-PanelOpacityValue } catch { }
        Sync-PanelLayeredAlpha   # 0.3.3：淡出被撤掉后 alpha 要回到 Opacity 口径
    }
}

function Exit-App {
    $script:Exiting = $true
    Start-ExitWatchdog
    Write-Log '退出开始'
    try { if ($null -ne $script:WatchTimer) { $script:WatchTimer.Stop(); $script:WatchTimer.Dispose() } } catch { }
    try { if ($null -ne $script:RefreshTimer) { $script:RefreshTimer.Stop(); $script:RefreshTimer.Dispose() } } catch { }
    try { if ($null -ne $script:ShowTimer) { $script:ShowTimer.Stop(); $script:ShowTimer.Dispose() } } catch { }
    try { if ($null -ne $script:AutoHideTimer) { $script:AutoHideTimer.Stop(); $script:AutoHideTimer.Dispose() } } catch { }
    try { if ($null -ne $script:FadeTimer) { $script:FadeTimer.Stop(); $script:FadeTimer.Dispose() } } catch { }
    try { if ($null -ne $script:DoneFadeTimer) { $script:DoneFadeTimer.Stop(); $script:DoneFadeTimer.Dispose() } } catch { }
    try { if ($null -ne $script:PendingDeleteTimer) { $script:PendingDeleteTimer.Stop(); $script:PendingDeleteTimer.Dispose() } } catch { }
    try { if ($null -ne $script:BubbleTimer) { $script:BubbleTimer.Stop(); $script:BubbleTimer.Dispose() } } catch { }
    try { if ($null -ne $script:Bubble) { $script:Bubble.Hide(); $script:Bubble.Dispose() } } catch { }
    $script:Bubble = $null
    try { if ($null -ne $script:HoverTimer) { $script:HoverTimer.Stop(); $script:HoverTimer.Dispose() } } catch { }
    try { if ($null -ne $script:LeaveTimer) { $script:LeaveTimer.Stop(); $script:LeaveTimer.Dispose() } } catch { }
    try { if ($null -ne $script:DragTimer) { $script:DragTimer.Stop(); $script:DragTimer.Dispose() } } catch { }
    try { if ($null -ne $script:WhaleTimer) { $script:WhaleTimer.Stop(); $script:WhaleTimer.Dispose() } } catch { }
    try { if ($null -ne $script:Whale) { $script:Whale.Hide(); $script:Whale.Dispose() } } catch { }
    try { if ($null -ne $script:ShellHook) { $script:ShellHook.ReleaseHandle(); $script:ShellHook = $null } } catch { }
    try { if ($null -ne $script:ExportForm) { $script:ExportForm.Close(); $script:ExportForm.Dispose() } } catch { }
    try { if ($null -ne $script:SettingsForm) { $script:SettingsForm.Close(); $script:SettingsForm.Dispose() } } catch { }
    try { if ($null -ne $script:ShowEvent) { $script:ShowEvent.Dispose() } } catch { }
    try { if ($null -ne $script:ToastTimer) { $script:ToastTimer.Stop(); $script:ToastTimer.Dispose() } } catch { }
    try { if ($null -ne $script:Toast) { $script:Toast.Hide(); $script:Toast.Dispose() } } catch { }
    try { if ($null -ne $script:Notify) { $script:Notify.Visible = $false; $script:Notify.Dispose() } } catch { }
    foreach ($h in @($script:OldIconHandles)) {
        if ($script:HasNative) { [void][DshTodoTray.Native]::DestroyIcon($h) }
    }
    $script:OldIconHandles.Clear()
    if ($script:IconHandle -ne [IntPtr]::Zero -and $script:HasNative) {
        [void][DshTodoTray.Native]::DestroyIcon($script:IconHandle)
        $script:IconHandle = [IntPtr]::Zero
    }
    try { if ($null -ne $script:Form) { $script:Form.Hide(); $script:Form.Dispose() } } catch { }
    Write-Log '程序退出'
    [System.Windows.Forms.Application]::ExitThread()
}

#endregion

# ============================================================
#  M18 无界面自检 —— 250 项断言，在临时目录跑，不碰真实数据
# ============================================================
#region M18 无界面自检
function Invoke-SelfTest {
    $ok = 0
    $bad = 0
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('todo-tray-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null

    function Check {
        param([string]$Name, [bool]$Condition, [string]$Detail = '')
        if ($Condition) {
            $script:SelfTestMessages.Add(('  [OK]   ' + $Name)) | Out-Null
        } else {
            $script:SelfTestMessages.Add(('  [FAIL] ' + $Name + '  ' + $Detail)) | Out-Null
        }
    }

    try {
        # 1) 配置 + 数据
        $cfgPath = Join-Path $tmp 'config.json'
        $dataPath = Join-Path $tmp 'todos.json'
        $cfg = [ordered]@{
            version = 1
            autostart = $false
            notify = [ordered]@{ aheadMinutes = 0; missedOnStartup = $true }
            lists = @([ordered]@{ id = 'selftest'; name = '自检清单'; todos = 'todos.json' })
        }
        Save-TextAtomic -Path $cfgPath -Text ((ConvertTo-JsonText $cfg) + "`n")
        Check '配置可写出并可解析' ($null -ne (Read-JsonFile $cfgPath))

        # 0.3.35：新装默认设置（用户 2026-11-10 16:04 定「适合的默认设置」）= 常驻 35% / 悬停 3 秒 / 冒泡 15 秒
        $defCfgPath = Join-Path $tmp 'defaults.json'
        New-DefaultConfig -Path $defCfgPath
        $defCfg = Read-JsonFile $defCfgPath
        $defUi = Get-Prop $defCfg 'ui' $null
        $defBub = Get-Prop $defUi 'bubble' $null
        Check '默认设置：mode=always（常驻）' ([string](Get-Prop $defUi 'mode' '') -eq 'always') ('实际 ' + (Get-Prop $defUi 'mode' ''))
        Check '默认设置：hideSeconds=5' ([int](Get-Prop $defUi 'hideSeconds' 0) -eq 5) ('实际 ' + (Get-Prop $defUi 'hideSeconds' 0))
        Check '默认设置：opacity=35' ([int](Get-Prop $defUi 'opacity' 0) -eq 35) ('实际 ' + (Get-Prop $defUi 'opacity' 0))
        Check '默认设置：hoverMs=3000' ([int](Get-Prop $defUi 'hoverMs' 0) -eq 3000) ('实际 ' + (Get-Prop $defUi 'hoverMs' 0))
        Check '默认设置：冒泡开 / 15 秒' (([bool](Get-Prop $defBub 'enabled' $false)) -and ([int](Get-Prop $defBub 'maxSeconds' 0) -eq 15))
        Check '默认设置：autostart=true（开机自启）' ([bool](Get-Prop $defCfg 'autostart' $false))

        $doc = [ordered]@{
            version = 1
            scope = 'selftest'
            name = '自检清单'
            updatedAt = (Get-NowStamp)
            items = @(
                [ordered]@{ id = 'st-001'; title = '中文标题 · 含 * 与「引号」'; status = 'todo'; due = (Get-Date).AddMinutes(-30).ToString('yyyy-MM-dd HH:mm'); tags = @('自检', '中文'); link = ''; source = 'selftest'; created = (Get-NowStamp); done_at = '' },
                [ordered]@{ id = 'st-002'; title = '第二条'; status = 'todo'; due = ''; tags = @(); link = ''; source = 'selftest'; created = (Get-NowStamp); done_at = '' }
            )
        }
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText $doc) + "`n")
        $reload = Read-JsonFile $dataPath
        Check '中文往返不丢字' (@(Get-Prop $reload 'items' @())[0].title -eq '中文标题 · 含 * 与「引号」')
        Check '条数一致' (@(Get-Prop $reload 'items' @()).Count -eq 2)
        Check 'due 保持原样' (@(Get-Prop $reload 'items' @())[0].due -ne '')

        # 2) 勾选落盘
        $script:ConfigPath = $cfgPath
        $script:BaseDir = $tmp
        $okSet = Set-ItemStatus -ListIndex 0 -ItemId 'st-001' -Done $true
        $doc2 = Read-JsonFile $dataPath
        Check '勾选写回返回成功' $okSet
        Check 'status 变 done' (@(Get-Prop $doc2 'items' @())[0].status -eq 'done')
        Check 'done_at 已填' (@(Get-Prop $doc2 'items' @())[0].done_at -ne '')
        Check '第二条未被动到' (@(Get-Prop $doc2 'items' @())[1].status -eq 'todo')
        $okUnset = Set-ItemStatus -ListIndex 0 -ItemId 'st-001' -Done $false
        $doc3 = Read-JsonFile $dataPath
        Check '取消勾选写回成功' ($okUnset -and (@(Get-Prop $doc3 'items' @())[0].status -eq 'todo'))

        # 3) 未完成计数
        $state = Load-State
        Check '未完成计数 = 2' ($state.Pending -eq 2) ('实际 ' + $state.Pending)
        Check '逾期识别正常' ($state.Overdue -eq 1) ('实际 ' + $state.Overdue)

        # 3.5) 勾选事件处理器（模拟真实 CheckBox 的 Tag/Checked）
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $fakeCb = New-Object System.Windows.Forms.CheckBox
        $fakeCb.Tag = [pscustomobject]@{ ListIndex = 0; ItemId = 'st-002' }
        $fakeCb.Checked = $true
        On-CheckChanged -Sender $fakeCb
        $doc4 = Read-JsonFile $dataPath
        Check '处理器：勾选后 status 变 done' (@(Get-Prop $doc4 'items' @())[1].status -eq 'done')
        Check '处理器：JustDone 记下本条' ($script:JustDone.ContainsKey('0|st-002'))
        $fakeCb.Checked = $false
        On-CheckChanged -Sender $fakeCb
        $doc5 = Read-JsonFile $dataPath
        Check '处理器：取消勾选后回到 todo' (@(Get-Prop $doc5 'items' @())[1].status -eq 'todo')
        Check '处理器：JustDone 已移除' (-not $script:JustDone.ContainsKey('0|st-002'))
        $fakeCb.Dispose()
        # 3.7) 新增条目
        $docAdd0 = Read-JsonFile $dataPath
        $cnt0 = @(Get-Prop $docAdd0 'items' @()).Count
        $okAdd = Add-TodoItem -ListIndex 0 -Title '自检新增一条' -DueText '2026-12-31 09:00'
        $docAdd1 = Read-JsonFile $dataPath
        $itemsAdd = @(Get-Prop $docAdd1 'items' @())
        Check '新增：写入成功' $okAdd
        Check '新增：条数 +1' ($itemsAdd.Count -eq ($cnt0 + 1))
        Check '新增：id 递增到 st-003' ($itemsAdd[$cnt0].id -eq 'st-003')
        Check '新增：due 原样保存' ($itemsAdd[$cnt0].due -eq '2026-12-31 09:00')
        Check '新增：状态为 todo' ($itemsAdd[$cnt0].status -eq 'todo')

        # 3.8) 到期提醒（提前 10 分钟）
        $cfgR = [ordered]@{ version = 1; notify = [ordered]@{ aheadMinutes = 10; missedOnStartup = $true }; lists = @([ordered]@{ id = 'selftest'; name = '自检清单'; todos = 'todos.json' }) }
        Save-TextAtomic -Path $cfgPath -Text ((ConvertTo-JsonText $cfgR) + "`n")
        $nowR = Get-Date
        $docR = [ordered]@{
            version = 1
            items = @(
                [ordered]@{ id = 'st-001'; title = '5分钟后到期'; status = 'todo'; due = $nowR.AddMinutes(5).ToString('yyyy-MM-dd HH:mm'); tags = @(); done_at = '' },
                [ordered]@{ id = 'st-002'; title = '2小时后到期'; status = 'todo'; due = $nowR.AddHours(2).ToString('yyyy-MM-dd HH:mm'); tags = @(); done_at = '' },
                [ordered]@{ id = 'st-003'; title = '已完成但有到期'; status = 'done'; due = $nowR.AddMinutes(-1).ToString('yyyy-MM-dd HH:mm'); tags = @(); done_at = (Get-NowStamp) },
                [ordered]@{ id = 'st-004'; title = '没有到期'; status = 'todo'; due = ''; tags = @(); done_at = '' }
            )
        }
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText $docR) + "`n")
        $script:Reminded = @{}
        $due1 = @(Get-DueChecks)
        Check '提醒：只挑该提醒的那 1 条' ($due1.Count -eq 1) ('实际 ' + $due1.Count)
        Check '提醒：挑中的是 5 分钟后那条' ($due1.Count -gt 0 -and $due1[0].Title -eq '5分钟后到期')
        foreach ($d in $due1) { $script:Reminded[$d.Key] = $d.DueText }
        Check '提醒：已提醒过的不重复' (@(Get-DueChecks).Count -eq 0)

        # 3.9) 过滤 / 自启路径
        $script:FilterText = ''
        $fe = [pscustomobject]@{ Title = '中文标题'; ListName = '自检清单'; Tags = @('自检'); ListIndex = 0 }
        Check '过滤：空条件全通过' (Test-FilterMatch -Entry $fe)
        $script:FilterText = '中文'
        Check '过滤：命中标题' (Test-FilterMatch -Entry $fe)
        $script:FilterText = '自检'
        Check '过滤：命中标签' (Test-FilterMatch -Entry $fe)
        $script:FilterText = '不存在的词'
        Check '过滤：不命中' (-not (Test-FilterMatch -Entry $fe))
        $script:FilterText = ''
        Check '自启路径可解析' (-not [string]::IsNullOrWhiteSpace((Get-AutostartPath)))
        # 3.92) 公共库：写盘 / 导出 / 文件锁 / 删除
        $docL = [ordered]@{
            version = 1
            items   = @([ordered]@{ id = 'x-001'; title = '库自检'; status = 'todo'; due = ''; tags = @(); done_at = '' })
        }
        Save-TodoDoc -Doc $docL -Path $dataPath | Out-Null
        $docL2 = Read-JsonFile $dataPath
        Check '库：Save-TodoDoc 落盘' (@(Get-Prop $docL2 'items' @()).Count -eq 1)
        $mdL = Export-TodoMarkdown -Doc $docL2 -ListName '自检'
        Check '库：导出 Markdown' ($mdL.Contains('## 未完成（1）'))
        $lockL = Enter-FileLock -Path $dataPath -TimeoutMs 300
        Check '库：能拿到文件锁' ($null -ne $lockL)
        $lockL2 = Enter-FileLock -Path $dataPath -TimeoutMs 120
        Check '库：第二把锁会超时' ($null -eq $lockL2)
        Exit-FileLock $lockL
        $okRm = Remove-TodoItem -Path $dataPath -ItemId 'x-001'
        $docL3 = Read-JsonFile $dataPath
        Check '库：删除条目' ($okRm -and @(Get-Prop $docL3 'items' @()).Count -eq 0)

        # 3.95) 提醒小窗
        Initialize-Fonts
        Initialize-Toast
        Check '提醒小窗可创建' ($null -ne $script:Toast -and -not $script:Toast.IsDisposed)
        Check '提醒小窗有标题/正文' ($null -ne $script:ToastTitle -and $null -ne $script:ToastBody)
        Hide-Toast

        # 3.96) R3 设置（ui 段）：默认值 / 落盘 / 越界回落 / 不破坏 lists
        $cfgNoUi = [ordered]@{ version = 1; notify = [ordered]@{ aheadMinutes = 0; missedOnStartup = $true }; lists = @([ordered]@{ id = 'selftest'; name = '自检清单'; todos = 'todos.json' }) }
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfgNoUi) + "`n")
        $u0 = Get-UiSettings -Config (Read-JsonFile $script:ConfigPath)
        Check '设置：缺 ui 时 mode=auto' ($u0.Mode -eq 'auto')
        Check '设置：缺 ui 时 15 秒' ($u0.HideSeconds -eq 15)
        Check '设置：auto 默认不透明 100' ($u0.Opacity -eq 100)
        Check '设置：默认置顶 true' ($u0.TopMost -eq $true)

        $cfgAlways = [ordered]@{ version = 1; ui = [ordered]@{ mode = 'always'; hideSeconds = 30 }; lists = @([ordered]@{ id = 'selftest'; name = '自检清单'; todos = 'todos.json' }) }
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfgAlways) + "`n")
        $u1 = Get-UiSettings -Config (Read-JsonFile $script:ConfigPath)
        Check '设置：always 缺省透明度 85' ($u1.Opacity -eq 85) ('实际 ' + $u1.Opacity)
        Check '设置：always / 30 秒读回' ($u1.Mode -eq 'always' -and $u1.HideSeconds -eq 30)

        $okUi = Save-UiSettings -Settings ([pscustomobject]@{ Mode = 'always'; HideSeconds = 60; Opacity = 60; TopMost = $false })
        $cfgSaved = Read-JsonFile $script:ConfigPath
        $uiSaved = Get-Prop $cfgSaved 'ui' $null
        Check '设置：保存 ui.mode' ($okUi -and [string](Get-Prop $uiSaved 'mode' '') -eq 'always')
        Check '设置：保存 ui.hideSeconds' ([int](Get-Prop $uiSaved 'hideSeconds' 0) -eq 60)
        Check '设置：保存 ui.opacity' ([int](Get-Prop $uiSaved 'opacity' 0) -eq 60)
        Check '设置：保存 ui.topmost=false' ((Get-Prop $uiSaved 'topmost' $true) -eq $false)
        Check '设置：lists 没被弄丢' (@(Get-Lists).Count -eq 1)

        $cfgBad = [ordered]@{ version = 1; ui = [ordered]@{ mode = 'weird'; hideSeconds = 7; opacity = 5; topmost = $false }; lists = @([ordered]@{ id = 'selftest'; name = '自检清单'; todos = 'todos.json' }) }
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfgBad) + "`n")
        $ub = Get-UiSettings -Config (Read-JsonFile $script:ConfigPath)
        Check '设置：非法值回落（auto/15/100）' ($ub.Mode -eq 'auto' -and $ub.HideSeconds -eq 15 -and $ub.Opacity -eq 100) ('实际 ' + $ub.Mode + '/' + $ub.HideSeconds + '/' + $ub.Opacity)

        # 设置窗可创建、控件齐（只建不 Show，不抢焦点）
        $script:UiSettings = Get-UiSettings -Config (Read-JsonFile $script:ConfigPath)
        $dlgSet = New-SettingsDialog
        Check '设置窗可创建' ($null -ne $dlgSet -and -not $dlgSet.IsDisposed)
        Check '设置窗控件齐（模式/秒数/透明度/置顶/自启）' ($null -ne $script:SetModeAlways -and $null -ne $script:SetModeAuto -and $null -ne $script:SetHide -and $null -ne $script:SetOpacity -and $null -ne $script:SetTop -and $null -ne $script:SetAutostart)
        $dlgSet.Dispose()
        $script:SettingsForm = $null

        # 3.97) M2：老数据补字段 / 星级排序 / 名额上限
        $docOld = [ordered]@{
            version = 1
            items = @(
                [ordered]@{ id='old-001'; title='旧一'; status='todo'; due=''; tags=@(); done_at='' },
                [ordered]@{ id='old-002'; title='旧二'; status='todo'; due=''; tags=@(); done_at='' },
                [ordered]@{ id='old-003'; title='旧三'; status='todo'; due=''; tags=@(); done_at='' }
            )
        }
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText $docOld) + "`n")
        $up1 = Update-LegacyFields
        $docUp = Read-JsonFile $dataPath
        $upItems = @(Get-Prop $docUp 'items' @())
        Check '老数据：条数不变（3）' ($upItems.Count -eq 3) ('实际 ' + $upItems.Count)
        Check '老数据：prio 补成 1' (@($upItems | Where-Object { [int](Get-Prop $_ 'prio' 0) -eq 1 }).Count -eq 3)
        Check '老数据：order 按文件顺序 0/1/2' ([int](Get-Prop $upItems[0] 'order' -1) -eq 0 -and [int](Get-Prop $upItems[2] 'order' -1) -eq 2)
        Check '老数据：标题语义未变' ([string](Get-Prop $upItems[1] 'title' '') -eq '旧二')
        Check '老数据：只写一次（再跑返回 0）' ((Update-LegacyFields) -eq 0)

        $docSort = [ordered]@{
            version = 1
            items = @(
                [ordered]@{ id='s-1'; title='一星后'; status='todo'; due='2026-01-01 00:00'; prio=1; order=1; tags=@(); done_at='' },
                [ordered]@{ id='s-2'; title='三星'; status='todo'; due='2026-12-31 23:59'; prio=3; order=0; tags=@(); done_at='' },
                [ordered]@{ id='s-3'; title='二星先'; status='todo'; due=''; prio=2; order=0; tags=@(); done_at='' },
                [ordered]@{ id='s-4'; title='二星后'; status='todo'; due='2026-02-02 00:00'; prio=2; order=1; tags=@(); done_at='' },
                [ordered]@{ id='s-5'; title='一星先'; status='todo'; due=''; prio=1; order=0; tags=@(); done_at='' }
            )
        }
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText $docSort) + "`n")
        $st2 = Load-State
        $orderTitles = @($st2.Entries | ForEach-Object { $_.Title })
        Check '排序：3★→2★→1★、组内按 order' (($orderTitles -join '|') -eq '三星|二星先|二星后|一星先|一星后') ('实际 ' + ($orderTitles -join '|'))
        Check '排序：不按到期时间重排' ($orderTitles[4] -eq '一星后')

        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText ([ordered]@{ version = 1; items = @() })) + "`n")
        $ok3a = Add-TodoItem -ListIndex 0 -Title '三星A' -DueText '' -Prio 3
        $ok3b = Add-TodoItem -ListIndex 0 -Title '三星B' -DueText '' -Prio 3
        Check '名额：3★ 第一个成功' $ok3a
        Check '名额：3★ 第二个被拒' (-not $ok3b)
        $ok2a = Add-TodoItem -ListIndex 0 -Title '二星A' -DueText '' -Prio 2
        $ok2b = Add-TodoItem -ListIndex 0 -Title '二星B' -DueText '' -Prio 2
        $ok2c = Add-TodoItem -ListIndex 0 -Title '二星C' -DueText '' -Prio 2
        Check '名额：2★ 两个成功' ($ok2a -and $ok2b)
        Check '名额：2★ 第三个被拒' (-not $ok2c)
        $docQ = Read-JsonFile $dataPath
        $qItems = @(Get-Prop $docQ 'items' @())
        $q3 = @($qItems | Where-Object { [int](Get-Prop $_ 'prio' 1) -eq 3 })
        Check '名额：落盘后 3★ 只有 1 条' ($q3.Count -eq 1)
        Check '名额：3★ 首个 order=0' ([int](Get-Prop $q3[0] 'order' -1) -eq 0)
        $okDone3 = $false
        if ($q3.Count -gt 0) { $okDone3 = Set-ItemStatus -ListIndex 0 -ItemId ([string](Get-Prop $q3[0] 'id' '')) -Done $true }
        $ok3c = Add-TodoItem -ListIndex 0 -Title '三星C（前一个已完成）' -DueText '' -Prio 3
        Check '名额：已完成的 3★ 不占名额' ($okDone3 -and $ok3c)

        # 3.98) 迁移安全性：二次幂等（字节不变）+ 坏 JSON 不崩不改文件
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText ([ordered]@{
            version = 1
            items = @(
                [ordered]@{ id='m-001'; title='幂等一'; status='todo'; due=''; tags=@(); done_at='' },
                [ordered]@{ id='m-002'; title='幂等二'; status='todo'; due=''; tags=@(); done_at='' }
            )
        })) + "`n")
        $upIdem1 = Update-LegacyFields
        $bytes1 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($dataPath))
        Start-Sleep -Milliseconds 30
        $upIdem2 = Update-LegacyFields
        $bytes2 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($dataPath))
        Check '迁移：第一次真补（返回 1）' ($upIdem1 -eq 1) ('实际 ' + $upIdem1)
        Check '迁移：第二次不动（返回 0）' ($upIdem2 -eq 0) ('实际 ' + $upIdem2)
        Check '迁移：二次运行后文件字节完全一致' ($bytes1 -eq $bytes2)

        [System.IO.File]::WriteAllText($dataPath, '{ "version": 1, "items": [ { "id": "x"', (New-Object System.Text.UTF8Encoding($false)))
        $badBefore = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($dataPath))
        $upBad = Update-LegacyFields
        $badAfter = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($dataPath))
        Check '迁移：坏 JSON 不崩（返回 0）' ($upBad -eq 0)
        Check '迁移：坏 JSON 原文件一字未动' ($badBefore -eq $badAfter)

        # 3.99) M3：组内拖动 / 改星级 / 编辑态行
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText ([ordered]@{
            version = 1
            items = @(
                [ordered]@{ id='m-1'; title='一A'; status='todo'; due=''; prio=1; order=0; tags=@(); done_at='' },
                [ordered]@{ id='m-2'; title='一B'; status='todo'; due=''; prio=1; order=1; tags=@(); done_at='' },
                [ordered]@{ id='m-3'; title='二A'; status='todo'; due=''; prio=2; order=0; tags=@(); done_at='' },
                [ordered]@{ id='m-4'; title='二B'; status='todo'; due=''; prio=2; order=1; tags=@(); done_at='' }
            )
        })) + "`n")
        $okMove = Move-TodoGroupItem -ListIndex 0 -ItemId 'm-2' -TargetIndex 0
        $stM = Load-State
        $titlesM = @($stM.Entries | ForEach-Object { $_.Title })
        Check '拖动：组内 一B 拖到 1★ 组最前' ($okMove -and $titlesM[2] -eq '一B' -and $titlesM[3] -eq '一A') ('实际 ' + ($titlesM -join '|'))
        Check '拖动：没有跨组（2★ 仍排在前）' ($titlesM[0] -eq '二A' -and $titlesM[1] -eq '二B')
        $docM3b = Read-JsonFile $dataPath
        $m2Order = 99
        foreach ($it in @(Get-Prop $docM3b 'items' @())) { if ([string](Get-Prop $it 'id' '') -eq 'm-2') { $m2Order = [int](Get-Prop $it 'order' 99) } }
        Check '拖动：order 已落盘（m-2 → 0）' ($m2Order -eq 0) ('实际 ' + $m2Order)

        $okPrio = Update-TodoItem -ListIndex 0 -ItemId 'm-1' -Title '一A' -DueText '' -Prio 3
        $stM2 = Load-State
        $t2 = @($stM2.Entries | ForEach-Object { $_.Title })
        Check '改星级：1★→3★ 后排第一' ($okPrio -and $t2[0] -eq '一A') ('实际 ' + ($t2 -join '|'))
        $okPrio2 = Update-TodoItem -ListIndex 0 -ItemId 'm-2' -Title '一B' -DueText '' -Prio 3
        Check '改星级：第二个 3★ 被拒' (-not $okPrio2)

        $fakeEntry = [pscustomobject]@{ ListIndex = 0; ListName = '自检'; ItemId = 'm-1'; Title = '一A'; Status = 'todo'; DueText = ''; DueDate = $null; Overdue = $false; Tags = @(); CreatedText = ''; DoneAt = $null; Prio = 3; Order = 0 }
        $editRow = New-EntryRow -Entry $fakeEntry -RowWidth 380 -ShowList $false -EditMode $true
        $btns = @($editRow.Controls | Where-Object { $_ -is [System.Windows.Forms.Button] })
        $cbs = @($editRow.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] })
        $stars = @($editRow.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] -and $_.Text -eq '3★' })
        Check '编辑态：每行 2 个按钮（⚙/🗑）' ($btns.Count -eq 2) ('实际 ' + $btns.Count)
        Check '编辑态：复选框不显示' ($cbs.Count -eq 1 -and -not $cbs[0].Visible)
        Check '编辑态：行内显示 3★' ($stars.Count -eq 1)
        $editRow.Dispose()

        # 3.995) 新增框在「多清单」时按钮不与清单下拉框重叠（0.2.2 修过的 $y 问题）
        $cfg2 = [ordered]@{
            version = 1
            lists = @(
                [ordered]@{ id = 'selftest'; name = '自检清单'; todos = 'todos.json' },
                [ordered]@{ id = 'selftest2'; name = '第二清单'; todos = 'todos.json' }
            )
        }
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfg2) + "`n")
        $dlg2 = New-AddDialog
        $cbo2 = @($dlg2.Controls | Where-Object { $_ -is [System.Windows.Forms.ComboBox] })
        $okBtn2 = @($dlg2.Controls | Where-Object { $_ -is [System.Windows.Forms.Button] -and $_.Text -eq '确定' })
        Check '新增框：多清单时出现清单下拉' ($cbo2.Count -eq 1) ('实际 ' + $cbo2.Count)
        Check '新增框：确定按钮在清单下拉下方（不重叠）' ($cbo2.Count -eq 1 -and $okBtn2.Count -eq 1 -and $okBtn2[0].Top -gt $cbo2[0].Bottom)
        $dlg2.Dispose()

        # 3.997) M4：导出（已完成/全部、CSV 列与转义、BOM、文件名）
        # 先把配置恢复成单清单（上一项布局用例临时写了 2 个清单）
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText ([ordered]@{
            version = 1
            lists = @([ordered]@{ id = 'selftest'; name = '自检清单'; todos = 'todos.json' })
        })) + "`n")
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText ([ordered]@{
            version = 1
            items = @(
                [ordered]@{ id='e-1'; title='带,逗号"引号'; status='done'; due=''; prio=3; order=0; tags=@('a', 'b'); link='D:\x.md'; created='2026-10-01T09:00:00+08:00'; done_at='2026-10-01T10:00:00+08:00' },
                [ordered]@{ id='e-2'; title='未完成一'; status='todo'; due='2026-11-01 09:00'; prio=1; order=0; tags=@(); link=''; created='2026-10-01T09:00:00+08:00'; done_at='' },
                [ordered]@{ id='e-3'; title='未完成二'; status='todo'; due=''; prio=2; order=0; tags=@(); link=''; created='2026-10-01T09:00:00+08:00'; done_at='' }
            )
        })) + "`n")
        $rDone = @(Get-ExportRows -DoneOnly)
        $rAll = @(Get-ExportRows)
        Check '导出：已完成 1 条' ($rDone.Count -eq 1) ('实际 ' + $rDone.Count)
        Check '导出：全部 3 条' ($rAll.Count -eq 3) ('实际 ' + $rAll.Count)
        $csvDone = Get-ExportCsvText -Kind 'done'
        $csvAll = Get-ExportCsvText -Kind 'all'
        Check '导出：已完成表头 6 列' ($csvDone.Split("`n")[0].Trim() -eq '完成时间,标题,星级,清单,标签,来源链接')
        Check '导出：全部表头 9 列' ($csvAll.Split("`n")[0].Trim() -eq '状态,标题,星级,到期,清单,标签,添加时间,完成时间,来源链接')
        Check '导出：逗号/引号正确转义' ($csvDone.Contains('"带,逗号""引号"'))
        $exportTmp = Join-Path $tmp 'exp.csv'
        Export-TodoCsv -Path $exportTmp -Kind 'done' | Out-Null
        $eb = [System.IO.File]::ReadAllBytes($exportTmp)
        Check '导出：CSV 为 UTF-8 带 BOM' ($eb.Length -ge 3 -and $eb[0] -eq 0xEF -and $eb[1] -eq 0xBB -and $eb[2] -eq 0xBF)
        $nameOk = ((New-ExportPath -Kind 'done' -At (Get-Date -Date '2026-10-28 11:40')) -match '待办_已完成_20261028_1140\.csv$')
        Check '导出：文件名格式对' $nameOk

        # 3.998) 0.2.3：xlsx 不可用时自动回落 CSV（硬要求）
        $fbDir = Join-Path $tmp 'exp_fallback'
        $fb = Export-TodoTable -Kind 'done' -Format 'xlsx' -Dir $fbDir -DisableXlsxForTest
        Check '导出：xlsx 不可用 → 回落 CSV' ($fb.Format -eq 'csv' -and $fb.Fallback -and $fb.Path.EndsWith('.csv') -and (Test-Path -LiteralPath $fb.Path))
        $fbBytes = [System.IO.File]::ReadAllBytes($fb.Path)
        Check '导出：回落出的 CSV 仍是 UTF-8 BOM' ($fbBytes.Length -ge 3 -and $fbBytes[0] -eq 0xEF -and $fbBytes[1] -eq 0xBB -and $fbBytes[2] -eq 0xBF)

        # 3.999) 0.2.3：便携模式（portable.flag → <app>\data\，不碰 profile）
        $pfDir = Join-Path $tmp 'portable_app'
        New-Item -ItemType Directory -Path $pfDir -Force | Out-Null
        $pfNoFlag = Resolve-ConfigPath -AppDir $pfDir
        Check '便携：无 flag 时仍走 profile' ($pfNoFlag -like '*\.dsh\deepseek-todo\config.json') ('实际 ' + $pfNoFlag)
        [System.IO.File]::WriteAllText((Join-Path $pfDir 'portable.flag'), '', (New-Object System.Text.UTF8Encoding($false)))
        $pfCfg = Resolve-ConfigPath -AppDir $pfDir
        Check '便携：有 flag 时 config 落在 <app>\data' ($pfCfg -eq (Join-Path $pfDir 'data\config.json')) ('实际 ' + $pfCfg)
        $profCfg = Join-Path $env:USERPROFILE '.dsh\deepseek-todo\config.json'
        $profBefore = 0
        if (Test-Path -LiteralPath $profCfg) { $profBefore = (Get-Item -LiteralPath $profCfg).LastWriteTimeUtc.Ticks }
        $script:ConfigPath = $pfCfg
        $script:BaseDir = Split-Path -Parent $pfCfg
        Ensure-Config
        $listsP = @(Get-Lists)
        Check '便携：生成 data\config.json' (Test-Path -LiteralPath $pfCfg)
        Check '便携：默认不开机自启（不写启动项）' ([bool](Get-Prop (Read-JsonFile $pfCfg) 'autostart' $true) -eq $false)
        Check '便携：清单路径在 data\ 下' ($listsP.Count -ge 1 -and $listsP[0].Path -eq (Join-Path $pfDir 'data\todos.json'))
        $pfText = Get-Content -LiteralPath $pfCfg -Raw -Encoding UTF8
        Check '便携：config 里不含 profile 路径' (-not ($pfText -match '\.dsh'))
        $okP = Add-TodoItem -ListIndex 0 -Title '便携一条' -DueText ''
        Check '便携：新增写进 data\todos.json' ($okP -and (Test-Path -LiteralPath (Join-Path $pfDir 'data\todos.json')))
        $profAfter = 0
        if (Test-Path -LiteralPath $profCfg) { $profAfter = (Get-Item -LiteralPath $profCfg).LastWriteTimeUtc.Ticks }
        Check '便携：全程没写 profile 的 config' ($profBefore -eq $profAfter)

        # 3.9995) 0.2.2a：删除确认框的按钮真的要能置 Tag 并关窗（防「多套一层 {}」回归）
        $script:ConfigPath = Join-Path $tmp 'config.json'
        $script:BaseDir = $tmp
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText ([ordered]@{
            version = 1
            lists = @([ordered]@{ id = 'selftest'; name = '自检清单'; todos = 'todos.json' })
        })) + "`n")
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText ([ordered]@{
            version = 1
            items = @([ordered]@{ id = 'del-1'; title = '删我'; status = 'todo'; due = ''; prio = 1; order = 0; tags = @(); done_at = '' })
        })) + "`n")
        # 0.3.9：确认框改系统 MessageBox，用钩子验「确认/取消」两条分支
        $script:SelfTestConfirmResult = $true
        Check '删除确认（钩子）：确认 → True' ((Confirm-Delete -Title 'x') -eq $true)
        $script:SelfTestConfirmResult = $false
        Check '删除确认（钩子）：取消 → False' ((Confirm-Delete -Title 'x') -eq $false)
        $script:SelfTestConfirmResult = $null
        $fakeDel = [pscustomobject]@{ ListIndex = 0; ItemId = 'del-1'; Title = '删我'; Status = 'todo'; Prio = 1 }
        $okDel = Invoke-DeleteConfirmed -Entry $fakeDel
        $docDel = Read-JsonFile $dataPath
        $still = @(@(Get-Prop $docDel 'items' @()) | Where-Object { [string](Get-Prop $_ 'id' '') -eq 'del-1' }).Count
        Check '删除：todos.json 里该条目真的没了' ($okDel -and $still -eq 0) ('ok=' + $okDel + ' still=' + $still)
        $logText = ''
        $logPath = Get-LogFilePath
        if (Test-Path -LiteralPath $logPath) { $logText = Get-Content -LiteralPath $logPath -Raw -Encoding UTF8 }
        Check '删除：日志有「删除条目 del-1 … 结果 True」' ($logText -match '删除条目 del-1.*结果 True')

        # 删除 → 15 秒撤销窗口 → 撤销恢复（走 Invoke-DeleteEntry，与按钮同一条路）
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText ([ordered]@{
            version = 1
            items = @([ordered]@{ id = 'undo-1'; title = '撤销我'; status = 'todo'; due = ''; prio = 1; order = 0; tags = @(); done_at = '' })
        })) + "`n")
        $fakeUndo = [pscustomobject]@{ ListIndex = 0; ItemId = 'undo-1'; Title = '撤销我'; Status = 'todo'; Prio = 1 }
        $script:PendingDeletes = @()
        $script:SelfTestConfirmResult = $true
        Invoke-DeleteEntry -Entry $fakeUndo
        $docGone = Read-JsonFile $dataPath
        $goneN = @(@(Get-Prop $docGone 'items' @()) | Where-Object { [string](Get-Prop $_ 'id' '') -eq 'undo-1' }).Count
        Check '删除执行：条目从文件里真的没了' ($goneN -eq 0) ('left=' + $goneN)
        Check '删除后进入 15 秒撤销窗口（列表留一行）' (@($script:PendingDeletes).Count -eq 1)
        Invoke-UndoDelete -Key ([string]$script:PendingDeletes[0].Key)
        $docBack = Read-JsonFile $dataPath
        $backN = @(@(Get-Prop $docBack 'items' @()) | Where-Object { [string](Get-Prop $_ 'id' '') -eq 'undo-1' }).Count
        Check '撤销：条目按原文写回文件' ($backN -eq 1) ('back=' + $backN)
        Check '撤销后撤销窗口清空' (@($script:PendingDeletes).Count -eq 0)
        $script:SelfTestConfirmResult = $null

        # 0.2.3a：导出菜单的格式单选要真的改到 $script:ExportFormat（防 handler 引用局部变量）
        $emf = New-ExportMenuForm -Anchor $null
        $script:ExportFormat = 'csv'
        $script:ExportXlsxRadio.Enabled = $true
        $script:ExportXlsxRadio.Checked = $true
        Check '导出菜单：选 Excel → format=xlsx' ($script:ExportFormat -eq 'xlsx') ('实际 ' + $script:ExportFormat)
        $script:ExportCsvRadio.Checked = $true
        Check '导出菜单：切回 CSV → format=csv' ($script:ExportFormat -eq 'csv') ('实际 ' + $script:ExportFormat)
        $emf.Dispose()

        # 0.2.3b：交互控件「触发后副作用成立」的行为断言（主管要求，不真点鼠标）
        # a) 顶栏 编辑/完成 按钮
        $fakeEditBtn = New-Object System.Windows.Forms.Button
        $fakeEditBtn.Text = '编辑'
        $script:EditButton = $fakeEditBtn
        $script:EditMode = $false
        $script:Form = $null
        Toggle-EditMode
        Check '控件：编辑按钮 → 进编辑态（按钮变「完成」）' ($script:EditMode -and $fakeEditBtn.Text -eq '完成')
        Toggle-EditMode
        Check '控件：再点 → 回常态（按钮变「编辑」）' ((-not $script:EditMode) -and $fakeEditBtn.Text -eq '编辑')

        # b) 设置窗「关闭」→ 配置真的落盘
        $script:UiSettings = Get-UiSettings -Config (Read-JsonFile $script:ConfigPath)
        $sdlg = New-SettingsDialog
        $script:SetModeAlways.Checked = $true
        $script:SetOpacity.Value = 60
        $script:SetTop.Checked = $true
        $clickClose = $script:SetBtnClose.GetType().GetMethod('OnClick', [System.Reflection.BindingFlags]'NonPublic,Instance')
        [void]$clickClose.Invoke($script:SetBtnClose, @([System.EventArgs]::Empty))
        $cfgAfter = Get-Config
        $uiAfter = Get-Prop $cfgAfter 'ui' $null
        Check '控件：设置「关闭」→ mode 落盘 always' ([string](Get-Prop $uiAfter 'mode' '') -eq 'always')
        Check '控件：设置「关闭」→ opacity 落盘 60' ([int](Get-Prop $uiAfter 'opacity' 0) -eq 60)
        $sdlg.Dispose()
        $script:SettingsForm = $null

        # c) 新增框「确定」→ 条目真的进文件
        $cntBefore = @(Get-Prop (Read-JsonFile $dataPath) 'items' @()).Count
        $adlg = New-AddDialog
        $script:DlgTitle.Text = '控件新增'
        $okAddBtn = @($adlg.Controls | Where-Object { $_ -is [System.Windows.Forms.Button] -and $_.Text -eq '确定' })
        $clickOk = $okAddBtn[0].GetType().GetMethod('OnClick', [System.Reflection.BindingFlags]'NonPublic,Instance')
        [void]$clickOk.Invoke($okAddBtn[0], @([System.EventArgs]::Empty))
        $cntAfter = @(Get-Prop (Read-JsonFile $dataPath) 'items' @()).Count
        Check '控件：新增「确定」→ 条目 +1' ($cntAfter -eq ($cntBefore + 1))
        $adlg.Dispose()

        # d) 导出动作（导出菜单两个按钮走的就是 Invoke-Export）：强制无 Excel → 只出 CSV
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText ([ordered]@{
            version = 1
            items = @([ordered]@{ id = 'exp-1'; title = '导出用'; status = 'done'; due = ''; prio = 1; order = 0; tags = @(); done_at = '2026-10-28T14:00:00+08:00' })
        })) + "`n")
        $expDir = Join-Path $tmp 'ui_export'
        Invoke-Export -Kind 'done' -Format 'xlsx' -Dir $expDir -DisableXlsxForTest
        $csvs = @(Get-ChildItem $expDir -Filter '*.csv' -ErrorAction SilentlyContinue)
        $xs = @(Get-ChildItem $expDir -Filter '*.xlsx' -ErrorAction SilentlyContinue)
        Check '控件：导出动作（无 Excel）→ 只出 CSV、不出 xlsx' ($csvs.Count -eq 1 -and $xs.Count -eq 0) ('csv=' + $csvs.Count + ' xlsx=' + $xs.Count)

        # e) 删除取消分支（用钩子）：Confirm-Delete 返回 False 时不动数据
        $script:SelfTestConfirmResult = $false
        Check '控件：删除取消 → Confirm-Delete 返回 False' ((Confirm-Delete -Title '取消测试') -eq $false)
        $script:SelfTestConfirmResult = $null

        # 0.3.1：必须用**真实 UI 树**（标题条、右下角抓手都是 child HWND）。
        # 0.3.0 用裸 Form 做自检，正是「141/141 假阳性」的来源之一。
        Initialize-Native
        Initialize-ShellNative
        Check 'M5 窗体走 TrayForm（CreateParams 防 WinForms 冲掉穿透位）' ([bool]('DshTodoTray.TrayForm' -as [type]))
        $script:WinCfg = Get-WindowSettings -Config (Read-JsonFile $script:ConfigPath)
        $script:UiSettings = Get-UiSettings -Config (Read-JsonFile $script:ConfigPath)
        $script:InteractMode = $false
        $script:PanelCollapsed = $false
        Initialize-Ui
        $tf = $script:Form
        try { $script:Notify.Visible = $false } catch { }
        $tf.Location = New-Object System.Drawing.Point(200, 200)
        $tf.ClientSize = New-Object System.Drawing.Size(420, 520)
        $script:ChromeLevel = 'none'
        Set-PanelChrome 'none'
        Apply-PanelExStyle
        $exPassive = [DshTodoTray.Win3]::ExStyle($tf.Handle)

        Check 'M5 穿透态 EXSTYLE 含 TRANSPARENT|NOACTIVATE' ((($exPassive -band 0x20) -ne 0) -and (($exPassive -band 0x08000000) -ne 0)) ('实际 0x{0:X8}' -f $exPassive)
        Check 'M5 穿透态 EXSTYLE 含 LAYERED|TOOLWINDOW' ((($exPassive -band 0x80000) -ne 0) -and (($exPassive -band 0x80) -ne 0)) ('实际 0x{0:X8}' -f $exPassive)

        # 悬停：0.3 秒只亮提示边框（仍穿透）→ 0.65 秒进交互态
        $script:Pinned = $true   # 0.3.26：穿透/悬停逻辑只在钉住的面板上测
        $t0 = Get-Date
        Update-PointerState -X 300 -Y 300 -Now $t0
        Check 'M5 悬停刚进入：界面无任何变化（仍穿透、无边框）' ((-not $script:InteractMode) -and $script:ChromeLevel -eq 'none') ('mode=' + $script:InteractMode + ' chrome=' + $script:ChromeLevel)
        Update-PointerState -X 300 -Y 300 -Now $t0.AddMilliseconds(300)
        Check 'M5 悬停 0.3 秒：还没进交互态' (-not $script:InteractMode)
        Update-PointerState -X 300 -Y 300 -Now $t0.AddMilliseconds(1400)
        Check 'M5 悬停 1.4 秒：还没进交互态（0.3.27 默认 1.5 秒）' (-not $script:InteractMode)
        Update-PointerState -X 300 -Y 300 -Now $t0.AddMilliseconds(1600)
        $exActive = [DshTodoTray.Win3]::ExStyle($tf.Handle)
        Check 'M5 悬停 1.6 秒：进交互态 + 实线边框' ($script:InteractMode -and $script:ChromeLevel -eq 'active') ('mode=' + $script:InteractMode + ' chrome=' + $script:ChromeLevel)
        Check 'M5 到点：面板直接 100% 不透明' ([Math]::Abs([double]$tf.Opacity - 1.0) -lt 0.001) ('opacity=' + $tf.Opacity)
        Check 'M5 交互态 EXSTYLE 去掉 TRANSPARENT|NOACTIVATE' ((($exActive -band 0x20) -eq 0) -and (($exActive -band 0x08000000) -eq 0)) ('实际 0x{0:X8}' -f $exActive)
        Check 'M5 交互态仍保留 LAYERED|TOOLWINDOW' ((($exActive -band 0x80000) -ne 0) -and (($exActive -band 0x80) -ne 0)) ('实际 0x{0:X8}' -f $exActive)

        # 移开 1.5 秒回穿透
        $t1 = $t0.AddSeconds(2)
        Update-PointerState -X 5000 -Y 5000 -Now $t1
        Update-PointerState -X 5000 -Y 5000 -Now $t1.AddMilliseconds(1490)
        Check 'M5 移开 1.49 秒：还在交互态' $script:InteractMode
        Update-PointerState -X 5000 -Y 5000 -Now $t1.AddMilliseconds(1600)
        Check 'M5 移开 1.5 秒：回穿透态 + 无边框' ((-not $script:InteractMode) -and $script:ChromeLevel -eq 'none') ('mode=' + $script:InteractMode + ' chrome=' + $script:ChromeLevel)
        $script:Pinned = $false   # 0.3.26：恢复侧边模式，后面的侧边/箭头断言按未钉住跑

        # M6 NCHITTEST（穿透=HTTRANSPARENT / 标题=HTCAPTION / 右下=HTBOTTOMRIGHT）
        $hitPassive = [DshTodoTray.Win3]::HitTest($tf.Handle, 300, 250).ToInt64()
        Check 'M6 穿透态 NCHITTEST = HTTRANSPARENT(-1)' ($hitPassive -eq -1) ('实际 ' + $hitPassive)
        Set-Interactive $true 'selftest'
        $hitCap = [DshTodoTray.Win3]::HitTest($tf.Handle, 260, 220).ToInt64()     # client (60,20)
        $hitCombo = [DshTodoTray.Win3]::HitTest($tf.Handle, 260, 260).ToInt64()   # client (60,60) 清单下拉
        $hitCorner = [DshTodoTray.Win3]::HitTest($tf.Handle, 610, 710).ToInt64()  # client (410,510)
        Check 'M6 交互态标题区 NCHITTEST = HTCAPTION(2)' ($hitCap -eq 2) ('实际 ' + $hitCap)
        Check 'M6 交互态控件区走默认命中（HTCLIENT=1，不抢拖动）' ($hitCombo -eq 1) ('实际 ' + $hitCombo)
        Check 'M6 交互态右下角 NCHITTEST = HTBOTTOMRIGHT(17)' ($hitCorner -eq 17) ('实际 ' + $hitCorner)

        # M8 抵抗 Win+D：连发 3 次 SWP_HIDEWINDOW，全被摘掉
        $blocked = 0
        for ($ii = 0; $ii -lt 3; $ii++) {
            [uint32]$flagsAfter = 0
            if ([DshTodoTray.Win3]::ProbeHide($tf.Handle, [ref]$flagsAfter)) { $blocked++ }
        }
        Check 'M8 连发 3 次 Win+D 隐藏消息全被拦下' ($blocked -eq 3) ('拦下 ' + $blocked + '/3')
        Check 'M8 拦截计数器累计 = 3' ([int]$script:ShellHook.HiddenBlocked -eq 3) ('实际 ' + $script:ShellHook.HiddenBlocked)

        # M6 收边判定（纯函数）：最近边 + 距离；侧边栏纵向居中
        $area = New-Object System.Drawing.Rectangle(0, 0, 1920, 1040)
        $s1 = Get-EdgeSpot -X 5 -W 420 -Area $area
        $s2 = Get-EdgeSpot -X 1494 -W 420 -Area $area      # 右边距 6
        $s3 = Get-EdgeSpot -X 700 -W 420 -Area $area       # 左 700 / 右 800
        $s4 = Get-EdgeSpot -X 11 -W 420 -Area $area        # 左边距 11 > 10
        Check 'M6 收边：距左 5px → left/5' ($s1.Edge -eq 'left' -and $s1.Distance -eq 5) ('edge=' + $s1.Edge + ' d=' + $s1.Distance)
        Check 'M6 收边：距右 6px → right/6' ($s2.Edge -eq 'right' -and $s2.Distance -eq 6) ('edge=' + $s2.Edge + ' d=' + $s2.Distance)
        Check 'M6 收边：离边 700px → 最近边 700（不收）' ($s3.Edge -eq 'left' -and $s3.Distance -eq 700) ('edge=' + $s3.Edge + ' d=' + $s3.Distance)
        Check 'M6 收边：距左 11px > 阈值 10（不收）' ($s4.Distance -eq 11 -and $s4.Distance -gt [int]$script:EdgeTouchPx) ('d=' + $s4.Distance)
        $barMid = Get-BarTop -Y 500 -Area $area
        $barTop = Get-BarTop -Y 0 -Area $area
        $barBot = Get-BarTop -Y 5000 -Area $area
        Check 'M6 侧边栏纵向：鼠标 Y 居中' ($barMid -eq (500 - [int]($script:BarHeight / 2))) ('top=' + $barMid)
        Check 'M6 侧边栏纵向：贴上/下边会被夹住' (($barTop -eq 0) -and ($barBot -eq (1040 - [int]$script:BarHeight))) ('top=' + $barTop + ' bottom=' + $barBot)
        $cl = Get-ClampedSize -W 300 -H 200
        Check 'M6 最小尺寸 300×200 → 320×240' ($cl.W -eq 320 -and $cl.H -eq 240) ('实际 ' + $cl.W + 'x' + $cl.H)

        # M6 老 config 无 ui.window → 默认值，不崩；保存幂等
        $defWin = Get-WindowSettings -Config (Read-JsonFile $script:ConfigPath)
        Check 'M6 老 config 无 ui.window → 默认 420 宽 / edge=none' ($defWin.W -eq 420 -and $defWin.Edge -eq 'none') ('w=' + $defWin.W + ' edge=' + $defWin.Edge)
        [void](Save-WindowSettings -Settings $script:WinCfg)
        $cfgA = ConvertTo-JsonText (Read-JsonFile $script:ConfigPath)
        [void](Save-WindowSettings -Settings $script:WinCfg)
        $cfgB = ConvertTo-JsonText (Read-JsonFile $script:ConfigPath)
        Check 'M6 config.ui.window 连存两次字节一致（幂等）' ($cfgA -eq $cfgB)
        $reWin = Get-WindowSettings -Config (Read-JsonFile $script:ConfigPath)
        Check 'M6 config.ui.window 回读一致' ([int]$reWin.X -eq [int]$script:WinCfg.X -and [int]$reWin.W -eq [int]$script:WinCfg.W) ('x=' + $reWin.X + ' w=' + $reWin.W)

        # M7 收起/展开（-NoShow：不弹窗，只验状态与自动收回截止）
        Initialize-Whale

        # 0.3.4 · B-①/B-②：对鲸鱼句柄读真属性 + 因果，不再用标志位假装
        $wh = $script:Whale
        $wa2 = 0
        $wf2 = [uint32]0
        $wRead = [DshTodoTray.Win3]::ReadAlpha($wh.Handle, [ref]$wa2, [ref]$wf2)
        Check 'B-① 鲸鱼句柄 layered 属性已设（ok / LWA_ALPHA / alpha=255）' ($wRead -and (($wf2 -band 0x2) -ne 0) -and ($wa2 -eq 255)) ('ok=' + $wRead + ' alpha=' + $wa2 + (' flags=0x{0:X}' -f $wf2))

        # 因果：把鲸鱼 alpha 打成 0（复现 0.3.3「有位无属性」），Show-Whale 必须补回来
        [void][DshTodoTray.Win3]::SetLayeredWindowAttributes($wh.Handle, 0, 0, 0x00000002)
        Show-Whale
        $wa3 = 0
        $wf3 = [uint32]0
        $wRead2 = [DshTodoTray.Win3]::ReadAlpha($wh.Handle, [ref]$wa3, [ref]$wf3)
        Check 'B-① 因果：鲸鱼 alpha=0 → Show-Whale 补回 alpha>=1' ($wRead2 -and (($wf3 -band 0x2) -ne 0) -and ($wa3 -ge 1)) ('ok=' + $wRead2 + ' alpha=' + $wa3)
        # 0.3.37：已经显示着的鲸鱼，再 Show 一次也必须重新压到置顶层（以前只在隐藏→显示时抬一次）
        $wExNow = [DshTodoTray.Win3]::ExStyle($wh.Handle)
        Check '0.3.37 鲸鱼每次 Show 都补置顶（WS_EX_TOPMOST）' (($wExNow -band 0x8) -ne 0) ('ex=0x' + ('{0:X}' -f $wExNow))
        # 0.3.38：摆尾曲线（两端归零，中段左右各摆）
        Check '0.3.39 摆尾：四摆（T=0.0625 右摆）' ((Get-WhaleTailOffset -T 0.0625) -gt 0) ('实际 ' + (Get-WhaleTailOffset -T 0.0625))
        Check '0.3.39 摆尾：四摆（T=0.1875 左摆）' ((Get-WhaleTailOffset -T 0.1875) -lt 0) ('实际 ' + (Get-WhaleTailOffset -T 0.1875))
        Check '0.3.39 摆尾：起止都归 0' (((Get-WhaleTailOffset -T 0) -eq 0) -and ((Get-WhaleTailOffset -T 1) -eq 0))
        Check 'B-② 鲸鱼显示后 PanelCollapsed=True（启动收起分支同一路径）' ([bool]$script:PanelCollapsed -and [bool]$wh.Visible)

        # 收起态 → Set-Collapsed $false 必须真的过掉早退（0.3.3 在这里直接 return，连日志都不打）
        Set-Collapsed $false 'selftest-restart' -NoShow
        Check 'B-② 收起态调 Set-Collapsed false 能展开（不再被 early-return 挡住）' (-not $script:PanelCollapsed)
        try { $wh.Hide() } catch { }

        $script:WinCfg.Edge = 'right'
        $script:WinCfg.AutoCollapseSeconds = 3
        Set-Collapsed $true 'selftest' -NoShow
        Check 'M7 收起：PanelCollapsed 置位' $script:PanelCollapsed
        $cw = Get-Prop (Get-Prop (Read-JsonFile $script:ConfigPath) 'ui' $null) 'window' $null
        Check 'M7 收起状态写进 config（重启可还原）' ([bool](Get-Prop $cw 'collapsed' $false))
        Set-Collapsed $false 'selftest' -NoShow
        $cw2 = Get-Prop (Get-Prop (Read-JsonFile $script:ConfigPath) 'ui' $null) 'window' $null
        Check 'M7 展开后 collapsed 落盘为 false' (-not [bool](Get-Prop $cw2 'collapsed' $true))
        $peekOk = ((-not $script:PanelCollapsed) -and $script:PeekExpanded -and $null -ne $script:WhaleDeadline)
        $secs = 0.0
        if ($null -ne $script:WhaleDeadline) { $secs = ($script:WhaleDeadline - (Get-Date)).TotalSeconds }
        Check 'M7 展开：状态复原 + 3 秒自动收回已排程' ($peekOk -and $secs -gt 2 -and $secs -le 3.2) ('剩余 ' + [Math]::Round($secs, 1) + ' 秒')

        # 0.3.2 · D1/D2：用 Show-Panel 的真实几何（ClientSize=560）+ WindowFromPoint 真命中
        $script:UiSettings.Mode = 'always'
        $script:WinCfg.X = 200
        $script:WinCfg.Y = 200
        $script:WinCfg.W = 420
        $script:WinCfg.H = 560
        $script:WinCfg.Edge = 'none'
        $script:WinCfg.Collapsed = $false
        $script:PanelCollapsed = $false
        Show-Panel -Interactive
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 200
        $script:InteractMode = $false
        Set-Interactive $true 'selftest-real'
        $clientScreen = $tf.RectangleToScreen($tf.ClientRectangle)
        Check 'D2 客户区高度 = ClientSize = 560（HWND 客户区与属性一致）' (($tf.ClientSize.Height -eq 560) -and ($clientScreen.Height -eq 560)) ('client=' + $tf.ClientSize.Height + ' screen=' + $clientScreen.Height)

        # 0.3.3 · L0（T20261028-08 根因）：layered 属性必须真的设上，否则整块面板点不到
        $hForm = $tf.Handle
        $a1 = 0
        $f1 = [uint32]0
        $lOk = [DshTodoTray.Win3]::ReadAlpha($hForm, [ref]$a1, [ref]$f1)
        Check 'L0 layered 属性已设（GetLayeredWindowAttributes ok、LWA_ALPHA、alpha≥1）' ($lOk -and (($f1 -band 0x2) -ne 0) -and ($a1 -ge 1)) ('ok=' + $lOk + ' alpha=' + $a1 + (' flags=0x{0:X}' -f $f1))

        # 因果回归（不是布置断言）：把 alpha 打成 0，等于复现 0.3.2「有 LAYERED 位无属性」；
        # 此时底栏采样点应掉到桌面，Apply-PanelExStyle 补属性后应立刻回到面板。
        $midX = $tf.Left + 195
        $midY = $tf.Top + [int]$tf.ClientSize.Height - 8
        [void][DshTodoTray.Win3]::SetLayeredWindowAttributes($hForm, 0, 0, 0x00000002)
        $bugHwnd = [DshTodoTray.Win3]::WindowAt($midX, $midY)
        $bugIsForm = ([DshTodoTray.Win3]::RootOf($bugHwnd) -eq $hForm)
        Apply-PanelExStyle
        [System.Windows.Forms.Application]::DoEvents()
        $fixHwnd = [DshTodoTray.Win3]::WindowAt($midX, $midY)
        $fixIsForm = ([DshTodoTray.Win3]::RootOf($fixHwnd) -eq $hForm)
        Check 'L0 因果回归：alpha=0 → 命中面掉到桌面；补属性 → 立刻回到面板' ((-not $bugIsForm) -and $fixIsForm) (('bug=0x{0:X}(form={1}) fix=0x{2:X}(form={3})') -f $bugHwnd.ToInt64(), $bugIsForm, $fixHwnd.ToInt64(), $fixIsForm)

        # 命中面全高闭合：x=195 正好是底栏「导出」与「刷新」之间的空白（07 诊断漏 40px 的那个位置）
        $miss = @()
        foreach ($cy in @(4, 40, 200, 430, 480, 512, 520, 524, 532, 540, 545, 555, 556)) {
            $hh = [DshTodoTray.Win3]::WindowAt(($tf.Left + 195), ($tf.Top + $cy))
            if ([DshTodoTray.Win3]::RootOf($hh) -ne $hForm) { $miss += ($cy.ToString() + ':0x' + $hh.ToInt64().ToString('X')) }
        }
        Check 'L0 命中面全高闭合（含底栏 40px 空白，13 个采样点无一落到桌面）' ($miss.Count -eq 0) ('漏点 ' + $miss.Count + '：' + ($miss -join ' '))

        # 底栏必须是「有 HWND 的 Panel」铺满，而不是 Form 表面
        $fHit = Get-DeepWindowAt -Root $hForm -X ($tf.Left + 195) -Y ($tf.Top + [int]$tf.ClientSize.Height - 8)
        $fCtl = [System.Windows.Forms.Control]::FromHandle($fHit)
        Check 'L0 底栏有真实 HWND（空白处命中的是底栏 Panel，不是 Form 表面）' (($null -ne $fCtl) -and ($fCtl -eq $script:Foot) -and ($fHit -ne $hForm)) (('hit=0x{0:X} ctl={1}') -f $fHit.ToInt64(), $(if ($null -ne $fCtl) { $fCtl.GetType().Name } else { 'null' }))

        # 三个高度都要闭合（07 诊断：H=500 缺口 0、H=560 缺 40、H=620 缺 70）
        $hgtBad = @()
        foreach ($hgt in @(500, 620, 560)) {
            $tf.ClientSize = New-Object System.Drawing.Size(420, $hgt)
            try { if ($null -ne $script:Layout) { $script:Layout.PerformLayout() } } catch { }
            [System.Windows.Forms.Application]::DoEvents()
            Position-DragGrip
            Apply-PanelExStyle
            foreach ($cy in @(4, 200, ($hgt - 60), ($hgt - 41), ($hgt - 20), ($hgt - 4))) {
                $hh = [DshTodoTray.Win3]::WindowAt(($tf.Left + 195), ($tf.Top + $cy))
                if ([DshTodoTray.Win3]::RootOf($hh) -ne $hForm) { $hgtBad += ('H' + $hgt + '/y' + $cy) }
            }
        }
        Check 'L0 三个高度（500/560/620）命中面都闭合' ($hgtBad.Count -eq 0) ('漏 ' + $hgtBad.Count + '：' + ($hgtBad -join ' '))
        Position-DragGrip

        $px = $tf.Left + 60
        $py = $tf.Top + 20
        $wfp = [DshTodoTray.Win3]::WindowAt($px, $py)
        Check 'D1 真鼠标点最终落在面板（WindowFromPoint 根=面板）' ([DshTodoTray.Win3]::RootOf($wfp) -eq $tf.Handle) ('wfp=0x{0:X}' -f $wfp.ToInt64())
        $hitReal = Get-DeepWindowAt -Root $tf.Handle -X $px -Y $py
        $hitRoot = [DshTodoTray.Win3]::RootOf($hitReal)
        Check 'D1 标题区命中的是真子控件（不是 Form 本身）' (($hitReal -ne [IntPtr]::Zero) -and ($hitReal -ne $tf.Handle) -and ($hitRoot -eq $tf.Handle)) ('hit=0x{0:X} root=0x{1:X} form=0x{2:X}' -f $hitReal.ToInt64(), $hitRoot.ToInt64(), $tf.Handle.ToInt64())

        # 0.3.6 · D1/D2 拖动与缩放：直接把坐标喂给状态机
        # （真实鼠标路径 = 标题条/抓手 MouseDown 起手 + 20ms DragTimer 轮询，见文件上部注释）
        # D2 抓手仍然是 0.3.3 修好的状态：Enabled、挂在 Form 上、真实命中面命中它本身
        $gx = $tf.Left + [int]$tf.ClientSize.Width - 9
        $gy = $tf.Top + [int]$tf.ClientSize.Height - 9
        Check 'D2 抓手 Enabled 且 Parent=Form（z-order 在底栏之上）' ($script:DragGrip.Enabled -and ($script:DragGrip.Parent -eq $tf)) ('enabled=' + $script:DragGrip.Enabled)
        $gripReal = [DshTodoTray.Win3]::WindowAt($gx, $gy)
        $gripCtl = [System.Windows.Forms.Control]::FromHandle($gripReal)
        Check 'D2 抓手在真实命中面内（WindowFromPoint 命中抓手本身）' (($null -ne $gripCtl) -and ($gripCtl -eq $script:DragGrip)) ('hit=0x{0:X}' -f $gripReal.ToInt64())
        Check 'D2 抓手光标形状 = SizeNWSE' ($script:DragGrip.Cursor.Handle -eq [System.Windows.Forms.Cursors]::SizeNWSE.Handle)

        $sw0 = [int]$tf.Width
        $sh0 = [int]$tf.Height
        $gx0 = $tf.Left + $sw0 - 9
        $gy0 = $tf.Top + $sh0 - 9
        Start-PanelDrag -Mode 'size' -X $gx0 -Y $gy0
        Update-PanelDrag -X ($gx0 + 60) -Y ($gy0 + 40)
        Check 'D2 抓手缩放：宽高 +60/+40' (([int]$tf.Width -eq ($sw0 + 60)) -and ([int]$tf.Height -eq ($sh0 + 40))) ('实际 ' + $tf.Width + 'x' + $tf.Height)
        Update-PanelDrag -X ($gx0 - 600) -Y ($gy0 - 600)
        Check 'D2 最小尺寸：拖到 320×240 停住' (([int]$tf.Width -eq 320) -and ([int]$tf.Height -eq 240)) ('实际 ' + $tf.Width + 'x' + $tf.Height)
        End-PanelDrag

        $r0 = [DshTodoTray.Win3]::RectOf($tf.Handle)
        $grabX = $tf.Left + 100
        $grabY = $tf.Top + 20
        Start-PanelDrag -Mode 'move' -X $grabX -Y $grabY
        Check 'D1 按标题条 → 拖动会话建立（window 态）' (($null -ne $script:PanelDrag) -and ([string]$script:PanelDrag.Phase -eq 'window'))
        Update-PanelDrag -X ($grabX + 80) -Y ($grabY + 40)
        $r1 = [DshTodoTray.Win3]::RectOf($tf.Handle)
        Check 'D1 拖动跟手：窗口位置 +80/+40' (((($r1[0] - $r0[0]) -eq 80)) -and (($r1[1] - $r0[1]) -eq 40)) ('before=' + $r0[0] + ',' + $r0[1] + ' after=' + $r1[0] + ',' + $r1[1])

        # ① 碰右边 → 不用松手，立刻收成侧边栏；纵向 = 鼠标 Y 居中
        $waNow = Get-ScreenArea
        $offX = [int]$script:PanelDrag.OffX
        $edgeX = $waNow.Right - 5 - [int]$tf.Width + $offX
        $edgeY = $tf.Top + 200
        Update-PanelDrag -X $edgeX -Y $edgeY
        # 0.3.19：侧边条从「碰边时面板的中心」起手，不再是鼠标 Y 居中
        $barTopWant = [int]($tf.Top + [Math]::Floor($tf.Height / 2) - 36)
        if ($barTopWant -lt [int]$waNow.Top) { $barTopWant = [int]$waNow.Top }
        if ($barTopWant -gt [int]($waNow.Bottom - 72)) { $barTopWant = [int]($waNow.Bottom - 72) }
        Check 'D1 碰右边 → 立刻收成侧边栏（面板隐藏 / 鲸鱼出现）' (([string]$script:PanelDrag.Phase -eq 'bar') -and $script:PanelCollapsed -and (-not $tf.Visible) -and $script:Whale.Visible) ('phase=' + $script:PanelDrag.Phase + ' formVisible=' + $tf.Visible + ' whale=' + $script:Whale.Visible)
        Check 'D1 侧边栏贴右边 + 纵向 = 面板中心（从原位起手）' ((($script:Whale.Left + $script:Whale.Width) -eq $waNow.Right) -and ($script:Whale.Top -eq $barTopWant)) ('right=' + ($script:Whale.Left + $script:Whale.Width) + ' top=' + $script:Whale.Top + ' want=' + $barTopWant)

        # ② 按住不放上下拖 → 侧边栏按鼠标位移跟手
        Update-PanelDrag -X $edgeX -Y ($edgeY + 120)
        $barTopWant2 = $barTopWant + 120
        if ($barTopWant2 -lt [int]$waNow.Top) { $barTopWant2 = [int]$waNow.Top }
        if ($barTopWant2 -gt [int]($waNow.Bottom - 72)) { $barTopWant2 = [int]($waNow.Bottom - 72) }
        Check 'D1 按住上下拖：侧边栏按鼠标位移跟手' ($script:Whale.Top -eq $barTopWant2) ('top=' + $script:Whale.Top + ' want=' + $barTopWant2)

        # ③ 拖离边 > 60px → 恢复成窗口（还按着，继续跟手）
        $pullX = $edgeX - ([int]$script:EdgeLeavePx + 10)
        Update-PanelDrag -X $pullX -Y ($edgeY + 120)
        Check 'D2 拖离边 >60px → 恢复成窗口（鲸鱼隐藏 / 面板可见 / 仍跟手）' (([string]$script:PanelDrag.Phase -eq 'window') -and (-not $script:PanelCollapsed) -and $tf.Visible -and (-not $script:Whale.Visible) -and ($tf.Left -eq ($pullX - $offX))) ('phase=' + $script:PanelDrag.Phase + ' left=' + $tf.Left + ' want=' + ($pullX - $offX))

        # ④ 松手 → 窗口几何落盘
        End-PanelDrag
        $cwWin = Get-Prop (Get-Prop (Read-JsonFile $script:ConfigPath) 'ui' $null) 'window' $null
        Check 'D2 松手（窗口态）：会话结束 + edge=none / collapsed=false 落盘' (($null -eq $script:PanelDrag) -and ([string](Get-Prop $cwWin 'edge' 'x') -eq 'none') -and (-not [bool](Get-Prop $cwWin 'collapsed' $true))) ('edge=' + (Get-Prop $cwWin 'edge' 'x') + ' collapsed=' + (Get-Prop $cwWin 'collapsed' $true))

        # ⑤ 再拖到右边直接松手 → 侧边栏就地固定（不再有松手吸附）
        $grabX2 = $tf.Left + 100
        $grabY2 = $tf.Top + 20
        Start-PanelDrag -Mode 'move' -X $grabX2 -Y $grabY2
        $offX2 = [int]$script:PanelDrag.OffX
        $edgeX2 = $waNow.Right - 5 - [int]$tf.Width + $offX2
        Update-PanelDrag -X $edgeX2 -Y ($waNow.Top + 300)
        End-PanelDrag
        $cwBar = Get-Prop (Get-Prop (Read-JsonFile $script:ConfigPath) 'ui' $null) 'window' $null
        Check 'D3 碰边松手：侧边栏就地固定（collapsed=true / edge=right / whaleY 落盘）' ([bool](Get-Prop $cwBar 'collapsed' $false) -and ([string](Get-Prop $cwBar 'edge' '') -eq 'right') -and ([int](Get-Prop $cwBar 'whaleY' -1) -eq [int]$script:Whale.Top)) ('collapsed=' + (Get-Prop $cwBar 'collapsed' $false) + ' edge=' + (Get-Prop $cwBar 'edge' '') + ' whaleY=' + (Get-Prop $cwBar 'whaleY' -1) + ' whaleTop=' + $script:Whale.Top)

        # 复位：展开面板，后面 M4-3 还要用
        $script:WinCfg.Edge = 'none'
        Set-Collapsed $false 'selftest-restore' -NoShow
        Show-Panel -Interactive
        $tf.ClientSize = New-Object System.Drawing.Size(420, 560)
        try { if ($null -ne $script:Layout) { $script:Layout.PerformLayout() } } catch { }
        Position-DragGrip
        [System.Windows.Forms.Application]::DoEvents()

        # 0.3.5 · M4-3：DoneFadeTimer 首拍自停的回归（真等待，不 mock）
        # 独立数据，别受前面用例影响；面板此刻是可见的（D2 刚缩到 320×240）
        $script:FilterListIndex = -1
        $script:FilterText = ''
        $fadeDoc = [ordered]@{
            version = 1
            scope = 'selftest'
            name = '自检清单'
            updatedAt = (Get-NowStamp)
            items = @(
                [ordered]@{ id = 'fade-a'; title = '淡出A'; status = 'todo'; due = ''; prio = 1; order = 0; tags = @(); created = (Get-NowStamp); done_at = '' },
                [ordered]@{ id = 'fade-b'; title = '淡出B'; status = 'todo'; due = ''; prio = 1; order = 1; tags = @(); created = (Get-NowStamp); done_at = '' }
            )
        }
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText $fadeDoc) + "`n")
        $script:JustDone.Clear()
        $script:DoneFadeAt.Clear()
        Refresh-All
        $dbgState = Load-State
        $dbgIds = (@($dbgState.Entries) | ForEach-Object { $_.ItemId + ':' + $_.Status }) -join ','
        $dbgFiltered = @(Get-FilteredEntries -State $dbgState)
        $dbgDirect = @($dbgFiltered | Where-Object { [string]$_.ItemId -eq 'fade-a' })
        $script:SelfTestMessages.Add(('  [INFO] M4-3 debug entries=' + @($dbgState.Entries).Count + ' ids=' + $dbgIds + ' filtered=' + $dbgFiltered.Count + ' direct=' + $dbgDirect.Count + ' idx=' + $script:FilterListIndex + ' q=[' + $script:FilterText + '] data=' + $dataPath)) | Out-Null
        function Test-FadeVisible {
            param([string]$Id)
            $arr = @(Get-FilteredEntries -State (Load-State))
            $hit = @($arr | Where-Object { [string]$_.ItemId -eq $Id })
            return ($hit.Count -gt 0)
        }
        Check 'M4-3 前置：两项 todo 都在列表' ((Test-FadeVisible 'fade-a') -and (Test-FadeVisible 'fade-b'))

        $cbFadeA = New-Object System.Windows.Forms.CheckBox
        $cbFadeA.Tag = [pscustomobject]@{ ListIndex = 0; ItemId = 'fade-a' }
        $cbFadeA.Checked = $true
        $tFadeA = Get-Date
        On-CheckChanged -Sender $cbFadeA
        $dlFade = (Get-Date).AddSeconds(8)
        while ((Get-Date) -lt $dlFade) {
            [System.Windows.Forms.Application]::DoEvents()
            if (-not $script:DoneFadeAt.ContainsKey('0|fade-a')) { break }
            Start-Sleep -Milliseconds 100
        }
        $eFadeA = ((Get-Date) - $tFadeA).TotalSeconds
        Check 'M4-3 勾掉一项 → ≤6.5 秒从列表消失（1s 定时器粒度、目标 5s；不再首拍自停）' ((-not (Test-FadeVisible 'fade-a')) -and (-not $script:DoneFadeAt.ContainsKey('0|fade-a')) -and ($eFadeA -le 6.5)) ('elapsed=' + [Math]::Round($eFadeA, 2) + 's')
        $afterDoc = Read-JsonFile $dataPath
        $afterItems = @(Get-Prop $afterDoc 'items' @() | Where-Object { [string](Get-Prop $_ 'id' '') -eq 'fade-a' })
        $afterStatus = if ($afterItems.Count -gt 0) { [string](Get-Prop $afterItems[0] 'status' '') } else { '' }
        Check 'M4-3 消失后 todos.json 仍是 done' ($afterStatus -eq 'done') ('status=' + $afterStatus)
        $expDirFade = Join-Path $tmp 'fade_export'
        $expFade = Export-TodoTable -Kind 'done' -Format 'csv' -Dir $expDirFade -DisableXlsxForTest
        $expText = [System.IO.File]::ReadAllText([string]$expFade.Path, [System.Text.Encoding]::UTF8)
        Check 'M4-3 导出仍含已消失的 done 项（与 M4-4 口径一致）' ($expText.Contains('淡出A'))

        # 连勾两项（间隔 2 秒）：各自从被勾时刻算 5 秒，不串、不提前
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText $fadeDoc) + "`n")
        $script:JustDone.Clear()
        $script:DoneFadeAt.Clear()
        Refresh-All
        $cbFadeA2 = New-Object System.Windows.Forms.CheckBox
        $cbFadeA2.Tag = [pscustomobject]@{ ListIndex = 0; ItemId = 'fade-a' }
        $cbFadeA2.Checked = $true
        $t0Fade = Get-Date
        On-CheckChanged -Sender $cbFadeA2
        Start-Sleep -Milliseconds 2000
        $cbFadeB2 = New-Object System.Windows.Forms.CheckBox
        $cbFadeB2.Tag = [pscustomobject]@{ ListIndex = 0; ItemId = 'fade-b' }
        $cbFadeB2.Checked = $true
        $tBFade = Get-Date
        On-CheckChanged -Sender $cbFadeB2
        $goneA = $null; $goneB = $null
        $dlFade2 = (Get-Date).AddSeconds(10)
        while ((Get-Date) -lt $dlFade2) {
            [System.Windows.Forms.Application]::DoEvents()
            if (($null -eq $goneA) -and (-not (Test-FadeVisible 'fade-a'))) { $goneA = Get-Date }
            if (($null -eq $goneB) -and (-not (Test-FadeVisible 'fade-b'))) { $goneB = Get-Date }
            if (($null -ne $goneA) -and ($null -ne $goneB)) { break }
            Start-Sleep -Milliseconds 100
        }
        $gapFade = if (($null -ne $goneA) -and ($null -ne $goneB)) { ($goneB - $goneA).TotalSeconds } else { -1 }
        # 1s 粒度定时器：勾选间隔 2s 时，两条消失的间隔允许 1~3s（下限 0.8 防抖动误报）
        Check 'M4-3 连勾两项：各自从被勾时刻算（间隔≈2s，不提前）' (($null -ne $goneA) -and ($null -ne $goneB) -and ($gapFade -ge 0.8) -and ($gapFade -le 3.5)) ('gap=' + [Math]::Round($gapFade, 2) + 's A=' + $(if ($null -ne $goneA) { [Math]::Round(($goneA - $t0Fade).TotalSeconds, 2) } else { -1 }) + 's B=' + $(if ($null -ne $goneB) { [Math]::Round(($goneB - $tBFade).TotalSeconds, 2) } else { -1 }) + 's')
        Check 'M4-3 连勾两项都 ≤6.5 秒（1s 定时器粒度、目标 5s；各自计时）' (($null -ne $goneA) -and (($goneA - $t0Fade).TotalSeconds -le 6.5) -and ($null -ne $goneB) -and (($goneB - $tBFade).TotalSeconds -le 6.5)) ('A=' + $(if ($null -ne $goneA) { [Math]::Round(($goneA - $t0Fade).TotalSeconds, 2) } else { -1 }) + 's B=' + $(if ($null -ne $goneB) { [Math]::Round(($goneB - $tBFade).TotalSeconds, 2) } else { -1 }) + 's')

        # 关面板再开：已消失的 done 项不复活（Show-Panel 会清 JustDone/DoneFadeAt，done 被过滤）
        Hide-Panel
        Show-Panel
        Check 'M4-3 关面板再开：已消失的 done 项不复活' ((-not (Test-FadeVisible 'fade-a')) -and (-not (Test-FadeVisible 'fade-b')))

        # 0.3.6：走真实控件路径 —— 编辑态点行上的真 🗑（Tag → Invoke-DeleteEntry → 确认框 → 真删）
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText ([ordered]@{
            version = 1
            items = @([ordered]@{ id = 'ui-del-1'; title = '点我删'; status = 'todo'; due = ''; prio = 1; order = 0; tags = @(); created = ''; done_at = '' })
        })) + "`n")
        $script:JustDone.Clear()
        $script:DoneFadeAt.Clear()
        $script:FilterListIndex = -1
        $script:FilterText = ''
        $script:UiSettings.Mode = 'always'
        Show-Panel -Interactive
        $script:EditMode = $true
        Refresh-All
        $delBtn = $null
        foreach ($row in @($script:Flow.Controls)) {
            foreach ($c in @($row.Controls)) {
                if (($c -is [System.Windows.Forms.Button]) -and ($c.Text -eq '🗑')) { $delBtn = $c; break }
            }
            if ($null -ne $delBtn) { break }
        }
        Check 'D3 编辑态行内有真 🗑 按钮' ($null -ne $delBtn)
        $script:SelfTestConfirmResult = $true
        $script:PendingDeletes = @()
        if ($null -ne $delBtn) { $delBtn.PerformClick() }
        $script:SelfTestConfirmResult = $null
        $docUi = Read-JsonFile $dataPath
        $left = @(@(Get-Prop $docUi 'items' @()) | Where-Object { [string](Get-Prop $_ 'id' '') -eq 'ui-del-1' }).Count
        Check 'D3 行内 🗑 确认后 → 条目真的删了' ($left -eq 0) ('left=' + $left)
        Check 'D3 行内 🗑 确认后 → 出现「已删除 + 撤销」行' (@($script:PendingDeletes).Count -eq 1)
        $script:EditMode = $false

        # 0.3.6：小窗口开着时，大面板不收起、不倒计时；关掉之后重新计时
        $script:SelfTestPointerInside = $false
        $script:UiSettings = [pscustomobject]@{ Mode = 'auto'; HideSeconds = 15; Opacity = 100; TopMost = $true }
        $script:PanelCollapsed = $false
        Show-Panel
        $script:PeekExpanded = $true
        $script:WinCfg.AutoCollapseSeconds = 3
        $script:WhaleDeadline = (Get-Date).AddMilliseconds(-10)   # 已到点
        Enter-ChildWindow
        $script:WhaleTimer.Start()
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 400
        [System.Windows.Forms.Application]::DoEvents()
        Check '小窗开着：到点的自动收回不执行（面板还在）' ($tf.Visible -and (-not $script:PanelCollapsed))
        Check '小窗开着：自动隐藏定时器不跑' (-not $script:AutoHideTimer.Enabled)
        Hide-Panel
        Check '小窗开着：隐藏请求被挡住（面板仍可见）' $tf.Visible
        $script:WhaleDeadline = (Get-Date).AddMilliseconds(-10)
        Exit-ChildWindow
        $secs2 = 0.0
        if ($null -ne $script:WhaleDeadline) { $secs2 = ($script:WhaleDeadline - (Get-Date)).TotalSeconds }
        Check '小窗关掉：自动收回重新计时（≈3 秒）' ($secs2 -gt 2 -and $secs2 -le 3.2) ('剩余 ' + [Math]::Round($secs2, 1))
        Check '小窗关掉：自动隐藏重新计时' ($script:AutoHideTimer.Enabled)
        $script:PeekExpanded = $false
        $script:WhaleDeadline = $null
        if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Stop() } catch { } }
        Stop-AutoHide

        # 0.3.10：弹窗开着时不改面板状态/EXSTYLE（否则会把输入焦点从弹窗抢走）
        $script:InteractMode = $false
        $script:ChildOpen = 1
        $exBefore = [DshTodoTray.Win3]::ExStyle($tf.Handle)
        Set-Interactive $true 'selftest-child'
        $exAfter = [DshTodoTray.Win3]::ExStyle($tf.Handle)
        Check '弹窗开着：Set-Interactive 不改态、不动 EXSTYLE' ((-not $script:InteractMode) -and ($exBefore -eq $exAfter)) ('before=0x{0:X8} after=0x{1:X8}' -f $exBefore, $exAfter)
        Update-PointerState -X ($tf.Left + 10) -Y ($tf.Top + 10) -Now (Get-Date)
        Update-PointerState -X ($tf.Left + 10) -Y ($tf.Top + 10) -Now ((Get-Date).AddMilliseconds(800))
        Check '弹窗开着：悬停 0.8 秒也不切交互态' (-not $script:InteractMode)
        $script:ChildOpen = 0

        # 0.3.8：鼠标在面板里 → 不启动自动隐藏、到点也不自动收回；离开才重新计时
        $script:Pinned = $true   # 0.3.26：指针状态逻辑只在钉住面板上生效
        $script:SelfTestPointerInside = $true
        $script:PanelCollapsed = $false
        Show-Panel
        Check '鼠标在面板里：不启动自动隐藏倒计时' (-not $script:AutoHideTimer.Enabled)
        $script:PeekExpanded = $true
        $script:WinCfg.AutoCollapseSeconds = 3
        $script:WhaleDeadline = (Get-Date).AddMilliseconds(-10)
        $script:WhaleTimer.Start()
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 400
        [System.Windows.Forms.Application]::DoEvents()
        Check '鼠标在面板里：到点也不自动收回' ((-not $script:PanelCollapsed) -and $tf.Visible)
        $script:SelfTestPointerInside = $false
        Update-PointerState -X ($tf.Left + 10) -Y ($tf.Top + 10)   # 先模拟"进入"（置 HoverSince）
        Update-PointerState -X 5000 -Y 5000                        # 再"离开"→ 起算
        $secs3 = 0.0
        if ($null -ne $script:WhaleDeadline) { $secs3 = ($script:WhaleDeadline - (Get-Date)).TotalSeconds }
        Check '鼠标离开面板：自动隐藏开始倒计时' ($script:AutoHideTimer.Enabled)
        Check '鼠标离开面板：自动收回重新计时（≈3 秒）' ($secs3 -gt 2 -and $secs3 -le 3.2) ('剩余 ' + [Math]::Round($secs3, 1))
        $script:Pinned = $false
        $script:SelfTestPointerInside = $null
        $script:PeekExpanded = $false
        $script:WhaleDeadline = $null
        if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Stop() } catch { } }
        Stop-AutoHide

        # 0.3.11：小鲸鱼冒泡
        $iv = Get-BubbleIntervalSeconds
        Check '冒泡间隔：落在 10~60 秒' (($iv -ge 10) -and ($iv -le 60)) ('iv=' + $iv)
        $script:SelfTestForceBubble = $true   # 下面直接调 Show-Bubble 验外观，不经过 Tick 的可见性判断
        Save-TextAtomic -Path $dataPath -Text ((ConvertTo-JsonText ([ordered]@{
            version = 1
            items = @(
                [ordered]@{ id = 'b1'; title = '普通1'; status = 'todo'; prio = 1; order = 0; tags = @() },
                [ordered]@{ id = 'b2'; title = '黄2'; status = 'todo'; prio = 2; order = 0; tags = @() },
                [ordered]@{ id = 'b3'; title = '红3'; status = 'todo'; prio = 3; order = 0; tags = @() }
            )
        })) + "`n")
        $script:BubbleIndex = 0
        $bb1 = Get-BubbleEntry
        $bb2 = Get-BubbleEntry
        $bb3 = Get-BubbleEntry
        $bb4 = Get-BubbleEntry
        Check '冒泡顺序：3★ → 2★ → 普通 → 回到 3★' (([int]$bb1.Prio -eq 3) -and ([int]$bb2.Prio -eq 2) -and ([int]$bb3.Prio -eq 1) -and ([int]$bb4.Prio -eq 3)) ('顺序=' + $bb1.Prio + ',' + $bb2.Prio + ',' + $bb3.Prio + ',' + $bb4.Prio)
        Initialize-Bubble
        Show-Bubble -Entry $bb1
        $bhEx = [DshTodoTray.Win3]::ExStyle($script:Bubble.Handle)
        Check '冒泡窗：穿透 + 不激活 + 不进 Alt+Tab（TRANSPARENT|NOACTIVATE|LAYERED|TOOLWINDOW）' ((($bhEx -band 0x20) -ne 0) -and (($bhEx -band 0x08000000) -ne 0) -and (($bhEx -band 0x80000) -ne 0) -and (($bhEx -band 0x80) -ne 0)) ('实际 0x{0:X8}' -f $bhEx)
        # 0.3.33：全屏置顶程序压不住——冒泡要带 WS_EX_TOPMOST
        Check '冒泡窗：置顶（WS_EX_TOPMOST，全屏程序压不住）' (($bhEx -band 0x8) -ne 0) ('实际 0x{0:X8}' -f $bhEx)
        $ba = 0
        $bf = [uint32]0
        $bRead = [DshTodoTray.Win3]::ReadAlpha($script:Bubble.Handle, [ref]$ba, [ref]$bf)
        Check '冒泡窗：不透明（alpha=255）' ($bRead -and ($ba -eq 255)) ('alpha=' + $ba)
        $secsB = 0.0
        if ($null -ne $script:BubbleHideAt) { $secsB = ($script:BubbleHideAt - (Get-Date)).TotalSeconds }
        Check '冒泡：显示 6 秒（截止时间≈6 秒）' ($script:Bubble.Visible -and ($secsB -gt 4.5) -and ($secsB -le 6.2)) ('剩余 ' + [Math]::Round($secsB, 1))
        Hide-Bubble
        Check '冒泡：可以立刻收起' (-not $script:Bubble.Visible)
        $okBub = Save-UiSettings -Settings ([pscustomobject]@{ Mode = 'auto'; HideSeconds = 15; Opacity = 100; TopMost = $true; BubbleEnabled = $false; BubbleMaxSeconds = 30 })
        $uiBub = Get-UiSettings -Config (Read-JsonFile $script:ConfigPath)
        Check '冒泡设置：关闭 + 最长 30 秒能存能读' ($okBub -and (-not $uiBub.BubbleEnabled) -and ([int]$uiBub.BubbleMaxSeconds -eq 30)) ('on=' + $uiBub.BubbleEnabled + ' max=' + $uiBub.BubbleMaxSeconds)
        # 0.3.37：冒泡边框按星级上色（普通蓝 / 2★ 橙 / 3★ 红）
        $cN = Get-BubbleEdgeColor -Prio 1
        $c2 = Get-BubbleEdgeColor -Prio 2
        $c3 = Get-BubbleEdgeColor -Prio 3
        Check '0.3.37 冒泡边框：普通=蓝（B>R）' ($cN.B -gt $cN.R) ('R=' + $cN.R + ' B=' + $cN.B)
        Check '0.3.37 冒泡边框：3★=红（R>B）/ 2★=橙（R>G>B）' (($c3.R -gt $c3.B) -and ($c2.R -gt $c2.G) -and ($c2.G -gt $c2.B)) ('3★ R=' + $c3.R + ' B=' + $c3.B + ' / 2★ R=' + $c2.R + ' G=' + $c2.G)
        [void](Save-UiSettings -Settings ([pscustomobject]@{ Mode = 'auto'; HideSeconds = 15; Opacity = 100; TopMost = $true; BubbleEnabled = $true; BubbleMaxSeconds = 60 }))

        $script:SelfTestForceBubble = $null   # 恢复真实判断

        # 0.3.12 · ② 冒泡跟随主界面选中的清单
        $cfgBackupText = [System.IO.File]::ReadAllText($script:ConfigPath)
        $wsA = Join-Path $tmp 'wsA'
        $wsB = Join-Path $tmp 'wsB'
        foreach ($w in @($wsA, $wsB)) {
            if (-not (Test-Path -LiteralPath $w)) { New-Item -ItemType Directory -Path $w -Force | Out-Null }
        }
        $docA = [ordered]@{ version = 1; scope = 'a'; name = 'A清单'; updatedAt = (Get-NowStamp); items = @(
            [ordered]@{ id = 'a1'; title = 'A清单1'; status = 'todo'; prio = 1; order = 0; tags = @() },
            [ordered]@{ id = 'a2'; title = 'A清单2'; status = 'todo'; prio = 1; order = 1; tags = @() }
        ) }
        $docB = [ordered]@{ version = 1; scope = 'b'; name = 'B清单'; updatedAt = (Get-NowStamp); items = @(
            [ordered]@{ id = 'b1'; title = 'B清单1'; status = 'todo'; prio = 2; order = 0; tags = @() }
        ) }
        Save-TextAtomic -Path (Join-Path $wsA 'todos.json') -Text ((ConvertTo-JsonText $docA) + "`n")
        Save-TextAtomic -Path (Join-Path $wsB 'todos.json') -Text ((ConvertTo-JsonText $docB) + "`n")
        $cfgTwo = [ordered]@{
            version = 1
            lists   = @(
                [ordered]@{ id = 'a'; name = 'A清单'; todos = 'wsA\todos.json' },
                [ordered]@{ id = 'b'; name = 'B清单'; todos = 'wsB\todos.json' }
            )
        }
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfgTwo) + "`n")
        $script:FilterListIndex = 0
        $script:BubbleIndex = 0
        $onlyA = $true
        for ($i = 0; $i -lt 4; $i++) {
            $eb = Get-BubbleEntry
            if ($null -eq $eb -or [int]$eb.ListIndex -ne 0) { $onlyA = $false }
        }
        Check '冒泡跟随清单：选中 A清单 → 只冒 A 的' $onlyA
        $script:FilterListIndex = 1
        $script:BubbleIndex = 0
        $onlyB = $true
        for ($i = 0; $i -lt 3; $i++) {
            $eb = Get-BubbleEntry
            if ($null -eq $eb -or [int]$eb.ListIndex -ne 1) { $onlyB = $false }
        }
        Check '冒泡跟随清单：选中 B清单 → 只冒 B 的' $onlyB
        $script:FilterListIndex = -1
        $script:BubbleIndex = 0
        $seenLists = @{}
        for ($i = 0; $i -lt 4; $i++) {
            $eb = Get-BubbleEntry
            if ($null -ne $eb) { $seenLists[[int]$eb.ListIndex] = $true }
        }
        Check '冒泡跟随清单：选「全部清单」→ 两个清单都轮到' ($seenLists.ContainsKey(0) -and $seenLists.ContainsKey(1)) ('seen=' + (($seenLists.Keys | Sort-Object) -join ','))

        # 0.3.12 · ① 新建清单（Add-TrayList：建 .todo\todos.json + 登记 config）
        $wsNew = Join-Path $tmp '新建清单测试'
        New-Item -ItemType Directory -Path $wsNew -Force | Out-Null
        $err1 = Add-TrayList -Name '自检新清单' -Folder $wsNew
        $listsNow = @(Get-Lists)
        $newPath = Join-Path $wsNew '.todo\todos.json'
        Check '新建清单：建文件 + 登记 config' (([string]::IsNullOrWhiteSpace($err1)) -and ($listsNow.Count -eq 3) -and (Test-Path -LiteralPath $newPath)) ('err=' + $err1 + ' lists=' + $listsNow.Count)
        $docNew = Read-JsonFile $newPath
        Check '新建清单：新清单是空清单（items=0）' (($null -ne $docNew) -and (@(Get-Prop $docNew 'items' @()).Count -eq 0))
        $err2 = Add-TrayList -Name '自检新清单' -Folder $wsA
        Check '新建清单：重名拒绝' ($err2 -like '*重复*') ('err=' + $err2)
        $err3 = Add-TrayList -Name '另一个名字' -Folder $wsNew
        Check '新建清单：同一文件夹重复拒绝' ($err3 -like '*已经是清单*') ('err=' + $err3)
        $err4 = Add-TrayList -Name '' -Folder $wsNew
        Check '新建清单：空名拒绝' ($err4 -like '*不能为空*') ('err=' + $err4)
        Update-ListCombo -ListIndex 0
        $comboOk = ($null -ne $script:CbList) -and ($script:CbList.Items.Count -eq ($listsNow.Count + 3)) -and ([int]$script:CbList.SelectedIndex -eq 1) -and ([int]$script:FilterListIndex -eq 0)
        Check '清单下拉：全部 + N 个清单 + 新建入口，选择映射正确' $comboOk ('items=' + $(if ($null -ne $script:CbList) { $script:CbList.Items.Count } else { -1 }) + ' sel=' + $(if ($null -ne $script:CbList) { $script:CbList.SelectedIndex } else { -1 }) + ' idx=' + $script:FilterListIndex)

        # 0.3.13 · 清单改名 / 移除
        $listsPre = @(Get-Lists)
        $errR1 = Rename-TrayList -Id ([string]$listsPre[0].Id) -Name 'A改名'
        $afterR = @(Get-Lists)
        $docAR = Read-JsonFile (Join-Path $wsA 'todos.json')
        Check '改名：config 与数据文件都改了' (([string]::IsNullOrWhiteSpace($errR1)) -and ([string]$afterR[0].Name -eq 'A改名') -and ([string](Get-Prop $docAR 'name' '') -eq 'A改名')) ('err=' + $errR1 + ' name=' + $afterR[0].Name)
        $errR2 = Rename-TrayList -Id ([string]$afterR[0].Id) -Name 'B清单'
        Check '改名：重名拒绝' ($errR2 -like '*重复*') ('err=' + $errR2)
        $errR3 = Rename-TrayList -Id ([string]$afterR[0].Id) -Name '   '
        Check '改名：空名拒绝' ($errR3 -like '*不能为空*') ('err=' + $errR3)
        $errD1 = Remove-TrayList -Id ([string]$afterR[2].Id)
        $afterD = @(Get-Lists)
        Check '移除：配置少一条，数据文件保留' (([string]::IsNullOrWhiteSpace($errD1)) -and ($afterD.Count -eq 2) -and (Test-Path -LiteralPath $newPath)) ('err=' + $errD1 + ' lists=' + $afterD.Count)
        $errD2 = Remove-TrayList -Id ([string]$afterD[1].Id)
        $afterD2 = @(Get-Lists)
        $errD3 = Remove-TrayList -Id ([string]$afterD2[0].Id)
        Check '移除：最后一个清单不能删' (($afterD2.Count -eq 1) -and ($errD3 -like '*至少保留*')) ('lists=' + $afterD2.Count + ' err=' + $errD3)

        # 复位：config 回原样，下拉回「全部清单」
        [System.IO.File]::WriteAllText($script:ConfigPath, $cfgBackupText, (New-Object System.Text.UTF8Encoding($false)))
        $script:FilterListIndex = -1
        Update-ListCombo -ListIndex (-1)

        # 0.3.14 · 侧边展开的收起箭头 / 小鲸鱼右键菜单 / 全隐藏不冒泡
        Show-Panel
        if (-not $script:Form.Visible) { $script:Form.Show() }
        Start-Sleep -Milliseconds 80
        Check '收起箭头：普通展开时 × 显示、箭头不出现' (($null -ne $script:BtnClose) -and $script:Form.Visible -and $script:BtnClose.Visible -and (-not $script:CollapseTab.Visible))
        Show-Panel -FromWhale
        if (-not $script:Form.Visible) { $script:Form.Show() }
        Position-CollapseTab
        Start-Sleep -Milliseconds 80
        $tabVis = ($null -ne $script:CollapseTab) -and $script:CollapseTab.Visible
        Check '收起箭头：从小鲸鱼展开时 × 隐藏、箭头显示' ($script:Form.Visible -and (-not $script:BtnClose.Visible) -and $tabVis)
        $waT = Get-ScreenArea
        $tabSideOk = $false
        $expectSide = 'right'
        $panelMidT2 = [int]$script:Form.Left + [int]($script:Form.Width / 2)
        if ($panelMidT2 -lt ($waT.Left + [int](($waT.Right - $waT.Left) / 2))) { $expectSide = 'left' }
        if ($tabVis) {
            $tabRightEdge = [int]$script:CollapseTab.Left + [int]$script:CollapseTab.Width
            $formRightEdge = [int]$script:Form.Left + [int]$script:Form.Width
            if ($expectSide -eq 'right') {
                # 右栏：箭头贴面板左沿外面（屏幕左边没空间时贴内侧左沿）
                $tabSideOk = ([string]$script:CollapseTabSide -eq 'right') -and (($tabRightEdge -le ([int]$script:Form.Left + 1)) -or ([int]$script:CollapseTab.Left -eq [int]$script:Form.Left))
            } else {
                # 左栏：箭头贴面板右沿外面（屏幕右边没空间时贴内侧右沿）
                $tabSideOk = ([string]$script:CollapseTabSide -eq 'left') -and (([int]$script:CollapseTab.Left -ge ($formRightEdge - 1)) -or ($tabRightEdge -eq $formRightEdge))
            }
        }
        Check '收起箭头：贴面板内侧边、方向朝面板（右栏→左沿朝右）' $tabSideOk ('side=' + $script:CollapseTabSide + ' expect=' + $expectSide + ' tab=' + $script:CollapseTab.Left + ',' + $script:CollapseTab.Top + ' form=' + $script:Form.Left + ',' + [int]$script:Form.Width)
        $dockSideNow = [string]$script:WinCfg.WhaleSide
        $dockOk = $false
        if ($dockSideNow -eq 'left') { $dockOk = ([int]$script:Form.Left -eq [int]$waT.Left) }
        else { $dockOk = (([int]$script:Form.Left + [int]$script:Form.Width) -eq [int]$waT.Right) }
        Check '小鲸鱼展开：面板贴着鲸鱼那条屏边' $dockOk ('side=' + $dockSideNow + ' form=' + $script:Form.Left + ',' + ([int]$script:Form.Left + [int]$script:Form.Width) + ' wa=' + $waT.Left + ',' + $waT.Right)
        Set-Collapsed $true 'selftest-tab'
        Start-Sleep -Milliseconds 120
        Check '收起箭头：收起后箭头消失、小鲸鱼出现' ((-not $script:CollapseTab.Visible) -and $script:Whale.Visible)
        $whaleMidWant = 0
        if ($null -ne $script:Whale) { $whaleMidWant = [int]$script:Whale.Top + [int]($script:Whale.Height / 2) }
        Set-Collapsed $false 'selftest-tab-back' -FromWhale
        if (-not $script:Form.Visible) { $script:Form.Show() }
        Start-Sleep -Milliseconds 80
        $waV = Get-ScreenArea
        $wantTop = $whaleMidWant - [int]($script:Form.Height / 2)
        if ($wantTop -lt $waV.Top) { $wantTop = $waV.Top }
        if (($wantTop + [int]$script:Form.Height) -gt $waV.Bottom) { $wantTop = $waV.Bottom - [int]$script:Form.Height }
        Check '小鲸鱼展开：纵向对齐鲸鱼中心（靠边夹到工作区顶/底）' ([int]$script:Form.Top -eq $wantTop) ('top=' + $script:Form.Top + ' want=' + $wantTop + ' whaleMid=' + $whaleMidWant)
        Check '收起箭头：从侧边再展开仍是箭头模式' ($script:Form.Visible -and (-not $script:BtnClose.Visible) -and $script:CollapseTab.Visible)
        # 0.3.18/0.3.19：拖面板到屏幕边收起 → 箭头消失；侧边条从面板中心起手、按位移走
        $formTopBefore = [int]$script:Form.Top
        $waBarT = Get-ScreenArea
        Set-Interactive $true 'selftest-drag'   # 拖动只在交互态下开始
        Start-PanelDrag -Mode 'move' -X ([int]$script:Form.Left + 100) -Y ($formTopBefore + 20)
        $waDrag2 = Get-ScreenArea
        $offX2 = [int]$script:PanelDrag.OffX
        $mouseYCollapse = $formTopBefore + 120
        Update-PanelDrag -X ($waDrag2.Right - 5 - [int]$script:Form.Width + $offX2) -Y $mouseYCollapse
        Check '拖动碰边收起：收起箭头跟着消失' (-not $script:CollapseTab.Visible)
        # 碰边时窗口实际 Top = 鼠标Y - 抓点偏移(20)，侧边条应按这个窗口的中心起手
        $barWant0 = [int]($script:Form.Top + [Math]::Floor($script:Form.Height / 2) - 36)
        if ($barWant0 -lt [int]$waBarT.Top) { $barWant0 = [int]$waBarT.Top }
        if ($barWant0 -gt [int]($waBarT.Bottom - 72)) { $barWant0 = [int]($waBarT.Bottom - 72) }
        Check '拖动碰边：侧边条从面板中心起手（不是被拽到鼠标点）' ([int]$script:Whale.Top -eq $barWant0) ('whaleTop=' + $script:Whale.Top + ' want=' + $barWant0 + ' mouseCentered=' + ($mouseYCollapse - 36))
        Update-PanelDrag -X ($waDrag2.Right - 5 - [int]$script:Form.Width + $offX2) -Y ($mouseYCollapse + 50)
        $barWant1 = $barWant0 + 50
        if ($barWant1 -gt [int]($waBarT.Bottom - 72)) { $barWant1 = [int]($waBarT.Bottom - 72) }
        Check '拖动上下移动：侧边条按鼠标位移跟手' ([int]$script:Whale.Top -eq $barWant1) ('whaleTop=' + $script:Whale.Top + ' want=' + $barWant1)
        End-PanelDrag
        if ($script:PanelCollapsed) { Set-Collapsed $false 'selftest-after-drag' -FromWhale }
        if (-not $script:Form.Visible) { $script:Form.Show() }
        Start-Sleep -Milliseconds 80
        # 0.3.20：收回时小鲸鱼保持原位（不按窗口中心重算）
        $whaleTopBefore = [int]$script:Whale.Top
        $script:Form.Top = [int]((Get-ScreenArea).Top + 100)
        Start-Sleep -Milliseconds 60
        Set-Collapsed $true 'selftest-keep'
        Start-Sleep -Milliseconds 100
        Check '收回侧边栏：小鲸鱼保持原来的位置（不按窗口中心重算）' ([int]$script:Whale.Top -eq $whaleTopBefore) ('whaleTop=' + $script:Whale.Top + ' before=' + $whaleTopBefore)

        # 0.3.24：卷帘起手（清空 + 队列 + 每拍补行）
        if ($null -ne $script:Flow) {
            $rollPkg = Get-RowSpecs -State (Load-State)
            $rollWant = [Math]::Min(3, @($rollPkg.Specs).Count)
            Start-RowRoll -State (Load-State)
            $rollQueueCount = @($script:RollQueue).Count
            $rollAdded = Step-RowRoll -Max 3
            $fadeCount = @($script:FadeRows).Count
            Check '卷帘：起手清空、逐行铺开且有淡入' (($rollAdded -eq $rollWant) -and ($script:Flow.Controls.Count -eq $rollWant) -and ($fadeCount -ge 1)) ('queue=' + $rollQueueCount + ' added=' + $rollAdded + ' controls=' + $script:Flow.Controls.Count + ' fade=' + $fadeCount)
            Stop-RowRoll
            Build-Rows -State (Load-State)
        }

        # 0.3.25：拖拽边界
        $waBound = Get-ScreenArea
        $cp1 = Get-ClampedWindowPos -Left ([int]$waBound.Right + 500) -Top ([int]$waBound.Bottom + 500) -W 420 -H 500
        Check '拖拽边界：右下越界顶在屏幕边' (($cp1.Left -eq [int]($waBound.Right - 420)) -and ($cp1.Top -eq [int]($waBound.Bottom - 500)))
        $cp2 = Get-ClampedWindowPos -Left ([int]$waBound.Left - 500) -Top ([int]$waBound.Top - 500) -W 420 -H 500
        Check '拖拽边界：左上越界顶在屏幕边' (($cp2.Left -eq [int]$waBound.Left) -and ($cp2.Top -eq [int]$waBound.Top))
        $cp3 = Get-ClampedWindowPos -Left 500 -Top 500 -W 5000 -H 5000
        Check '拖拽边界：窗口比屏幕大时两边顶死不动' (($cp3.Left -eq [int]$waBound.Left) -and ($cp3.Top -eq [int]$waBound.Top))

        # 0.3.20：小鲸鱼拖拽（按住拖=定位；单击=打开主界面）
        $waW = Get-ScreenArea
        $baseW = [int]$script:Whale.Top
        Start-WhaleDrag -Y $baseW
        Update-WhaleDrag -Y ($baseW + 40)
        $wantW = $baseW + 40
        if ($wantW -gt [int]($waW.Bottom - 72)) { $wantW = [int]($waW.Bottom - 72) }
        if ($wantW -lt [int]$waW.Top) { $wantW = [int]$waW.Top }
        Check '小鲸鱼拖动：按位移跟手' ([int]$script:Whale.Top -eq $wantW) ('top=' + $script:Whale.Top + ' want=' + $wantW)
        End-WhaleDrag
        $savedW = Get-Prop (Get-Prop (Read-JsonFile $script:ConfigPath) 'ui' $null) 'window' $null
        Check '小鲸鱼拖动：松手后位置落盘' ([int](Get-Prop $savedW 'whaleY' -1) -eq [int]$script:Whale.Top) ('saved=' + (Get-Prop $savedW 'whaleY' -1) + ' top=' + $script:Whale.Top)
        # 0.3.21：拖鲸鱼过屏幕中线 → 换到对应侧边
        $waSide = Get-ScreenArea
        if ($null -ne $script:Whale) { $script:Whale.Show() }
        Update-WhaleSideFromX -X ([int]($waSide.Left + 10))
        $okLeftSide = ([string]$script:WinCfg.WhaleSide -eq 'left') -and ([int]$script:Whale.Left -eq [int]$waSide.Left)
        Update-WhaleSideFromX -X ([int]($waSide.Right - 10))
        $okRightSide = ([string]$script:WinCfg.WhaleSide -eq 'right') -and ([int]$script:Whale.Left -eq [int]($waSide.Right - [int]$script:BarWidth))
        Check '小鲸鱼换边：过中线就贴到对应侧边' ($okLeftSide -and $okRightSide) ('left=' + $okLeftSide + ' right=' + $okRightSide)

        $keepW = [int]$script:Whale.Top
        Start-WhaleDrag -Y $keepW
        End-WhaleDrag
        Start-Sleep -Milliseconds 100
        Check '小鲸鱼单击：打开主界面' ($script:Form.Visible -and (-not $script:Whale.Visible))
        Set-Collapsed $true 'selftest-click-back'
        Start-Sleep -Milliseconds 100
        Check '单击展开再收回：小鲸鱼回到拖到的位置' ([int]$script:Whale.Top -eq $keepW) ('top=' + $script:Whale.Top + ' want=' + $keepW)
        Show-Panel
        if (-not $script:Form.Visible) { $script:Form.Show() }
        Start-Sleep -Milliseconds 80
        $menuCount = 0
        $hasExit = $false
        $hasHide = $false
        if ($null -ne $script:WhaleMenu) {
            $menuCount = $script:WhaleMenu.Items.Count
            foreach ($mi in $script:WhaleMenu.Items) {
                if ([string]$mi.Text -like '*退出*') { $hasExit = $true }
                if ([string]$mi.Text -like '*关闭小鲸鱼*') { $hasHide = $true }
            }
        }
        Check '小鲸鱼右键菜单：有「关闭小鲸鱼」和「退出」' ($hasHide -and $hasExit -and ($menuCount -ge 7)) ('items=' + $menuCount)
        $script:Form.Hide()
        if ($null -ne $script:Whale) { $script:Whale.Show() }
        $ctxWhale = Test-BubbleContext
        $script:Form.Show()
        $ctxPanel = Test-BubbleContext
        $script:Form.Hide()
        if ($null -ne $script:Whale) { $script:Whale.Hide() }
        $ctxNone = Test-BubbleContext
        Check '冒泡：只有小鲸鱼状态才冒（主界面开着、都关着都不冒）' ($ctxWhale -and (-not $ctxPanel) -and (-not $ctxNone)) ('whale=' + $ctxWhale + ' panel=' + $ctxPanel + ' none=' + $ctxNone)
        Show-Panel
        if (-not $script:Form.Visible) { $script:Form.Show() }
        Start-Sleep -Milliseconds 80
        Check '收起箭头：普通展开后回到 × 模式' ($script:Form.Visible -and $script:BtnClose.Visible -and (-not $script:CollapseTab.Visible))

        # 0.3.32：小窗开着只暂停，关窗后重新排 3 秒（恢复 0.3.29 的行为）
        $script:FromWhale = $true
        $script:WinCfg.Edge = 'right'
        $script:WinCfg.AutoCollapseSeconds = 3
        $script:PeekExpanded = $true
        $script:WhaleDeadline = (Get-Date).AddMilliseconds(10)
        Enter-ChildWindow
        Check '小窗打开：暂停自动收回（小窗期间不收面板）' ((-not $script:PeekExpanded) -and ($null -eq $script:WhaleDeadline))
        Exit-ChildWindow
        $secsCw = 0.0
        if ($null -ne $script:WhaleDeadline) { $secsCw = ($script:WhaleDeadline - (Get-Date)).TotalSeconds }
        Check '小窗关掉：3 秒自动收回重新排程（0.3.32 恢复）' ($script:PeekExpanded -and $secsCw -gt 2 -and $secsCw -le 3.2) ('剩余 ' + [Math]::Round($secsCw, 1))
        $tabBack = ($null -ne $script:CollapseTab) -and $script:CollapseTab.Visible
        Check '小窗关掉：侧向收起箭头还在（0.3.32 修 FromWhale 丢失）' ([bool]$script:FromWhale -and $tabBack) ('fromWhale=' + $script:FromWhale + ' tab=' + $tabBack)
        # 0.3.32：Show-Settings 保存后按原 FromWhale 重显面板 → 不能又变回普通窗口
        Show-Panel -NoAnim -FromWhale:$script:FromWhale
        $secsCw2 = 0.0
        if ($null -ne $script:WhaleDeadline) { $secsCw2 = ($script:WhaleDeadline - (Get-Date)).TotalSeconds }
        $tabBack2 = ($null -ne $script:CollapseTab) -and $script:CollapseTab.Visible
        Check '关设置后重显面板：仍是箭头模式 + 3 秒倒计时还在（0.3.32）' ([bool]$script:FromWhale -and $tabBack2 -and $secsCw2 -gt 2) ('fromWhale=' + $script:FromWhale + ' tab=' + $tabBack2 + ' secs=' + [Math]::Round($secsCw2, 1))
        # 0.3.40：点导出后的黑色提示框（面板已显示）→ 侧边模式/箭头/3 秒倒计时都不许丢
        $script:FromWhale = $true
        $script:WinCfg.Edge = 'right'
        $script:WinCfg.AutoCollapseSeconds = 3
        $script:PeekExpanded = $true
        $script:WhaleDeadline = (Get-Date).AddSeconds(0.5)   # 故意快到期：点完提示框应重新排满 3 秒
        $script:ToastTimer.Start()
        $toastTimerWas = [bool]$script:ToastTimer.Enabled
        # 走真实事件：直接触发 Toast 的 Click（和用户用鼠标点它走的是同一条 handler）
        $toastClick = [System.Windows.Forms.Control].GetMethod('OnClick', [System.Reflection.BindingFlags]'NonPublic,Instance')
        $toastClick.Invoke($script:Toast, @([System.EventArgs]::Empty))
        $toastTimerStopped = -not [bool]$script:ToastTimer.Enabled
        Check '点提示框：事件真的触发（Hide-Toast 执行）' ($toastTimerWas -and $toastTimerStopped) ('was=' + $toastTimerWas + ' stopped=' + $toastTimerStopped)
        $secsToast = 0.0
        if ($null -ne $script:WhaleDeadline) { $secsToast = ($script:WhaleDeadline - (Get-Date)).TotalSeconds }
        $tabToast = ($null -ne $script:CollapseTab) -and $script:CollapseTab.Visible
        Check '点提示框（面板已显示）：侧边箭头还在 + 3 秒倒计时重新排满（0.3.40）' ([bool]$script:FromWhale -and $tabToast -and $secsToast -gt 2.5) ('fromWhale=' + $script:FromWhale + ' tab=' + $tabToast + ' secs=' + [Math]::Round($secsToast, 1))
        # 面板已显示时 Show-Panel 不带 -FromWhale 也不许把模式重置（0.3.40 兜底）
        Show-Panel -NoAnim
        $tabToast2 = ($null -ne $script:CollapseTab) -and $script:CollapseTab.Visible
        Check '面板重显不带 -FromWhale：侧边模式不被重置（0.3.40）' ([bool]$script:FromWhale -and $tabToast2) ('fromWhale=' + $script:FromWhale + ' tab=' + $tabToast2)
        $script:PeekExpanded = $false
        $script:WhaleDeadline = $null
        if ($null -ne $script:WhaleTimer) { try { $script:WhaleTimer.Stop() } catch { } }

        # 0.3.25：图钉
        Show-Panel
        if (-not $script:Form.Visible) { $script:Form.Show() }
        $script:Pinned = $true
        $script:WinCfg.Edge = 'none'
        Set-Collapsed $true 'selftest-pin'
        Start-Sleep -Milliseconds 80
        $pinKept = ($script:Form.Visible -and (-not $script:PanelCollapsed))
        $script:Pinned = $false
        Set-Collapsed $true 'selftest-unpin'
        Start-Sleep -Milliseconds 150
        Check '图钉：钉住时不收回，取消后正常收回' ($pinKept -and $script:PanelCollapsed -and $script:Whale.Visible) ('pinKept=' + $pinKept + ' collapsed=' + $script:PanelCollapsed + ' whale=' + $script:Whale.Visible + ' child=' + $script:ChildOpen)
        Show-Panel
        if (-not $script:Form.Visible) { $script:Form.Show() }
        Check '侧边面板：未钉住时一直可点（不退穿透）' ([bool]$script:InteractMode)
        Check '侧边面板：未钉住时不透明度恒 100%' ([Math]::Abs([double]$script:Form.Opacity - 1.0) -lt 0.001) ('opacity=' + $script:Form.Opacity)
        $opBak = [int]$script:UiSettings.Opacity
        $script:UiSettings.Opacity = 30
        Show-Panel
        if (-not $script:Form.Visible) { $script:Form.Show() }
        Check '侧边面板：配置透明度 30% 时仍 100%（0.3.30 回归）' ([Math]::Abs([double]$script:Form.Opacity - 1.0) -lt 0.001) ('opacity=' + $script:Form.Opacity)
        $script:UiSettings.Opacity = $opBak

        # 0.3.32：刷新/设置/编辑 这些按钮也要挂上焦点清理（0.3.30 挂太早，它们没挂上）
        $focusOk = $false
        $hadFocus = $false
        if ($null -ne $script:BtnRefresh) {
            try { $script:Form.ActiveControl = $script:BtnRefresh } catch { }
            $hadFocus = ([object]::ReferenceEquals($script:Form.ActiveControl, $script:BtnRefresh))
            try { $script:BtnRefresh.PerformClick() } catch { }
            $focusOk = ($hadFocus -and ($null -eq $script:Form.ActiveControl))
        }
        Check '按钮焦点：刷新点完不留焦点（0.3.32 覆盖全）' $focusOk ('before=' + $hadFocus + ' afterNull=' + ($null -eq $script:Form.ActiveControl))

        # 0.3.1 · P6：Deactivate 事件 → auto 收起 / always 只回穿透
        $script:Pinned = $true   # 0.3.26：失焦回穿透只在钉住模式成立
        $script:UiSettings = [pscustomobject]@{ Mode = 'auto'; HideSeconds = 15; Opacity = 100; TopMost = $true }
        $tf.Hide()
        $tf.Location = New-Object System.Drawing.Point(300, 300)
        $tf.ClientSize = New-Object System.Drawing.Size(420, 520)
        $tf.Show()
        $script:InteractMode = $false
        Set-Interactive $true 'selftest-p6'
        Invoke-PanelDeactivate
        Start-Sleep -Milliseconds 80
        Check 'P6 auto：失焦收起' (-not $tf.Visible)
        $tf.Show()
        $script:InteractMode = $false
        $script:UiSettings.Mode = 'always'
        Set-Interactive $true 'selftest-p6b'
        Invoke-PanelDeactivate
        Start-Sleep -Milliseconds 80
        Check 'P6 always：失焦回穿透且不收起' ($tf.Visible -and (-not $script:InteractMode)) ('visible=' + $tf.Visible + ' mode=' + $script:InteractMode)
        $tf.Hide()
        $tf.TopMost = $false
        try { $tf.Opacity = 1.0 } catch { }

        $script:SelfTestMessages.Add(('  [INFO] EXSTYLE 穿透=0x{0:X8} 交互=0x{1:X8}' -f $exPassive, $exActive)) | Out-Null
        $script:SelfTestMessages.Add(('  [INFO] NCHITTEST 穿透={0} 标题={1} 控件={2} 右下={3}' -f $hitPassive, $hitCap, $hitCombo, $hitCorner)) | Out-Null
        $script:SelfTestMessages.Add(('  [INFO] Win+D 拦截 {0}/3，累计 {1}' -f $blocked, $script:ShellHook.HiddenBlocked)) | Out-Null

        # 收尾：解钩、停表、销毁测试窗体（不可留在桌面上/托盘里）
        try { $script:ShellHook.ReleaseHandle() } catch { }
        $script:ShellHook = $null
        $script:Exiting = $true
        foreach ($tn in 'WatchTimer', 'ShowTimer', 'HoverTimer', 'LeaveTimer', 'DragTimer', 'WhaleTimer', 'RefreshTimer', 'AutoHideTimer', 'FadeTimer', 'DoneFadeTimer', 'PendingDeleteTimer', 'BubbleTimer', 'ToastTimer', 'SlideTimer', 'OpenFillTimer', 'RollTimer') {
            $tv = Get-Variable -Name $tn -Scope Script -ErrorAction SilentlyContinue
            if ($null -ne $tv -and $null -ne $tv.Value) { try { $tv.Value.Stop(); $tv.Value.Dispose() } catch { } }
        }
        try { if ($null -ne $script:Notify) { $script:Notify.Visible = $false; $script:Notify.Dispose() } } catch { }
        $script:Notify = $null
        try { if ($null -ne $script:Whale) { $script:Whale.Dispose() } } catch { }
        $script:Whale = $null
        try { if ($null -ne $script:Bubble) { $script:Bubble.Dispose() } } catch { }
        $script:Bubble = $null
        try { $tf.Dispose() } catch { }
        $script:Form = $null
        $script:Exiting = $false

        # 4) 图标（0 / 5 / 12 / 120）
        Initialize-Native
        foreach ($n in 0, 5, 12, 120) {
            $made = New-TrayIconObject -Pending $n
            Check ('图标 32×32 可生成 (' + $n + ')') ($made.Icon.Width -eq 32 -and $made.Icon.Height -eq 32)
            if ($script:HasNative) { [void][DshTodoTray.Native]::DestroyIcon($made.Handle) }
            $made.Icon.Dispose()
        }

        # 5) 缺失文件不崩
        $missing = Join-Path $tmp 'nope.json'
        $docMissing = Read-JsonFile $missing
        Check '缺失文件返回 null 不抛异常' ($null -eq $docMissing)
    } catch {
        $script:SelfTestMessages.Add(('  [FAIL] 自检异常：' + $_.Exception.Message)) | Out-Null
        $bad++
    } finally {
        try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }

    $fails = @($script:SelfTestMessages | Where-Object { $_.Contains('[FAIL]') }).Count
    $passes = @($script:SelfTestMessages | Where-Object { $_.Contains('[OK]') }).Count

    Write-Host ('{0} {1} ({2}) 自检' -f $script:AppName, $script:AppVersion, $script:Stage)
    Write-Host ('PS 版本: ' + $PSVersionTable.PSVersion.ToString())
    foreach ($m in $script:SelfTestMessages) { Write-Host $m }
    Write-Host ('结果: {0} 项通过, {1} 项失败' -f $passes, $fails)
    if ($fails -gt 0) { exit 1 }
    exit 0
}

#endregion

# ============================================================
#  M19 主流程 —— Mutex、初始化、托盘、Application.Run
# ============================================================
#region M19 主流程
# ============================================================
#  主流程
# ============================================================

$script:ConfigPath = Resolve-ConfigPath
$script:BaseDir    = Split-Path -Parent $script:ConfigPath
$script:ScriptPath = Join-Path $PSScriptRoot 'todo-tray.ps1'

try {
    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
} catch {
    Write-Host ('缺少 .NET 组件（System.Drawing / System.Windows.Forms）：' + $_.Exception.Message)
    exit 2
}

Initialize-Native

if ($SelfTest) { Invoke-SelfTest }
if (-not [string]::IsNullOrWhiteSpace($DumpUi)) {
    $dir = [System.IO.Path]::GetFullPath($DumpUi)
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Ensure-Config
    Initialize-Ui
    try { $script:Notify.Visible = $false } catch { }
    $stateDump = Load-State
    Update-Status -State $stateDump
    # 屏外 + 全透明地 Show 一下：只为让控件真正布局，用户看不见也不抢焦点
    $script:Form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $script:Form.Location = New-Object System.Drawing.Point(-4000, -4000)
    $script:Form.Opacity = 0.0
    $script:Form.ClientSize = New-Object System.Drawing.Size(420, 560)
    $script:Form.Show()
    Start-Sleep -Milliseconds 250
    Build-Rows -State $stateDump
    Start-Sleep -Milliseconds 150
    $bmp1 = New-Object System.Drawing.Bitmap(420, 560)
    $script:Form.DrawToBitmap($bmp1, (New-Object System.Drawing.Rectangle(0, 0, 420, 560)))
    $script:Form.Hide()
    $bmp1.Save((Join-Path $dir 'panel.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp1.Dispose()
    # M7：把小鲸鱼也画成 PNG（不走 Show，纯控件绘制，验证矢量图不依赖 emoji）
    if ($null -ne $script:Whale) {
        try {
            $bw = New-Object System.Drawing.Bitmap(24, 72)
            $script:Whale.DrawToBitmap($bw, (New-Object System.Drawing.Rectangle(0, 0, 24, 72)))
            $bw.Save((Join-Path $dir 'whale.png'), [System.Drawing.Imaging.ImageFormat]::Png)
            $bw.Dispose()
            Write-Host 'ui-whale: ok'
        } catch {
            Write-Host ('ui-whale: EXCEPTION ' + $_.Exception.Message)
        }
    }
    $dlg = New-AddDialog
    $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $dlg.Location = New-Object System.Drawing.Point(-4000, -4000)
    $dlg.Opacity = 0.0
    $dlg.Show()
    Start-Sleep -Milliseconds 250
    $bmp2 = New-Object System.Drawing.Bitmap($dlg.Width, $dlg.Height)
    $dlg.DrawToBitmap($bmp2, (New-Object System.Drawing.Rectangle(0, 0, $dlg.Width, $dlg.Height)))
    $bmp2.Save((Join-Path $dir 'dialog.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp2.Dispose()
    # 顺手自检「确定」按钮的处理逻辑（反射触发 OnClick，不弹窗）
    try {
        $btnOkD = @($dlg.Controls | Where-Object { $_.Text -eq '确定' })
        $tbD = @($dlg.Controls | Where-Object { $_ -is [System.Windows.Forms.TextBox] })
        if ($btnOkD.Count -ge 1 -and $tbD.Count -ge 1) {
            $tbD[0].Text = 'UI自检新增'
            $tbD[1].Text = '10-28 23:59'
            $m = $btnOkD[0].GetType().GetMethod('OnClick', [System.Reflection.BindingFlags]'NonPublic,Instance')
            [void]$m.Invoke($btnOkD[0], @([System.EventArgs]::Empty))
            if ($dlg.Tag -eq 'ok') { Write-Host 'ui-add: ok' } else { Write-Host 'ui-add: FAILED (tag empty)' }
        } else {
            Write-Host 'ui-add: SKIP (controls not found)'
        }
    } catch {
        Write-Host ('ui-add: EXCEPTION ' + $_.Exception.Message)
    }
    $dlg.Dispose()
    # 0.3.13：清单管理窗也 dump 一张（布局回归用）
    try {
        $dlgMgr = New-ListManagerDialog
        $dlgMgr.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $dlgMgr.Location = New-Object System.Drawing.Point(-4000, -4000)
        $dlgMgr.Opacity = 0.0
        $dlgMgr.Show()
        Start-Sleep -Milliseconds 250
        $bmpM = New-Object System.Drawing.Bitmap($dlgMgr.Width, $dlgMgr.Height)
        $dlgMgr.DrawToBitmap($bmpM, (New-Object System.Drawing.Rectangle(0, 0, $dlgMgr.Width, $dlgMgr.Height)))
        $bmpM.Save((Join-Path $dir 'listmgr.png'), [System.Drawing.Imaging.ImageFormat]::Png)
        $bmpM.Dispose()
        $dlgMgr.Dispose()
        Write-Host 'ui-listmgr: ok'
    } catch {
        Write-Host ('ui-listmgr: EXCEPTION ' + $_.Exception.Message)
    }
    # 0.3.14：收起箭头的两个朝向也 dump 一张
    try {
        Initialize-CollapseTab
        foreach ($tabSide in @('right', 'left')) {
            $script:CollapseTabSide = $tabSide
            $script:CollapseTab.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
            $script:CollapseTab.Location = New-Object System.Drawing.Point(-4000, -4000)
            $script:CollapseTab.Show()
            $script:CollapseTab.Invalidate()
            Start-Sleep -Milliseconds 150
            $bmpTab = New-Object System.Drawing.Bitmap($script:CollapseTab.Width, $script:CollapseTab.Height)
            $script:CollapseTab.DrawToBitmap($bmpTab, (New-Object System.Drawing.Rectangle(0, 0, $script:CollapseTab.Width, $script:CollapseTab.Height)))
            $bmpTab.Save((Join-Path $dir ('tab_' + $tabSide + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
            $bmpTab.Dispose()
            $script:CollapseTab.Hide()
        }
        Write-Host 'ui-tab: ok'
    } catch {
        Write-Host ('ui-tab: EXCEPTION ' + $_.Exception.Message)
    }
    Initialize-Toast
    $script:ToastTitle.Text = '补提醒 · 有 2 条待办到期'
    $script:ToastBody.Text = '已经过期的一条（面板里应该标红「逾期」）、今天到期的一条（测 v1-b 气泡用）'
    $script:Toast.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $script:Toast.Location = New-Object System.Drawing.Point(-4000, -4000)
    $script:Toast.Opacity = 0.0
    $script:Toast.Show()
    Start-Sleep -Milliseconds 250
    $bmp3 = New-Object System.Drawing.Bitmap($script:Toast.Width, $script:Toast.Height)
    $script:Toast.DrawToBitmap($bmp3, (New-Object System.Drawing.Rectangle(0, 0, $script:Toast.Width, $script:Toast.Height)))
    $bmp3.Save((Join-Path $dir 'toast.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp3.Dispose()
    $script:Toast.Hide()
    Write-Host ('ui dumped to ' + $dir)
    exit 0
}
if (-not [string]::IsNullOrWhiteSpace($DumpIcons)) {
    $dir = [System.IO.Path]::GetFullPath($DumpIcons)
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    foreach ($n in 0, 1, 5, 12, 45, 120) {
        $made = New-TrayIconObject -Pending $n
        $b32 = $made.Icon.ToBitmap()
        $b32.Save((Join-Path $dir ('icon-' + $n + '-32.png')), [System.Drawing.Imaging.ImageFormat]::Png)
        $b16 = New-Object System.Drawing.Bitmap($b32, 16, 16)
        $b16.Save((Join-Path $dir ('icon-' + $n + '-16.png')), [System.Drawing.Imaging.ImageFormat]::Png)
        $b16.Dispose(); $b32.Dispose(); $made.Icon.Dispose()
        if ($script:HasNative) { [void][DshTodoTray.Native]::DestroyIcon($made.Handle) }
    }
    Write-Host ('icons dumped to ' + $dir)
    exit 0
}

# 单实例（按配置路径区分，dev 与正式可以同时跑）
$mutexName = 'Local\dsh-todo-tray-' + (Get-PathHash $script:ConfigPath)
$showEventName = 'Local\dsh-todo-tray-show-' + (Get-PathHash $script:ConfigPath)
$script:Mutex = New-Object System.Threading.Mutex($false, $mutexName)
$gotMutex = $false
try { $gotMutex = $script:Mutex.WaitOne(0, $false) } catch { $gotMutex = $true }
if (-not $gotMutex) {
    # P3：重复启动必须留痕；顺手让已运行的实例把面板弹出来（不用再去溢出区找图标）
    Write-Log ('已有实例在运行（配置: ' + $script:ConfigPath + '），本进程退出')
    $signaled = $false
    try {
        $evt = [System.Threading.EventWaitHandle]::OpenExisting($showEventName)
        [void]$evt.Set()
        $evt.Dispose()
        $signaled = $true
    } catch { }
    if ($signaled) { Write-Log '已通知已运行的实例显示面板' }
    else { Show-MessageBox ('待办托盘已经在运行了（配置文件：' + $script:ConfigPath + '）。' + "`r`n" + '请看任务栏右下角的托盘图标。') }
    exit 0
}
try {
    $script:ShowEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, $showEventName)
} catch {
    $script:ShowEvent = $null
}

try {
    Ensure-Config
    Ensure-AutostartFromConfig   # 0.3.36：新装默认开机自启（配置里 autostart=true 而启动项不在就补）
    [void](Update-LegacyFields)   # M2：老条目补 prio/order（幂等，只写一次）
    Write-Log ('启动 ' + $script:AppVersion + ' / 配置: ' + $script:ConfigPath)

    Initialize-Ui
    Refresh-All
    Initialize-NotifyState
    $script:LastReminderCheck = Get-Date
    Invoke-Reminders -Startup

    $script:WinCfg = Get-WindowSettings
    if ($ShowPanelOnStart) { Show-Panel }
    elseif ($script:WinCfg.Collapsed) { Show-Whale }
    # R3：常驻模式启动即挂在右上角（穿透态、不抢焦点、不自动隐藏）
    elseif ($null -ne $script:UiSettings -and $script:UiSettings.Mode -eq 'always') { Show-Panel }

    if ($HangSeconds -gt 0) {
        $script:HangTimer = New-Object System.Windows.Forms.Timer
        $script:HangTimer.Interval = 1000
        $script:HangTimer.Add_Tick({
            $script:HangTimer.Stop()
            Write-Log ('模拟 UI 卡死 ' + $HangSeconds + ' 秒')
            Start-Sleep -Seconds $HangSeconds
        })
        $script:HangTimer.Start()
    }

    if ($ExitAfter -gt 0) {
        $script:ExitTimer = New-Object System.Windows.Forms.Timer
        $script:ExitTimer.Interval = [Math]::Max(1, $ExitAfter) * 1000
        $script:ExitTimer.Add_Tick({ $script:ExitTimer.Stop(); Write-Log ('-ExitAfter 到点（' + $ExitAfter + ' 秒），开始退出'); Exit-App })
        $script:ExitTimer.Start()
        # 兜底：后台线程另开一只表，UI 线程卡死（对话框/死循环）也能按时退出
        if ('DshTodoTray.Keeper' -as [type]) {
            try { [DshTodoTray.Keeper]::Arm((($ExitAfter + 8) * 1000), (Get-LogFilePath)); Write-Log ('看门狗已挂：' + ($ExitAfter + 8) + ' 秒') }
            catch { Write-Log ('看门狗挂载失败: ' + $_.Exception.Message) 'WARN' }
        } else {
            Write-Log '看门狗类型没加载（Add-Type 失败）' 'WARN'
        }
    }

    if (-not $ShowPanelOnStart) {
        try {
            $script:Notify.ShowBalloonTip(4000, '待办托盘已启动', ('未完成 ' + $script:LastPending + ' 条 · 左键托盘图标打开面板'), [System.Windows.Forms.ToolTipIcon]::Info)
        } catch { }
    }    Write-Log ('清单数: ' + @(Get-Lists).Count)
    $script:Ctx = New-Object System.Windows.Forms.ApplicationContext
    [System.Windows.Forms.Application]::Run($script:Ctx)
} catch {
    $msg = $_.Exception.Message
    Write-Log ('致命错误 :: ' + $_.Exception.ToString()) 'ERROR'
    $script:Exiting = $true
    try { if ($null -ne $script:Notify) { $script:Notify.Visible = $false; $script:Notify.Dispose() } } catch { }
    Show-MessageBox ('待办托盘启动失败：' + "`r`n" + $msg + "`r`n`r`n" + '日志：' + (Join-Path $script:BaseDir 'logs\todo-tray.log'))
    exit 3
} finally {
    try { if ($null -ne $script:Mutex) { $script:Mutex.ReleaseMutex(); $script:Mutex.Dispose() } } catch { }
}
#endregion
