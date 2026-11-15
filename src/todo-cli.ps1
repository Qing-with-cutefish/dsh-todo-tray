#Requires -Version 5.1
<#
    dsh-todo-tray · 命令行（v1-c）
    ==========================================================
    给 agent 和批处理用的待办 CLI。数据格式与托盘完全一致（todos.json）。

      todo.cmd init [--workspace <目录>]        # 建 .todo\ + AGENTS.md 指针 + 登记到 config
      todo.cmd add "标题" [--due "10-30 09:00"] [--link "D:\x.md"] [--tags a,b] [--scope id]
      todo.cmd list [--all] [--scope id] [--json]
      todo.cmd done <id> [--scope id]
      todo.cmd rm <id> [--scope id]
      todo.cmd export [--md] [--scope id]
      todo.cmd where                            # 当前会用哪份清单

    退出码：0 成功 / 1 业务失败 / 2 用法错误

    本文件必须存 UTF-8 带 BOM（Windows PowerShell 5.1 规则）。
#>
param()

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$script:AppVersion = '0.1.6'
$script:NoLog = $false
$script:ConfigPath = ''
$script:BaseDir = ''

. (Join-Path $PSScriptRoot 'todo-lib.ps1')

function Fail {
    param([string]$Message, [int]$Code = 1)
    [Console]::Error.WriteLine('错误：' + $Message)
    exit $Code
}

function Show-Usage {
    @'
用法：
  todo.cmd init [--workspace <目录>]
  todo.cmd add "标题" [--due "2026-10-30 09:00"] [--link "D:\...\x.md"] [--tags a,b] [--scope <id>]
  todo.cmd list [--all] [--scope <id>] [--json]
  todo.cmd done <id> [--scope <id>]
  todo.cmd rm <id> [--scope <id>]
  todo.cmd export [--md] [--scope <id>]
  todo.cmd where

说明：
  - 不给 --scope 时，从当前目录往上找 .todo\todos.json；找不到就用全局「我的待办」
  - 到期时间支持 2026-10-30 09:00 / 10-30 09:00 简写
'@ | Write-Output
}

# ---------- 参数解析（不用 PowerShell 绑定，避免 --due 之类的坑） ----------
$cmd = ''
$positional = @()
$opts = @{}
$raw = @($args)
$i = 0
while ($i -lt $raw.Count) {
    $a = [string]$raw[$i]
    if ($a -like '--*') {
        $key = $a.Substring(2).ToLowerInvariant()
        if (($i + 1) -lt $raw.Count -and -not ([string]$raw[$i + 1]).StartsWith('--')) {
            $opts[$key] = [string]$raw[$i + 1]
            $i += 2
        } else {
            $opts[$key] = 'true'
            $i += 1
        }
    } else {
        $positional += $a
        $i += 1
    }
}
if ($positional.Count -gt 0) { $cmd = $positional[0].ToLowerInvariant() }
$rest = @($positional | Select-Object -Skip 1)

# ---------- 初始化配置 ----------
$script:ConfigPath = Resolve-ConfigPath
$script:BaseDir = Split-Path -Parent $script:ConfigPath
try { Ensure-Config } catch { Fail ('读不到配置，也无法创建：' + $_.Exception.Message) }

function Get-Opt {
    param($Opts, [string]$Name)
    if ($Opts.ContainsKey($Name)) { return [string]$Opts[$Name] }
    return ''
}

# ---------- 定位清单 ----------
function Resolve-CliList {
    param([string]$ScopeId)
    $lists = @(Get-Lists)
    if (-not [string]::IsNullOrWhiteSpace($ScopeId)) {
        $hit = @($lists | Where-Object { $_.Id -eq $ScopeId })
        if ($hit.Count -eq 0) {
            $ids = @($lists | ForEach-Object { $_.Id }) -join ', '
            Fail ('没有 id 为 "' + $ScopeId + '" 的清单。现有：' + $ids)
        }
        return $hit[0]
    }
    $dir = (Get-Location).Path
    while (-not [string]::IsNullOrWhiteSpace($dir)) {
        # 认「.todo 目录」而不是 todos.json 文件：文件被删了也算这个工作区，add 会重建它
        $todoDir = Join-Path $dir '.todo'
        if (Test-Path -LiteralPath $todoDir) {
            $cand = Join-Path $todoDir 'todos.json'
            $full = [System.IO.Path]::GetFullPath($cand)
            $hit = @($lists | Where-Object { [string]$_.Path -eq $full })
            if ($hit.Count -gt 0) { return $hit[0] }
            return [pscustomobject]@{
                Index = -1
                Id    = (Get-WorkspaceId $dir)
                Name  = (Split-Path -Leaf $dir)
                Path  = $full
            }
        }
        $parent = Split-Path -Parent $dir
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) { break }
        $dir = $parent
    }
    [Console]::Error.WriteLine('提示：当前目录及其上级都没有 .todo\，这次用的是全局清单「' + $lists[0].Name + '」。要给本工作区建清单，先跑：todo.cmd init')
    return $lists[0]
}

