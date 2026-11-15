# ============================================================
#  dsh-todo-tray · 公共函数库（托盘 todo-tray.ps1 与 CLI todo-cli.ps1 共用）
#  只放不依赖界面的东西：JSON 读写、配置、清单发现、原子写盘、文件锁
#  用法：. (Join-Path $PSScriptRoot 'todo-lib.ps1')
# ============================================================
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    if ($script:NoLog) { return }
    if ([string]::IsNullOrWhiteSpace($script:BaseDir)) { return }
    try {
        $dir = Join-Path $script:BaseDir 'logs'
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $file = Join-Path $dir 'todo-tray.log'
        if ((Test-Path -LiteralPath $file) -and ((Get-Item -LiteralPath $file).Length -gt 524288)) {
            $bak = Join-Path $dir 'todo-tray.log.1'
            if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Force }
            Move-Item -LiteralPath $file -Destination $bak -Force
        }
        $line = '{0} [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Level, $Message
        Add-Content -LiteralPath $file -Value $line -Encoding UTF8
    } catch { }
}

function Get-Prop {
    param($Obj, [string]$Name, $Default = $null)
    if ($null -eq $Obj) { return $Default }
    # 有序字典/哈希表：[ordered]@{} 的键不在 PSObject.Properties 里，必须按字典取
    if ($Obj -is [System.Collections.IDictionary]) {
        if (-not $Obj.Contains($Name)) { return $Default }
        $v = $Obj[$Name]
        if ($null -eq $v) { return $Default }
        return $v
    }
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) { return $Default }
    if ($null -eq $p.Value) { return $Default }
    return $p.Value
}

function Set-Prop {
    param($Obj, [string]$Name, $Value)
    if ($null -eq $Obj) { return }
    if ($Obj -is [System.Collections.IDictionary]) {
        $Obj[$Name] = $Value
        return
    }
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) {
        $Obj | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    } else {
        $p.Value = $Value
    }
}

