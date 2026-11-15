# dsh-todo-tray · 待办托盘

常驻 Windows 托盘的轻量待办清单：点开是一张悬浮清单，收起是屏幕边上一只摇尾巴的小鲸鱼。
**零依赖、不联网、不写注册表** —— 只用 Windows 自带的 PowerShell 5.1 + WinForms，解压即用。

当前版本 **v0.3.40**（完整版本史见 [CHANGELOG.md](CHANGELOG.md)）。

![待办托盘面板](screenshots/v0.3.40/panel.png)

## 这是什么

- **常驻不挡路**：面板平时半透明「点穿」，鼠标悬停 3 秒（可调）才变可交互；失焦自动收起。
- **收成小鲸鱼**：面板拖到屏幕边收成 24×72 的小鲸鱼，可以上下拖、换边、右键出菜单；小鲸鱼会摇尾巴。
- **气泡提醒**：收起状态每隔 15~60 秒冒一个待办气泡（6 秒），3★/2★ 优先。
- **多清单**：工作 / 生活 / 任意文件夹下的 `.todo\todos.json` 都能挂进来，清单可改名、移除（数据文件保留）。
- **星级与名额**：2★/3★ 标记重点，名额只算未完成条目。
- **到期提醒**：到点弹通知，可设提前量；关电脑错过的，下次启动补提醒一次。
- **导出**：导出 CSV；本机有 Excel / WPS 时也能导出 xlsx。
- **开机自启（可选）**：只写「启动」文件夹里的一个 `dsh-todo-tray.cmd`，不写注册表、不装服务。

## 环境要求

| 项 | 要求 |
|---|---|
| 系统 | Windows 10 / 11（x64） |
| 运行时 | Windows PowerShell **5.1**（系统自带，无需安装） |
| 界面 | .NET Framework 自带的 WinForms |
| 权限 | 普通用户即可，**不需要管理员** |
| 网络 | **完全不需要**（无联网、无遥测） |

## 安装（3 步）

1. 下载 Release 里的 `dsh-todo-tray-0.3.40-open.zip`，解压到任意文件夹
   （**别放 `C:\Program Files`** 之类需要管理员权限的位置，否则写不了数据）。
2. 双击 **`scripts\start-todo-tray.cmd`** —— 走 wscript 宿主，**不会留黑框**。
3. 看托盘：Win11 默认把新图标收进 `^` 溢出区，找不到就点任务栏的 `^`。
   首次启动会在 `%USERPROFILE%\.dsh\deepseek-todo\` 自动建 `config.json` / `todos.json`。

> 新装默认：常驻悬浮、35% 透明、悬停 3 秒进交互、冒泡开、开机自启**开**（可在「设置」里关）。

## 快速开始

- **新增**：面板底部「＋ 新增」，填标题、到期时间（`11-20 09:00` 这种简写也行）、标签。
- **完成**：左侧方框勾选；已完成的条目会淡出，5 秒后从列表消失（可撤销）。
- **编辑 / 删除 / 排序**：点一行进入编辑态（编辑、拖动排序、删除）；删除有二次确认 + 15 秒撤销。
- **清单**：顶部清单下拉 → 选「全部清单」或某个清单；下拉底部「＋ 新建清单…」可把任意文件夹挂进来。
- **收成小鲸鱼**：按住标题条把面板拖到屏幕左/右边缘，自动收成小鲸鱼；小鲸鱼右键有菜单（显示待办 / 新增 / 新建清单 / 清单管理 / 设置 / 关闭小鲸鱼 / 退出）。
- **图钉**：钉住后面板不再自动收回、可拖动、鼠标悬停才可交互。
- **设置**：底部「设置」——模式（常驻 / 自动隐藏）、透明度、悬停毫秒数、冒泡开关与间隔、开机自启、导出目录。
- **托盘图标**：图标上的数字 = 未完成条数（>99 显示 99）；左键开关面板，右键出菜单。

## 目录结构

```
dsh-todo-tray/
├─ src/            todo-tray.ps1（主程序）  todo-lib.ps1（公共库）  todo-cli.ps1（CLI）  todo.cmd
├─ scripts/        start-todo-tray.cmd / .vbs（无黑框启动）  selftest.cmd
├─ docs/           使用说明.docx  程序结构说明.docx  怎么验_怎么卸.md
├─ screenshots/    v0.3.40/ 当前版本截图；根目录几张是早期版本留档
├─ README.md  CHANGELOG.md  LICENSE  .gitignore
```

## 从源码跑（自检 / 调试）

```powershell
# 无界面自检：临时目录里跑 266 项断言，不碰真实待办；ExitCode 0 = 全过
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\todo-tray.ps1 -SelfTest

# 指定数据目录启动（调试用，数据只写你给的目录）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\todo-tray.ps1 -ConfigPath C:\temp\todo\config.json