# ---------- init ----------
function Write-AgentGuide {
    param([string]$Path, [string]$Name)
    $text = @"
# 本工作区待办 · 给 AI 的规则（AGENT.md）

> 这份文件由「待办托盘」生成/维护。**任何会话、任何 agent，先读这 20 行再动待办。**

## 1. 待办存在哪

- 本工作区：``.todo\todos.json``（唯一数据源，清单名：$Name）
- 全局：``%USERPROFILE%\.dsh\deepseek-todo\todos.json``
- **不要**把待办写进聊天、也不要只写在某个 ``.md`` 里。``.md`` 只能是条目里的 ``link`` 字段。

## 2. 怎么操作（只准用 CLI）

``````
todo.cmd list                 # 列出未完成
todo.cmd list --all           # 含已完成
todo.cmd add "标题" --due "2026-10-30 09:00" --link "D:\...\xxx.md" --tags 紧固件
todo.cmd done <id>            # 完成
todo.cmd rm   <id>            # 删除
todo.cmd export --md          # 导出成 Markdown（只读）
``````

**禁止**直接编辑 ``todos.json``（并发会互相覆盖）。

## 3. 什么该记待办

- 用户说「记一下 / 回头做 / 待确认 / 等我决定 / 后面抽时间」的事；
- 需要跨会话保留的结论或半成品；
- 定时任务（``--due``），让托盘到点提醒。

## 4. 什么不该记

- 本次会话马上就能做完的事；
- 已经有明确脚本/计划在跑、只差结果的（结果出来再记一条结论即可）。

## 5. 条目字段

``id / title / status(todo|doing|done) / due / tags[] / link / source / created / done_at``

- ``link`` 写**能一键打开的证据文件**（报告、核对表、CSV），不要写目录。
- ``source`` 写来源（哪次会话/谁的交代），方便回溯。
"@
    [System.IO.File]::WriteAllText($Path, ($text -replace "`r`n", "`n" -replace "`n", "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-Init {
    param($Opts)
    $ws = Get-Opt $Opts 'workspace'
    if ([string]::IsNullOrWhiteSpace($ws)) { $ws = (Get-Location).Path }
    $ws = [System.IO.Path]::GetFullPath($ws)
    if (-not (Test-Path -LiteralPath $ws)) { New-Item -ItemType Directory -Path $ws -Force | Out-Null }
    $todoDir = Join-Path $ws '.todo'
    if (-not (Test-Path -LiteralPath $todoDir)) { New-Item -ItemType Directory -Path $todoDir -Force | Out-Null }
    $todosPath = Join-Path $todoDir 'todos.json'
    $leaf = Split-Path -Leaf ($ws.TrimEnd('\'))
    $id = Get-WorkspaceId $ws

    if (-not (Test-Path -LiteralPath $todosPath)) {
        $doc = [ordered]@{ version = 1; scope = $id; name = $leaf; updatedAt = (Get-NowStamp); items = @() }
        Save-TextAtomic -Path $todosPath -Text ((ConvertTo-JsonText $doc) + "`n")
        Write-Output ('[ok] 清单已建：' + $todosPath)
    } else {
        Write-Output ('[skip] 清单已存在：' + $todosPath)
    }

    $agentPath = Join-Path $todoDir 'AGENT.md'
    if (-not (Test-Path -LiteralPath $agentPath)) {
        Write-AgentGuide -Path $agentPath -Name $leaf
        Write-Output ('[ok] 规则已建：' + $agentPath)
    } else {
        Write-Output ('[skip] 规则已存在：' + $agentPath)
    }

    $agentsPath = Join-Path $ws 'AGENTS.md'
    $needle = '本工作区的待办在 `.todo/todos.json`'
    $content = ''
    if (Test-Path -LiteralPath $agentsPath) { $content = [System.IO.File]::ReadAllText($agentsPath) }
    if ($content -notlike ('*' + $needle + '*')) {
        if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) { $content += "`n" }
        $block = "`n## 待办`n`n- 本工作区的待办在 ``.todo/todos.json``，操作请用 ``todo.cmd``，规则见 ``.todo/AGENT.md``。`n"
        [System.IO.File]::WriteAllText($agentsPath, ($content + $block), (New-Object System.Text.UTF8Encoding($false)))
        Write-Output ('[ok] 指针已写入：' + $agentsPath)
    } else {
        Write-Output ('[skip] AGENTS.md 里已有指针')
    }

    # 登记到全局 config
    $cfg = Get-Config
    $lists = @(Get-Lists)
    $exists = @($lists | Where-Object { [string]$_.Path -eq $todosPath })
    if ($exists.Count -gt 0) {
        Write-Output ('[skip] 已登记到 config：' + $exists[0].Id + '（' + $exists[0].Name + '）')
    } else {
        $newId = $id
        $n = 2
        while (@($lists | Where-Object { $_.Id -eq $newId }).Count -gt 0) {
            $newId = $id + '-' + $n
            $n++
        }
        $raw = @()
        if ($null -ne $cfg) {
            $names = @($cfg.PSObject.Properties | ForEach-Object { $_.Name })
            if ($names -contains 'lists') { $raw = @($cfg.lists) }
            elseif ($names -contains 'scopes') { $raw = @($cfg.scopes) }
        }
        $raw += [ordered]@{ id = $newId; name = $leaf; dir = $ws; todos = $todosPath }
        if ($null -eq $cfg) { $cfg = [ordered]@{ version = 1; autostart = $false } }
        Set-Prop $cfg 'lists' @($raw)
        Set-Prop $cfg 'version' 1
        Save-TextAtomic -Path $script:ConfigPath -Text ((ConvertTo-JsonText $cfg) + "`n")
        Write-Output ('[ok] 已登记到 config：' + $newId + '（' + $leaf + '）')
    }
    Write-Output ''
    Write-Output ('托盘会自动发现这份清单（最多 10 秒）；清单 id = ' + $id)
    exit 0
}

# ---------- list ----------
function Invoke-List {
    param($Opts)
    $list = Resolve-CliList (Get-Opt $Opts 'scope')
    if (-not (Test-Path -LiteralPath $list.Path)) {
        Write-Output ('[空] 清单文件还不存在：' + $list.Path)
        exit 0
    }
    $doc = Read-JsonFile $list.Path
    if ($null -eq $doc) { Fail ('读不出 ' + $list.Path) }
    $all = ($opts.ContainsKey('all'))
    $items = @(Get-Prop $doc 'items' @())
    $now = Get-Date
    $rows = @()
    foreach ($it in $items) {
        $st = [string](Get-Prop $it 'status' 'todo')
        if (-not $all -and $st -eq 'done') { continue }
        $rows += $it
    }
    if ($opts.ContainsKey('json')) {
        Write-Output ((ConvertTo-JsonText ([ordered]@{ list = $list.Name; id = $list.Id; items = @($rows) })) -replace "\n", "`n")
        exit 0
    }
    Write-Output ('# ' + $list.Name + '　（' + $list.Id + '）　' + $list.Path)
    if ($rows.Count -eq 0) {
        Write-Output '（没有未完成的待办）'
        exit 0
    }
    foreach ($it in $rows) {
        $st = [string](Get-Prop $it 'status' 'todo')
        $mark = '[ ]'
        if ($st -eq 'done') { $mark = '[x]' }
        elseif ($st -eq 'doing') { $mark = '[~]' }
        $line = '{0} {1,-10} {2}' -f $mark, [string](Get-Prop $it 'id' ''), [string](Get-Prop $it 'title' '')
        $due = [string](Get-Prop $it 'due' '')
        if (-not [string]::IsNullOrWhiteSpace($due)) {
            $dd = ConvertTo-DateOrNull $due
            if ($null -ne $dd -and $dd -lt $now -and $st -ne 'done') { $line += '　**逾期 ' + $due + '**' }
            else { $line += '　到期 ' + $due }
        }
        $tags = @(Get-Prop $it 'tags' @())
        if ($tags.Count -gt 0) { $line += '　#' + ($tags -join ' #') }
        Write-Output $line
    }
    exit 0
}

# ---------- add ----------
function Invoke-Add {
    param($Opts, $Rest)
    if ($Rest.Count -lt 1 -or [string]::IsNullOrWhiteSpace([string]$Rest[0])) {
        Fail '缺少标题。例：todo.cmd add "补 304 材质" --due "10-30 09:00"' 2
    }
    $title = [string]$Rest[0]
    $dueText = Get-Opt $Opts 'due'
    if (-not [string]::IsNullOrWhiteSpace($dueText)) {
        $dd = ConvertTo-DateOrNull $dueText
        if ($null -eq $dd) { Fail ('到期时间看不懂：' + $dueText + '（例：2026-10-30 09:00 或 10-30 09:00）') 2 }
        $dueText = $dd.ToString('yyyy-MM-dd HH:mm')
    }
    $link = Get-Opt $Opts 'link'
    $tagsText = Get-Opt $Opts 'tags'
    $tags = @()
    if (-not [string]::IsNullOrWhiteSpace($tagsText)) {
        $tags = @($tagsText -split '[,，]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    }
    $list = Resolve-CliList (Get-Opt $Opts 'scope')
    $lock = Enter-FileLock -Path $list.Path
    try {
        if ($null -eq $lock) { Write-Warning '没拿到文件锁（2 秒超时），仍继续写入' }
        $doc = Get-TodoDocForWrite $list
        $items = @(Get-Prop $doc 'items' @())
        $newItem = [ordered]@{
            id      = (New-TodoId -Items $items)
            title   = $title.Trim()
            status  = 'todo'
            due     = $dueText
            tags    = @($tags)
            link    = $link
            source  = 'cli'
            created = (Get-NowStamp)
            done_at = ''
        }
        $items = @($items) + $newItem
        Set-Prop $doc 'items' @($items)
        Save-TodoDoc -Doc $doc -Path $list.Path | Out-Null
    } finally {
        Exit-FileLock $lock
    }
    Write-Output ('[ok] ' + $newItem.id + '　' + $newItem.title + $(if ($dueText) { '　到期 ' + $dueText } else { '' }))
    exit 0
}

# ---------- done / rm ----------
function Invoke-SetStatus {
    param($Opts, $Rest)
    if ($Rest.Count -lt 1) { Fail '缺少 id。例：todo.cmd done sw-003' 2 }
    $id = [string]$Rest[0]
    $list = Resolve-CliList (Get-Opt $Opts 'scope')
    if (-not (Test-Path -LiteralPath $list.Path)) { Fail ('清单不存在：' + $list.Path) }
    $lock = Enter-FileLock -Path $list.Path
    try {
        $doc = Read-JsonFile $list.Path
        if ($null -eq $doc) { Fail ('读不出 ' + $list.Path) }
        $items = @(Get-Prop $doc 'items' @())
        $found = $false
        foreach ($it in $items) {
            if ([string](Get-Prop $it 'id' '') -eq $id) {
                $found = $true
                Set-Prop $it 'status' 'done'
                Set-Prop $it 'done_at' (Get-NowStamp)
            }
        }
        if (-not $found) { Fail ('清单里没有 id = ' + $id) }
        Set-Prop $doc 'items' @($items)
        Save-TodoDoc -Doc $doc -Path $list.Path | Out-Null
    } finally {
        Exit-FileLock $lock
    }
    Write-Output ('[ok] 已完成 ' + $id)
    exit 0
}

function Invoke-Delete {
    param($Opts, $Rest)
    if ($Rest.Count -lt 1) { Fail '缺少 id。例：todo.cmd rm sw-007' 2 }
    $id = [string]$Rest[0]
    $list = Resolve-CliList (Get-Opt $Opts 'scope')
    $lock = Enter-FileLock -Path $list.Path
    try {
        $okDel = Remove-TodoItem -Path $list.Path -ItemId $id
    } finally {
        Exit-FileLock $lock
    }
    if (-not $okDel) { Fail ('没删掉：清单里没有 id = ' + $id + '，或文件不存在') }
    Write-Output ('[ok] 已删除 ' + $id)
    exit 0
}

# ---------- export ----------
function Invoke-Export {
    param($Opts)
    $list = Resolve-CliList (Get-Opt $Opts 'scope')
    if (-not (Test-Path -LiteralPath $list.Path)) { Fail ('清单不存在：' + $list.Path) }
    $doc = Read-JsonFile $list.Path
    if ($null -eq $doc) { Fail ('读不出 ' + $list.Path) }
    $md = Export-TodoMarkdown -Doc $doc -ListName $list.Name
    Write-Output ($md.TrimEnd())
    exit 0
}

# ---------- where ----------
function Invoke-Where {
    param($Opts)
    $list = Resolve-CliList (Get-Opt $Opts 'scope')
    Write-Output ('清单：' + $list.Name + '（' + $list.Id + '）')
    Write-Output ('文件：' + $list.Path)
    Write-Output ('存在：' + (Test-Path -LiteralPath $list.Path))
    exit 0
}

# ---------- 分发 ----------
switch ($cmd) {
    'init'   { Invoke-Init $opts }
    'add'    { Invoke-Add $opts $rest }
    'list'   { Invoke-List $opts }
    'ls'     { Invoke-List $opts }
    'done'   { Invoke-SetStatus $opts $rest }
    'rm'     { Invoke-Delete $opts $rest }
    'del'    { Invoke-Delete $opts $rest }
    'export' { Invoke-Export $opts }
    'where'  { Invoke-Where $opts }
    'help'   { Show-Usage; exit 0 }
    '-h'     { Show-Usage; exit 0 }
    '--help' { Show-Usage; exit 0 }
    ''       { Show-Usage; exit 0 }
    default  { Fail ('不认识的命令：' + $cmd + '（用 todo.cmd help 看用法）') 2 }
}