function ConvertTo-DateOrNull {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $s = $Text.Trim()
    $formats = [string[]]@(
        'yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm', 'yyyy-MM-dd',
        'yyyy/MM/dd HH:mm:ss', 'yyyy/MM/dd HH:mm', 'yyyy/MM/dd',
        'yyyy-MM-ddTHH:mm:ss', 'yyyy-MM-ddTHH:mm:sszzz', 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    )
    # 简写：10-27 21:00（补当前年份）
    if ($s -match '^(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})(:\d{2})?$') {
        try {
            $d0 = New-Object System.DateTime((Get-Date).Year, [int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4], 0)
            return $d0
        } catch { }
    }
    $d = [datetime]::MinValue
    $ci = [System.Globalization.CultureInfo]::InvariantCulture
    if ([datetime]::TryParseExact($s, $formats, $ci, [System.Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
    if ([datetime]::TryParse($s, [System.Globalization.CultureInfo]::GetCultureInfo('zh-CN'), [System.Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
    return $null
}

function Get-NowStamp {
    return (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
}

function Get-PathHash {
    param([string]$Text)
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try { $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text.ToLowerInvariant())) }
    finally { $md5.Dispose() }
    return (($bytes[0..3] | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Resolve-UserPath {
    param([string]$Path, [string]$BaseDir)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $p = [Environment]::ExpandEnvironmentVariables($Path.Trim())
    if ([System.IO.Path]::IsPathRooted($p)) { return [System.IO.Path]::GetFullPath($p) }
    return [System.IO.Path]::GetFullPath((Join-Path $BaseDir $p))
}

# ============================================================
#  JSON：读（ConvertFrom-Json）+ 写（自写序列化，保留中文与字段顺序）
#  用自写序列化是因为 PS 5.1 的 ConvertTo-Json 会把中文转成 \uXXXX、
#  并且会丢掉 PSCustomObject 之外的顺序；todos.json 要人/agent 都能直接读。
# ============================================================

function ConvertTo-JsonStringLiteral {
    param([string]$Text)
    if ($null -eq $Text) { return 'null' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append([char]34)
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        if ($ch -eq [char]34) { [void]$sb.Append('\"') }
        elseif ($ch -eq [char]92) { [void]$sb.Append('\\') }
        elseif ($code -eq 8) { [void]$sb.Append('\b') }
        elseif ($code -eq 12) { [void]$sb.Append('\f') }
        elseif ($code -eq 10) { [void]$sb.Append('\n') }
        elseif ($code -eq 13) { [void]$sb.Append('\r') }
        elseif ($code -eq 9) { [void]$sb.Append('\t') }
        elseif ($code -lt 32) { [void]$sb.Append(('\u{0:x4}' -f $code)) }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append([char]34)
    return $sb.ToString()
}

function ConvertTo-JsonText {
    param($Value, [int]$Depth = 0)
    $ind  = '  ' * $Depth
    $ind2 = '  ' * ($Depth + 1)

    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [string]) { return (ConvertTo-JsonStringLiteral $Value) }
    if ($Value -is [char]) { return (ConvertTo-JsonStringLiteral ([string]$Value)) }
    if ($Value -is [datetime]) { return (ConvertTo-JsonStringLiteral ($Value.ToString('yyyy-MM-ddTHH:mm:sszzz'))) }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [single] -or
        $Value -is [decimal] -or $Value -is [int16] -or $Value -is [byte] -or $Value -is [uint32] -or $Value -is [uint64]) {
        return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }

    # 数组
    if ($Value -is [System.Collections.IList]) {
        $arr = @($Value)
        if ($arr.Count -eq 0) { return '[]' }
        $parts = @()
        foreach ($v in $arr) {
            $parts += ($ind2 + (ConvertTo-JsonText -Value $v -Depth ($Depth + 1)))
        }
        return ("[`n" + ($parts -join ",`n") + "`n$ind]")
    }

    # 有序字典（[ordered]@{}）
    if ($Value -is [System.Collections.IDictionary]) {
        $keys = @($Value.Keys)
        if ($keys.Count -eq 0) { return '{}' }
        $parts = @()
        foreach ($k in $keys) {
            $parts += ($ind2 + (ConvertTo-JsonStringLiteral ([string]$k)) + ': ' +
                       (ConvertTo-JsonText -Value $Value[$k] -Depth ($Depth + 1)))
        }
        return ("{`n" + ($parts -join ",`n") + "`n$ind}")
    }

    # ConvertFrom-Json 出来的 PSCustomObject
    $props = @($Value.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' -or $_.MemberType -eq 'Property' })
    if ($props.Count -gt 0) {
        $parts = @()
        foreach ($p in $props) {
            $parts += ($ind2 + (ConvertTo-JsonStringLiteral ([string]$p.Name)) + ': ' +
                       (ConvertTo-JsonText -Value $p.Value -Depth ($Depth + 1)))
        }
        return ("{`n" + ($parts -join ",`n") + "`n$ind}")
    }

    return (ConvertTo-JsonStringLiteral ([string]$Value))
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $text = [System.IO.File]::ReadAllText($Path)
    } catch {
        Write-Log ("读取失败 {0} :: {1}" -f $Path, $_.Exception.Message) 'ERROR'
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try {
        return (ConvertFrom-Json -InputObject $text)
    } catch {
        Write-Log ("JSON 解析失败 {0} :: {1}" -f $Path, $_.Exception.Message) 'ERROR'
        return $null
    }
}

function Save-TextAtomic {
    param([string]$Path, [string]$Text)
    $dir = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($dir)) { $dir = '.' }
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = Join-Path $dir ('.' + (Split-Path -Leaf $Path) + '.tmp')
    # 不带 BOM 的 UTF-8：与现有 todos.json 保持一致，agent 用 read 工具直接可读
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tmp, $Text, $enc)
    try {
        if (Test-Path -LiteralPath $Path) {
            try {
                [System.IO.File]::Replace($tmp, $Path, $null)
            } catch {
                # 网络盘 / 被占用时回退：先备份再覆盖
                Copy-Item -LiteralPath $Path -Destination ($Path + '.bak') -Force -ErrorAction SilentlyContinue
                Copy-Item -LiteralPath $tmp -Destination $Path -Force
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            }
        } else {
            [System.IO.File]::Move($tmp, $Path)
        }
    } catch {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        throw
    }
}

# ============================================================
#  配置 & 数据
# ============================================================

# 0.2.3：便携模式 —— 程序目录下放一个 portable.flag（空文件也行），
#         数据就落在 <程序目录>\data\，完全不碰 %USERPROFILE%\.dsh\。
function Test-PortableMode {
    param([string]$BaseDir = $PSScriptRoot)
    if ([string]::IsNullOrWhiteSpace($BaseDir)) { return $false }
    return (Test-Path -LiteralPath (Join-Path $BaseDir 'portable.flag'))
}

function Resolve-ConfigPath {
    param([string]$AppDir = $PSScriptRoot)
    # 显式 -ConfigPath 优先。注意 $ConfigPath 与 $script:ConfigPath 是同一个变量，
    # 主流程后面会改写它，所以入口脚本会先存一份 $script:ParamConfigPath。
    $explicit = ''
    $pv = Get-Variable -Name ParamConfigPath -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $pv) { $explicit = [string]$pv.Value } else { $explicit = [string]$ConfigPath }
    if (-not [string]::IsNullOrWhiteSpace($explicit)) {
        return [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($explicit))
    }
    if (Test-PortableMode -BaseDir $AppDir) {
        return (Join-Path $AppDir 'data\config.json')
    }
    $home2 = $env:USERPROFILE
    if ([string]::IsNullOrWhiteSpace($home2)) { $home2 = $env:HOME }
    if ([string]::IsNullOrWhiteSpace($home2)) { throw '找不到 USERPROFILE，无法定位配置文件。' }
    return (Join-Path $home2 '.dsh\deepseek-todo\config.json')
}

function New-DefaultConfig {
    param([string]$Path, [bool]$Portable = $false)
    # 便携模式：清单用相对路径（按 config 所在目录解析）→ <程序目录>\data\todos.json
    $todosPath = '%USERPROFILE%\.dsh\deepseek-todo\todos.json'
    if ($Portable) { $todosPath = 'todos.json' }
    # 0.3.35：默认设置 = 用户 2026-11-10 16:04 现用的那套（用户定「这个是适合的默认设置」）
    # 0.3.36：开机自启也进默认（用户 2026-11-10 17:3x 定「默认开机自启」）；便携模式不写启动项。
    # 只影响「新建 config」；已有 config.json 一律不动。
    $autoDefault = -not $Portable
    $cfg = [ordered]@{
        version   = 1
        autostart = $autoDefault
        notify    = [ordered]@{ aheadMinutes = 0; missedOnStartup = $true }
        ui        = [ordered]@{
            mode        = 'always'   # 常驻悬浮（不是 N 秒自动隐藏）
            hideSeconds = 5          # 只有 mode=auto 时用
            opacity     = 35         # 透明度 35%
            topmost     = $true
            hoverMs     = 3000       # 悬停 3 秒进交互
            bubble      = [ordered]@{ enabled = $true; maxSeconds = 15 }
        }
        lists     = @(
            [ordered]@{
                id    = 'default'
                name  = '我的待办'
                todos = $todosPath
            }
        )
    }
    Save-TextAtomic -Path $Path -Text ((ConvertTo-JsonText $cfg) + "`n")
}

function Ensure-Config {
    if (Test-Path -LiteralPath $script:ConfigPath) { return }
    # 判断是否便携：config 在 <某目录>\data\config.json，且上层有 portable.flag
    $portable = $false
    $cfgDir = Split-Path -Parent $script:ConfigPath
    if ((Split-Path -Leaf $cfgDir) -eq 'data') {
        $appDir = Split-Path -Parent $cfgDir
        if (-not [string]::IsNullOrWhiteSpace($appDir)) { $portable = (Test-Path -LiteralPath (Join-Path $appDir 'portable.flag')) }
    }
    New-DefaultConfig -Path $script:ConfigPath -Portable $portable
    # 首次运行时顺手建一份空清单，免得一打开面板就是「文件不存在」
    foreach ($l in @(Get-Lists)) {
        if (-not (Test-Path -LiteralPath $l.Path)) {
            $doc = [ordered]@{ version = 1; scope = $l.Id; name = $l.Name; updatedAt = (Get-NowStamp); items = @() }
            Save-TextAtomic -Path $l.Path -Text ((ConvertTo-JsonText $doc) + "`n")
            Write-Log ('已生成空清单: ' + $l.Path)
        }
    }
}

function Get-Config {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) { return $null }
    return (Read-JsonFile $script:ConfigPath)
}

function Get-Lists {
    $cfg = Get-Config
    $raw = @()
    $names = @()
    if ($null -ne $cfg) { $names = @($cfg.PSObject.Properties | ForEach-Object { $_.Name }) }

    if ($names -contains 'lists') { $raw = @($cfg.lists) }
    elseif ($names -contains 'scopes') { $raw = @($cfg.scopes) }   # 兼容设计说明 §4 的旧写法

    $out = @()
    $i = 0
    foreach ($l in $raw) {
        if ($null -eq $l) { continue }
        $id = [string](Get-Prop $l 'id' '')
        if ([string]::IsNullOrWhiteSpace($id)) { $id = 'list' + $i }
        $name = [string](Get-Prop $l 'name' '')
        if ([string]::IsNullOrWhiteSpace($name)) { $name = $id }
        $tp = [string](Get-Prop $l 'todos' '')
        if ([string]::IsNullOrWhiteSpace($tp)) {
            $ld = [string](Get-Prop $l 'dir' '')
            if (-not [string]::IsNullOrWhiteSpace($ld)) {
                $tp = Join-Path ([Environment]::ExpandEnvironmentVariables($ld)) '.todo\todos.json'
            } else {
                $tp = 'todos.json'
            }
        }
        $resolved = Resolve-UserPath -Path $tp -BaseDir $script:BaseDir
        $out += [pscustomobject]@{ Index = $i; Id = $id; Name = $name; Path = $resolved }
        $i++
    }

    if ($out.Count -eq 0) {
        $out += [pscustomobject]@{
            Index = 0
            Id    = 'default'
            Name  = '我的待办'
            Path  = (Join-Path $script:BaseDir 'todos.json')
        }
    }
    return $out
}


function New-TodoId {
    param($Items)
    $prefix = 'todo-'
    $max = 0
    foreach ($it in @($Items)) {
        $id = [string](Get-Prop $it 'id' '')
        if ($id -match '^(.*?)(\d+)$') {
            $n = [int]$Matches[2]
            if ($n -gt $max) { $max = $n; $prefix = $Matches[1] }
        }
    }
    return ($prefix + ('{0:D3}' -f ($max + 1)))
}

function Add-TodoItem {
    param([int]$ListIndex, [string]$Title, [string]$DueText, [int]$Prio = 1)
    $lists = @(Get-Lists)
    if ($ListIndex -lt 0 -or $ListIndex -ge $lists.Count) { return $false }
    if ([string]::IsNullOrWhiteSpace($Title)) { return $false }
    if ($Prio -lt 1) { $Prio = 1 }
    if ($Prio -gt 3) { $Prio = 3 }
    $list = $lists[$ListIndex]
    $doc = $null
    if (Test-Path -LiteralPath $list.Path) { $doc = Read-JsonFile $list.Path }
    if ($null -eq $doc) {
        $doc = [ordered]@{ version = 1; scope = $list.Id; name = $list.Name; updatedAt = (Get-NowStamp); items = @() }
    }
    $items = @(Get-Prop $doc 'items' @())

    # R6：名额上限（3★ 1 个、2★ 2 个）。只算未完成条目——已完成的不占名额，
    # 否则「请先取消现有的」对一条 done 的 3★ 无法兑现。后端再判一次，防 UI 被绕过。
    if ($Prio -gt 1) {
        $u2 = 0
        $u3 = 0
        foreach ($l2 in $lists) {
            if (-not (Test-Path -LiteralPath $l2.Path)) { continue }
            $d2 = Read-JsonFile $l2.Path
            if ($null -eq $d2) { continue }
            foreach ($it2 in @(Get-Prop $d2 'items' @())) {
                if ($null -eq $it2) { continue }
                if ([string](Get-Prop $it2 'status' 'todo') -eq 'done') { continue }
                $p2 = [int](Get-Prop $it2 'prio' 1)
                if ($p2 -eq 3) { $u3++ } elseif ($p2 -eq 2) { $u2++ }
            }
        }
        if ($Prio -eq 3 -and $u3 -ge 1) { Write-Log '3★ 名额已满（只能 1 个），拒绝新增' 'WARN'; return $false }
        if ($Prio -eq 2 -and $u2 -ge 2) { Write-Log '2★ 名额已满（最多 2 个），拒绝新增' 'WARN'; return $false }
    }

    # R8：order = 同星级组内最大值 + 1（组内添加顺序）
    $maxOrder = -1
    foreach ($it in $items) {
        if ($null -eq $it) { continue }
        $p0 = [int](Get-Prop $it 'prio' 1)
        if ($p0 -ne $Prio) { continue }
        $o0 = [int](Get-Prop $it 'order' 0)
        if ($o0 -gt $maxOrder) { $maxOrder = $o0 }
    }

    $newItem = [ordered]@{
        id      = (New-TodoId -Items $items)
        title   = $Title.Trim()
        status  = 'todo'
        due     = $DueText.Trim()
        prio    = $Prio
        order   = ($maxOrder + 1)
        tags    = @()
        link    = ''
        source  = '托盘新增'
        created = (Get-NowStamp)
        done_at = ''
    }
    $items = @($items) + $newItem
    Set-Prop $doc 'items' @($items)
    Set-Prop $doc 'updatedAt' (Get-NowStamp)
    $text = (ConvertTo-JsonText $doc) + "`n"
    try {
        $check = ConvertFrom-Json -InputObject $text
        if (@(Get-Prop $check 'items' @()).Count -ne $items.Count) { throw '序列化自检失败：条数不一致' }
        Save-TextAtomic -Path $list.Path -Text $text
    } catch {
        Write-Log ('新增待办失败: ' + $_.Exception.Message) 'ERROR'
        return $false
    }
    Write-Log ('新增待办 ' + $list.Name + ' / ' + $newItem.id + ' / ' + $newItem.title)
    return $true
}
# ============================================================
#  v1-c：写盘统一入口 / 删条目 / 导出 / 文件锁
# ============================================================

# 统一写盘：强制 items 为数组、刷新 updatedAt、写前自检、原子替换
function Save-TodoDoc {
    param($Doc, [string]$Path)
    $items = @(Get-Prop $Doc 'items' @())
    Set-Prop $Doc 'items' @($items)
    Set-Prop $Doc 'updatedAt' (Get-NowStamp)
    $text = (ConvertTo-JsonText $Doc) + "`n"
    $check = ConvertFrom-Json -InputObject $text
    if (@(Get-Prop $check 'items' @()).Count -ne $items.Count) {
        throw '序列化自检失败：条数不一致'
    }
    Save-TextAtomic -Path $Path -Text $text
    return $text
}

# 取清单文档；不存在或读不出就返回一个空文档（CLI 的 add 会用到）
function Get-TodoDocForWrite {
    param($List)
    if (Test-Path -LiteralPath $List.Path) {
        $doc = Read-JsonFile $List.Path
        if ($null -ne $doc) { return $doc }
    }
    return [pscustomobject]@{
        version   = 1
        scope     = $List.Id
        name      = $List.Name
        updatedAt = (Get-NowStamp)
        items     = @()
    }
}

function Remove-TodoItem {
    param([string]$Path, [string]$ItemId)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $doc = Read-JsonFile $Path
    if ($null -eq $doc) { return $false }
    $items = @(Get-Prop $doc 'items' @())
    $kept = @($items | Where-Object { [string](Get-Prop $_ 'id' '') -ne $ItemId })
    if ($kept.Count -eq $items.Count) { return $false }
    Set-Prop $doc 'items' $kept
    Save-TodoDoc -Doc $doc -Path $Path | Out-Null
    return $true
}

function Export-TodoMarkdown {
    param($Doc, [string]$ListName)
    $items = @(Get-Prop $Doc 'items' @())
    $now = Get-Date
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# 待办 · ' + $ListName)
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('> 导出时间：' + $now.ToString('yyyy-MM-dd HH:mm') + '　数据源：todos.json')
    $open = @($items | Where-Object { [string](Get-Prop $_ 'status' 'todo') -ne 'done' })
    $done = @($items | Where-Object { [string](Get-Prop $_ 'status' 'todo') -eq 'done' })
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## 未完成（' + $open.Count + '）')
    [void]$sb.AppendLine('')
    if ($open.Count -eq 0) { [void]$sb.AppendLine('_（无）_') }
    foreach ($it in $open) {
        $line = '- [ ] `' + [string](Get-Prop $it 'id' '') + '` ' + [string](Get-Prop $it 'title' '')
        $due = [string](Get-Prop $it 'due' '')
        if (-not [string]::IsNullOrWhiteSpace($due)) {
            $dd = ConvertTo-DateOrNull $due
            if ($null -ne $dd -and $dd -lt $now) { $line += ' · **逾期 ' + $due + '**' }
            else { $line += ' · 到期 ' + $due }
        }
        $tags = @(Get-Prop $it 'tags' @())
        if ($tags.Count -gt 0) { $line += ' · #' + ($tags -join ' #') }
        $link = [string](Get-Prop $it 'link' '')
        if (-not [string]::IsNullOrWhiteSpace($link)) { $line += ' · [证据](' + $link + ')' }
        [void]$sb.AppendLine($line)
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## 已完成（' + $done.Count + '）')
    [void]$sb.AppendLine('')
    if ($done.Count -eq 0) { [void]$sb.AppendLine('_（无）_') }
    foreach ($it in $done) {
        $line = '- [x] `' + [string](Get-Prop $it 'id' '') + '` ' + [string](Get-Prop $it 'title' '')
        $doneAt = [string](Get-Prop $it 'done_at' '')
        if (-not [string]::IsNullOrWhiteSpace($doneAt)) { $line += ' · 完成于 ' + $doneAt }
        [void]$sb.AppendLine($line)
    }
    return $sb.ToString()
}

# 文件锁：todos.json 旁边放 .lock，独占打开；拿不到就等，超时返回 $null
function Enter-FileLock {
    param([string]$Path, [int]$TimeoutMs = 3000)
    $lockPath = $Path + '.lock'
    $dir = Split-Path -Parent $lockPath
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $deadline = (Get-Date).AddMilliseconds($TimeoutMs)
    while ($true) {
        try {
            return [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate,
                [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        } catch {
            if ((Get-Date) -gt $deadline) { return $null }
            Start-Sleep -Milliseconds 50
        }
    }
}

function Exit-FileLock {
    param($Stream)
    if ($null -eq $Stream) { return }
    try { $Stream.Dispose() } catch { }
}

# 工作区目录 → 清单 id（尽量用 ASCII；中文名退化成拼音没法做，就用前缀 + 短哈希）
function Get-WorkspaceId {
    param([string]$Dir)
    $leaf = Split-Path -Leaf ($Dir.TrimEnd('\'))
    $slug = ($leaf.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = 'ws-' + (Get-PathHash $leaf)
    }
    return $slug
}

# ============================================================
#  v1.8 M3：改条目（标题/到期/星级）与组内拖动排序
# ============================================================

function Update-TodoItem {
    param([int]$ListIndex, [string]$ItemId, [string]$Title, [string]$DueText, [int]$Prio = 1)
    $lists = @(Get-Lists)
    if ($ListIndex -lt 0 -or $ListIndex -ge $lists.Count) { return $false }
    if ([string]::IsNullOrWhiteSpace($ItemId)) { return $false }
    $list = $lists[$ListIndex]
    if (-not (Test-Path -LiteralPath $list.Path)) { return $false }
    $doc = Read-JsonFile $list.Path
    if ($null -eq $doc) { return $false }
    $items = @(Get-Prop $doc 'items' @())
    $target = $null
    foreach ($it in $items) {
        if ($null -ne $it -and [string](Get-Prop $it 'id' '') -eq $ItemId) { $target = $it; break }
    }
    if ($null -eq $target) { return $false }
    if ($Prio -lt 1) { $Prio = 1 }
    if ($Prio -gt 3) { $Prio = 3 }
    $oldPrio = [int](Get-Prop $target 'prio' 1)
    if ($Prio -ne $oldPrio) {
        # 名额：排除自己之后再数（否则「改成原星级」也会被自己挡住）
        $u2 = 0
        $u3 = 0
        foreach ($it2 in $items) {
            if ($null -eq $it2) { continue }
            if ([string](Get-Prop $it2 'id' '') -eq $ItemId) { continue }
            if ([string](Get-Prop $it2 'status' 'todo') -eq 'done') { continue }
            $p2 = [int](Get-Prop $it2 'prio' 1)
            if ($p2 -eq 3) { $u3++ } elseif ($p2 -eq 2) { $u2++ }
        }
        if ($Prio -eq 3 -and $u3 -ge 1) { Write-Log '3★ 名额已满（只能 1 个），拒绝改星级' 'WARN'; return $false }
        if ($Prio -eq 2 -and $u2 -ge 2) { Write-Log '2★ 名额已满（最多 2 个），拒绝改星级' 'WARN'; return $false }
        # 换组后排到新组末尾
        $maxOrder = -1
        foreach ($it2 in $items) {
            if ($null -eq $it2 -or [string](Get-Prop $it2 'id' '') -eq $ItemId) { continue }
            if ([int](Get-Prop $it2 'prio' 1) -ne $Prio) { continue }
            $o2 = [int](Get-Prop $it2 'order' 0)
            if ($o2 -gt $maxOrder) { $maxOrder = $o2 }
        }
        Set-Prop $target 'order' ($maxOrder + 1)
    }
    if (-not [string]::IsNullOrWhiteSpace($Title)) { Set-Prop $target 'title' $Title.Trim() }
    Set-Prop $target 'due' $DueText.Trim()
    Set-Prop $target 'prio' $Prio
    try {
        Save-TodoDoc -Doc $doc -Path $list.Path | Out-Null
    } catch {
        Write-Log ('改条目失败: ' + $_.Exception.Message) 'ERROR'
        return $false
    }
    Write-Log ('改条目 ' + $list.Name + ' / ' + $ItemId + ' / prio=' + $Prio)
    return $true
}

# 组内拖动：把某条移到它所在星级组的第 TargetIndex 位（0 起），只重排该组的 order
function Move-TodoGroupItem {
    param([int]$ListIndex, [string]$ItemId, [int]$TargetIndex)
    $lists = @(Get-Lists)
    if ($ListIndex -lt 0 -or $ListIndex -ge $lists.Count) { return $false }
    $list = $lists[$ListIndex]
    if (-not (Test-Path -LiteralPath $list.Path)) { return $false }
    $doc = Read-JsonFile $list.Path
    if ($null -eq $doc) { return $false }
    $items = @(Get-Prop $doc 'items' @())
    $target = $null
    foreach ($it in $items) {
        if ($null -ne $it -and [string](Get-Prop $it 'id' '') -eq $ItemId) { $target = $it; break }
    }
    if ($null -eq $target) { return $false }
    $prio = [int](Get-Prop $target 'prio' 1)
    $group = @($items | Where-Object { $null -ne $_ -and [int](Get-Prop $_ 'prio' 1) -eq $prio } |
        Sort-Object -Property @{ Expression = { [int](Get-Prop $_ 'order' 0) } }, @{ Expression = { [string](Get-Prop $_ 'id' '') } })
    $cur = -1
    for ($i = 0; $i -lt $group.Count; $i++) {
        if ([string](Get-Prop $group[$i] 'id' '') -eq $ItemId) { $cur = $i; break }
    }
    if ($cur -lt 0) { return $false }
    if ($TargetIndex -lt 0) { $TargetIndex = 0 }
    if ($TargetIndex -gt ($group.Count - 1)) { $TargetIndex = $group.Count - 1 }
    if ($TargetIndex -eq $cur) { return $true }
    $arr = New-Object System.Collections.ArrayList
    foreach ($g in $group) { [void]$arr.Add($g) }
    $arr.RemoveAt($cur)
    $arr.Insert($TargetIndex, $target)
    for ($i = 0; $i -lt $arr.Count; $i++) { Set-Prop $arr[$i] 'order' $i }
    try {
        Save-TodoDoc -Doc $doc -Path $list.Path | Out-Null
    } catch {
        Write-Log ('拖动排序写盘失败: ' + $_.Exception.Message) 'ERROR'
        return $false
    }
    Write-Log ('拖动排序 ' + $list.Name + ' / ' + $ItemId + ' -> 组内第 ' + ($TargetIndex + 1) + ' 位')
    return $true
}

# ============================================================
#  v1.8 M4：导出（CSV 必做；xlsx 用本机 Excel/WPS 的 COM，失败就只给 CSV）
#  口径：已完成 = 完成时间/标题/星级/清单/标签/来源链接
#        全部   = 状态/标题/星级/到期/清单/标签/添加时间/完成时间/来源链接
# ============================================================

function Get-ExportRows {
    param([switch]$DoneOnly)
    $rows = @()
    foreach ($l in @(Get-Lists)) {
        if (-not (Test-Path -LiteralPath $l.Path)) { continue }
        $doc = Read-JsonFile $l.Path
        if ($null -eq $doc) { continue }
        $items = @(Get-Prop $doc 'items' @())
        for ($i = 0; $i -lt $items.Count; $i++) {
            $it = $items[$i]
            if ($null -eq $it) { continue }
            $status = [string](Get-Prop $it 'status' 'todo')
            if ($DoneOnly -and $status -ne 'done') { continue }
            $rows += [pscustomobject]@{
                DoneAt    = [string](Get-Prop $it 'done_at' '')
                Title     = [string](Get-Prop $it 'title' '')
                Prio      = [int](Get-Prop $it 'prio' 1)
                ListName  = $l.Name
                Tags      = (@(Get-Prop $it 'tags' @()) -join ',')
                Link      = [string](Get-Prop $it 'link' '')
                Status    = $status
                Due       = [string](Get-Prop $it 'due' '')
                Created   = [string](Get-Prop $it 'created' '')
                Order     = [int](Get-Prop $it 'order' $i)
                ListIndex = [int]$l.Index
            }
        }
    }
    return @($rows | Sort-Object -Property @{ Expression = { [int]$_.ListIndex } }, @{ Expression = { -1 * [int]$_.Prio } }, @{ Expression = { [int]$_.Order } })
}

function Get-ExportFolder {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if ([string]::IsNullOrWhiteSpace($docs)) { $docs = $script:BaseDir }
    return (Join-Path $docs '待办导出')
}

function New-ExportPath {
    param([string]$Kind = 'done', [datetime]$At = (Get-Date))
    $name = '待办_全部_' + $At.ToString('yyyyMMdd_HHmm') + '.csv'
    if ($Kind -eq 'done') { $name = '待办_已完成_' + $At.ToString('yyyyMMdd_HHmm') + '.csv' }
    return (Join-Path (Get-ExportFolder) $name)
}

function ConvertTo-CsvCell {
    param([string]$Text)
    $s = $Text
    if ($null -eq $s) { $s = '' }
    if ($s -match '[",\r\n]') { $s = '"' + ($s -replace '"', '""') + '"' }
    return $s
}

# 生成 CSV 文本（不写盘，自检直接用）
function Get-ExportCsvText {
    param([string]$Kind = 'done')
    $doneOnly = ($Kind -eq 'done')
    $rows = @(Get-ExportRows -DoneOnly:$doneOnly)
    $sb = New-Object System.Text.StringBuilder
    if ($doneOnly) {
        [void]$sb.AppendLine('完成时间,标题,星级,清单,标签,来源链接')
        foreach ($r in $rows) {
            $cells = @(
                (ConvertTo-CsvCell $r.DoneAt), (ConvertTo-CsvCell $r.Title), ('{0}★' -f $r.Prio),
                (ConvertTo-CsvCell $r.ListName), (ConvertTo-CsvCell $r.Tags), (ConvertTo-CsvCell $r.Link)
            )
            [void]$sb.AppendLine(($cells -join ','))
        }
    } else {
        [void]$sb.AppendLine('状态,标题,星级,到期,清单,标签,添加时间,完成时间,来源链接')
        foreach ($r in $rows) {
            $cells = @(
                (ConvertTo-CsvCell $r.Status), (ConvertTo-CsvCell $r.Title), ('{0}★' -f $r.Prio),
                (ConvertTo-CsvCell $r.Due), (ConvertTo-CsvCell $r.ListName), (ConvertTo-CsvCell $r.Tags),
                (ConvertTo-CsvCell $r.Created), (ConvertTo-CsvCell $r.DoneAt), (ConvertTo-CsvCell $r.Link)
            )
            [void]$sb.AppendLine(($cells -join ','))
        }
    }
    return $sb.ToString()
}

function Export-TodoCsv {
    param([string]$Path, [string]$Kind = 'done')
    $text = Get-ExportCsvText -Kind $Kind
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    # Excel 双击不乱码：UTF-8 带 BOM
    [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($true)))
    Write-Log ('导出 CSV ' + $Path)
    return $true
}

# xlsx：借本机 Excel/WPS 的 COM；没有组件或失败就返回 $false，由界面提示只给 CSV
function Export-TodoXlsx {
    param([string]$Path, [string]$Kind = 'done')
    $doneOnly = ($Kind -eq 'done')
    $rows = @(Get-ExportRows -DoneOnly:$doneOnly)
    $app = $null
    $wb = $null
    try {
        $app = New-Object -ComObject Excel.Application
        $app.Visible = $false
        $app.DisplayAlerts = $false
        $wb = $app.Workbooks.Add()
        $ws = $wb.Worksheets.Item(1)
        $headers = @('状态', '标题', '星级', '到期', '清单', '标签', '添加时间', '完成时间', '来源链接')
        if ($doneOnly) { $headers = @('完成时间', '标题', '星级', '清单', '标签', '来源链接') }
        for ($c = 0; $c -lt $headers.Count; $c++) { $ws.Cells.Item(1, $c + 1).Value2 = $headers[$c] }
        $r = 2
        foreach ($row in $rows) {
            if ($doneOnly) {
                $vals = @($row.DoneAt, $row.Title, ('{0}★' -f $row.Prio), $row.ListName, $row.Tags, $row.Link)
            } else {
                $vals = @($row.Status, $row.Title, ('{0}★' -f $row.Prio), $row.Due, $row.ListName, $row.Tags, $row.Created, $row.DoneAt, $row.Link)
            }
            for ($c = 0; $c -lt $vals.Count; $c++) { $ws.Cells.Item($r, $c + 1).Value2 = [string]$vals[$c] }
            $r++
        }
        $dir = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $wb.SaveAs($Path, 51)   # 51 = xlOpenXMLWorkbook (.xlsx)
        Write-Log ('导出 xlsx ' + $Path)
        return $true
    } catch {
        Write-Log ('导出 xlsx 失败（将只给 CSV）: ' + $_.Exception.Message) 'WARN'
        return $false
    } finally {
        try { if ($null -ne $wb) { $wb.Close($false) } } catch { }
        try { if ($null -ne $app) { $app.Quit() } } catch { }
        try { if ($null -ne $ws) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($ws) } } catch { }
        try { if ($null -ne $wb) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wb) } } catch { }
        try { if ($null -ne $app) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) } } catch { }
        [GC]::Collect()
    }
}

# 统一出口：要 xlsx 但 COM 不可用/失败 → 自动回落 CSV（R13 硬要求）
# -DisableXlsxForTest 只给自检用，模拟「本机没有 Excel/WPS」
function Export-TodoTable {
    param([string]$Kind = 'done', [string]$Format = 'csv', [string]$Dir = $null, [switch]$DisableXlsxForTest)
    if ([string]::IsNullOrWhiteSpace($Dir)) { $Dir = Get-ExportFolder }
    if (-not (Test-Path -LiteralPath $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    $at = Get-Date
    $label = '全部'
    if ($Kind -eq 'done') { $label = '已完成' }
    $baseName = '待办_' + $label + '_' + $at.ToString('yyyyMMdd_HHmm')
    $fallback = $false
    if ($Format -eq 'xlsx') {
        if (-not $DisableXlsxForTest) {
            $xlsxPath = Join-Path $Dir ($baseName + '.xlsx')
            if (Export-TodoXlsx -Path $xlsxPath -Kind $Kind) {
                return [pscustomobject]@{ Path = $xlsxPath; Format = 'xlsx'; Fallback = $false }
            }
        }
        $fallback = $true
        Write-Log 'xlsx 不可用，回落 CSV' 'WARN'
    }
    $csvPath = Join-Path $Dir ($baseName + '.csv')
    Export-TodoCsv -Path $csvPath -Kind $Kind | Out-Null
    return [pscustomobject]@{ Path = $csvPath; Format = 'csv'; Fallback = $fallback }
}