# 把界面渲染成 PNG（不弹窗、不抢焦点）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\todo-tray.ps1 -DumpUi .\out
```

启动开关：`-ConfigPath`（配置文件）、`-SelfTest`（自检）、`-DumpUi` / `-DumpIcons`（截图）、
`-ShowPanelOnStart`（启动即显示面板）、`-ExitAfter N`（N 秒后自动退出）、`-HangSeconds N`（故意卡死验证看门狗）、
`-DisableXlsxForTest`（模拟无 Excel，验证 CSV 回落）、`-NoLog`（不写日志；注意自检里有断言依赖日志，**自检别加**）。

## 命令行（todo.cmd）

```bat
todo.cmd init [--workspace <目录>]                          :: 在该目录下建 .todo\todos.json 并登记
todo.cmd add "标题" [--due "11-20 09:00"] [--tags a,b] [--link "C:\docs\x.md"] [--scope <id>]
todo.cmd list [--all] [--scope <id>] [--json]
todo.cmd done <id>   /   todo.cmd rm <id>
todo.cmd export [--md]   /   todo.cmd where
```

不给 `--scope` 时，从当前目录往上找 `.todo\todos.json`；找不到就用全局清单。

## 配置（`config.json`）

位置：`%USERPROFILE%\.dsh\deepseek-todo\config.json`（首启自动生成；设置窗改的即时生效，手改的需重启）。

| 字段 | 类型 | 说明 |
|---|---|---|
| `version` | int | 配置版本，当前 `1` |
| `autostart` | bool | 开机自启；真正生效的是「启动」文件夹里的 `dsh-todo-tray.cmd` |
| `notify.aheadMinutes` | int | 提前几分钟弹提醒，默认 `0` |
| `notify.missedOnStartup` | bool | 错过（关机）的提醒，启动时补一次，默认 `true` |
| `notify.enabled` | bool | 到期提醒总开关，默认 `true` |
| `ui.mode` | `always` / `auto` | 常驻悬浮 / 失焦自动隐藏 |
| `ui.hideSeconds` | int | auto 模式下失焦几秒收起（5/15/30/60） |
| `ui.opacity` | int | 钉住面板的透明度 30~100（不钉住恒 100） |
| `ui.topmost` | bool | 置顶 |
| `ui.hoverMs` | int | 悬停多少毫秒进入可交互，200~5000，默认 3000 |
| `ui.window.*` | — | 窗口几何：`x`/`y`/`w`/`h`、`edge`、`collapsed`、`whaleSide`、`whaleY`、`autoCollapseSeconds` |
| `lists[]` | array | 清单：`id` / `name` / `todos`（文件路径，支持 `%USERPROFILE%`，相对路径按 config.json 所在目录解析） |

## 数据与隐私

- 全部数据在本机 `%USERPROFILE%\.dsh\deepseek-todo\`：`config.json`、`todos.json`、`state.json`（提醒记录）、`logs\`
- **不联网、不上传、无遥测**；仓库里不含任何真实待办、日志、账号或本机路径
- 备份 = 复制这个文件夹；换机器 = 拷过去即可

## 卸载

1. 托盘右键 → **退出待办托盘**（或小鲸鱼右键 → 退出）
2. 删掉程序文件夹
3. 需要清数据就删 `%USERPROFILE%\.dsh\deepseek-todo\`（想留就先备份）
4. 若开过机自启：删「启动」文件夹里的 `dsh-todo-tray.cmd`（在设置里取消勾选会自动删）

## 已知限制

- **Win11 托盘溢出**：新图标默认收进 `^`，程序不写注册表所以无法强制移出 → 启动时有一次气泡提示。
- **多屏 / 高 DPI / 任务栏在侧边**：未专门适配（100% 单屏已验证）。
- **导出 xlsx** 依赖本机 Excel 或 WPS；没有时自动回落 CSV。
- **托盘数字 >99** 显示 `99`（悬停提示是准确数）。
- 面板按主屏工作区定位，换分辨率后可能需要重新摆一次位置。

## 与开发版的差别（开源整理时改了什么）

1. **路径适配仓库布局**：`scripts\start-todo-tray.vbs` → `..\src\todo-tray.ps1`；`scripts\selftest.cmd` → `..\src\todo-tray.ps1`；主程序设置自启时先找同目录的 vbs，再找 `..\scripts\`（开发目录是扁平的，两种都能跑）。
2. **README 重写**：原 88 KB 的版本流水全部留在 `CHANGELOG.md`。
3. **不带出去的东西**：原目录里的 `_evidence\`（含机器名/用户名的测试证据）、`data_seed\`、任何真实 `config.json` / `todos.json` / 日志，一个都没进仓库。
4. 其余源码与 v0.3.40 一致：**自检 266/266**。

## 许可

MIT License，见 [LICENSE](LICENSE)。

作者：**cute fish**（GitHub：[@Qing-with-cutefish](https://github.com/Qing-with-cutefish)）。
