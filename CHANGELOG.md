# dsh-todo-tray · 版本变更记录

> 从 `todo-tray.ps1` 文件头迁移出来（2026-11-10 0.3.34 整理）；按版本倒序，最新在最上面。

> 程序内部只在文件头保留「最近几版」，完整历史看这一页。

---

dsh-todo-tray · v2.0 / 0.3.40
==========================================================

0.3.40（2026-11-11 · 修：点导出提示框后收起箭头消失）：
  用户 19:05 报：点导出 → 等导出完成，右下角弹黑色提示框 → 点它 → 主界面侧边收起箭头不见了，
  面板也不再 3 秒自动收回。
  根因：Toast 的点击处理是 `Hide-Toast; Show-Panel`。面板**已经显示着**时，Show-Panel 不带 -FromWhale，
  把 `$script:FromWhale` 清成 false → `Update-CollapseChrome` 收掉箭头改出 ×；
  同时 `PeekExpanded / WhaleDeadline` 被清 → 3 秒自动收回也没了。两条症状同一个根。
  修：①点击提示框改走 `Open-PanelFromToast`——面板已显示就只补一次置顶 + `Update-CollapseChrome` +
  `Restart-PeekCountdown`，不重排不重显；面板收在小鲸鱼就 `Set-Collapsed $false -FromWhale` 展开；
  面板真隐藏了才 `Show-Panel -FromWhale:(Edge -ne 'none')`。
  ②`Show-Panel` 兜底：面板已经显示着、调用又没带 -FromWhale 时，沿用当前 `$script:FromWhale`，
  任何「重显」都不许把侧边模式重置。
  自检 263 → **265**（点提示框：箭头还在 + 3 秒倒计时不丢；重显不带 -FromWhale 不重置模式），
  265/265 通过（新断言直接触发 Toast 的 Click 事件，走的就是用户点它那条 handler）。
  日志新增 `[TOAST] 点提示框：…`，以后一眼看出走了哪条分支。

dsh-todo-tray · v2.0 / 0.3.39
==========================================================

0.3.39（2026-11-11 · 小鲸鱼多摇两下）：
  用户 16:38：「再多摇两下，我看过去的时候她都摇完了」。
  改：两摆 700ms → **四摆 1400ms**（sin 8πT，两端仍 sinπT 包络收住），幅度 ±4.5 → ±5px；
  另加**鼠标移到鲸鱼上也会摇**（MouseEnter）——用户看过去的那一刻刚好能看到。
  自检仍 263（摆尾断言改成四摆的采样点：T=0.0625 右 / T=0.1875 左）。
  实测：盯鲸鱼 90 秒逐帧比对，尾巴区 82 次像素变化（0.3.38 是 35 次），拼图 `_tmp\wag_seq3.png`。

dsh-todo-tray · v2.0 / 0.3.38
==========================================================

0.3.38（2026-11-11 · 小鲸鱼会摆尾巴了）：
  用户 2026-11-11 14:34 看到 DSH 那条会摆尾的小鲸鱼，说「真可爱」，让我给托盘的小鲸鱼也做一个。
  做：`Get-WhaleTailOffset`（T=0..1，两摆 sin4πT，两端用 sinπT 包络收住 → 起止自然归 0）+
  `Start-WhaleWag`（40ms 一拍、700ms 摆完两下，只重画 24×72 的小鲸鱼，CPU 可以忽略）。
  尾巴三角随 `$script:WhaleWagOffset` 横向摆 ±4.5px（根部只跟 30%，看起来像绕尾根摇），
  摆起来时尾尖略微抬起。触发点：从侧边收起出现时、每冒一个气泡时。
  自检 260 → **263**（右摆 / 左摆 / 起止归零三条）。

dsh-todo-tray · v2.0 / 0.3.37
==========================================================

0.3.37（2026-11-11 · 小鲸鱼置顶守护 + 冒泡边框更显眼）：
  用户 2026-11-11：「小鲸鱼图标现在好像不是悬在最上层了」+「冒泡的边框要改得更显眼一些」。
  ①置顶：查了运行时 z 序——小鲸鱼确实带着 WS_EX_TOPMOST，但排在置顶层最底下（任务栏、小火箭、
    后出现的全屏程序都在它上面）。根因：`Show-Whale` 只在「隐藏→显示」那一次补 HWND_TOPMOST，
    已经显示着就不再抬。修：每次 Show 都补；另加 `TopmostTimer`（3 秒一拍，SWP_NOSIZE|NOMOVE|
    NOACTIVATE）把可见的小鲸鱼、显示中的冒泡、**钉住**的面板抬回置顶层（未钉住的面板是临时展开，不抢别人）。
  ②冒泡边框：1px 浅灰蓝（201,216,238）几乎看不见 → **2px + 按星级上色**：普通蓝（96,140,205）、
    2★ 橙（235,150,0）、3★ 红（209,52,56）；2px 描边路径内缩 1px，避免被窗体 Region 裁掉。
  自检 257 → **260**（鲸鱼重复 Show 仍置顶、冒泡边框三色）。

dsh-todo-tray · v2.0 / 0.3.36
==========================================================

0.3.36（2026-11-10 · 开机自启进默认）：
  用户 2026-11-10 17:34：「默认开机自启」。0.3.35 交付时 autostart 仍默认关，用户要求反过来。
  改：①`New-DefaultConfig` 的 `autostart` 默认 true（便携模式仍 false，便携不写启动项）；
  ②新增 `Ensure-AutostartFromConfig`（M16）：启动时若 config 里 `autostart=true` 而「启动」文件夹里
    没有 `dsh-todo-tray.cmd`（首次运行 / 被删），就补建一个；`autostart=false` 时不主动删（取消勾选才删）。
  ③设置窗勾选框文案「默认关」→「默认开」。
  **已有 config.json 一个字不动**；用户本机启动项本来就在（2026-10-29 建），行为不变。
  自检：255 → 257（+「默认设置 autostart=true」「便携默认不开机自启」两条）。
  交付：试用包重打 `dsh-todo-tray-0.3.36-试用包_20261110.zip`。

dsh-todo-tray · v2.0 / 0.3.35
==========================================================

0.3.35（2026-11-10 · 默认设置按用户现用配置）：
  用户 2026-11-10 16:04：把「我现在用的设置」定为适合的默认设置（新装的人 / 领导试用直接用这套）。
  只改「新建 config」的默认值（todo-lib.ps1 → New-DefaultConfig），**已有 config.json 一律不动**：
    mode=always（常驻悬浮）、hideSeconds=5、opacity=35、topmost=true、
    hoverMs=3000（悬停 3 秒进交互）、bubble={enabled:true, maxSeconds:15}。
  autostart 仍默认关（开机自启由用户自己在设置里勾，不替用户做主）。
  自检：新增 5 条默认值断言（250 → 255），已有配置的行为不变。
  交付：试用包重新打包 `dsh-todo-tray-0.3.35-试用包_20261110.zip`。

0.3.34（2026-11-10 · 代码整理，行为不变）：
  150 个函数按 19 个模块重排，每个模块 `#region` 标出；文件头换成「模块地图 + 函数清单 + 常见改动入口」；
  260 行版本变更史外移到本文件；删掉函数之间的重复分组横幅。
  函数体逐字节未改（AST 逐函数比对 150 个，0 差异）。自检 250/250、
  `-ExitAfter 6` 冒烟 ExitCode 0、zip 解包后再自检 250/250。

dsh-todo-tray · v2.0 / 0.3.33
==========================================================
待办托盘程序（PowerShell 5.1 + WinForms，零依赖、不联网、不写注册表）

0.3.33（2026-11-10 · 修「全屏程序把冒泡压住」）：
  用户 2026-11-10 12:15：DeepSeek Harness 开全屏时只能看到侧边小鲸鱼，看不到冒泡。
  根因：小鲸鱼/面板/收起箭头每次 Show 之后都显式补一次 SetWindowPos(HWND_TOPMOST)，
    冒泡窗没有这一步（只靠 Form.TopMost 属性）；全屏窗口是置顶时，冒泡就排在它下面。
  修：Show-Bubble 显示后补一次 `$h.TopMost = $true` + SetWindowPos(HWND_TOPMOST,
    SWP_NOSIZE|SWP_NOMOVE|SWP_NOACTIVATE)，和小鲸鱼同一套口径（不抢焦点、仍可穿透）。
  自检加一条：冒泡窗带 WS_EX_TOPMOST。

0.3.32（2026-11-10 · 恢复 3 秒自动收回 + 修侧向收起箭头消失 + 焦点框覆盖全）：
  用户 2026-11-10 11:58 更正：上次说的「关设置后面板不见了」记错了——面板没丢，
    是侧边那个「向里收起」的箭头不见了；而且主面板展开后 3 秒自动收回也不该被取消。
  根因（箭头）：Show-Settings 保存后走 mode=always → 调 Show-Panel（没带 -FromWhale），
    FromWhale 被置 false → Update-CollapseChrome 收掉箭头、改出 ×；0.3.31 的
    「非 FromWhale 清 peek」顺带把 3 秒倒计时也清了 → 面板从此不自动收回。
  修：①Show-Settings 重新显示面板时带上原来的 -FromWhale（-NoAnim，不重播滑入）；
    ②Enter-ChildWindow 仍暂停倒计时；Exit-ChildWindow 关窗后按 FromWhale + Edge 重新排 3 秒；
    ③小窗关掉后补一次 Update-CollapseChrome，箭头跟着回来。
  焦点框：0.3.30 的 Register-ButtonFocusFix 挂得太早（第 2727 行，编辑/新增/导出/刷新/设置
    都在它之后才建）→ 挪到 Initialize-Ui 末尾统一挂一次；Clear-FocusCue 改成清「按钮所属窗体」
    的焦点（弹窗里的按钮也适用）。
  自检：小窗关窗后 3 秒重新排程 + 箭头仍在 + 刷新按钮点完焦点为空的断言。

0.3.31（2026-11-10 · 修「关掉设置小窗后侧边栏（面板）消失」）：
  现象（用户 2026-11-10）：点设置 → 关闭设置 → 面板不见了。
  根因：从小鲸鱼展开时 set PeekExpanded=true + 3 秒自动收回截止；紧接着打开设置小窗时
    Enter-ChildWindow 只停了 WhaleTimer，没清 PeekExpanded/WhaleDeadline；关掉设置后
    Exit-ChildWindow 调 Restart-PeekCountdown 又把 3 秒倒计时点着 → 到点自动收成鲸鱼。
  修：①Enter-ChildWindow 清掉 PeekExpanded / WhaleDeadline（小窗期间不排自动收回）；
    ②Show-Panel 非 -FromWhale（托盘/设置回显等）也清掉 peek 状态，普通窗口不再带自动收回。
  自检加一条：Enter-ChildWindow 后 PeekExpanded 必须为 false、截止为空。

0.3.30（2026-11-10 · 修侧边面板仍透明 + 按钮焦点黑框）：
  ① 用户实测：不钉住时侧边面板还是透明的。根因：Start-AutoHide 里先调 Stop-AutoHide，
     Stop-AutoHide 又把 Opacity 设回 ui.opacity（30%）—— 它在 Show-Panel 设完 100% 之后跑，
     把值覆盖了。修：Stop-AutoHide 也用 Get-PanelOpacityValue（未钉住恒 1.0）。
  ② 按钮点完留黑框：加 Clear-FocusCue（Form.ActiveControl = $null）并 Register-ButtonFocusFix
     递归给面板/行里的按钮挂 Click 清理；行是动态建的，Add-RowSpec 里补挂。

0.3.29（2026-11-10 · 透明度只属于钉住模式；侧边展开的面板恒 100%）：
  需求（用户 2026-11-10）：透明度只在钉住状态用；不钉住（侧边栏弹出）一律 100%。
  落地：新增 Get-PanelOpacityValue：未钉住返回 1.0，钉住返回 ui.opacity/100（夹 0.3~1）；
    Show-Panel / Apply-UiSettings / Set-Interactive 回穿透时的透明度都改用它。
  自检加一条：未钉住展开的面板必须 100% 不透明。

0.3.28（2026-11-10 · 悬停倒计时期间完全不表现，到点才出边框且直接不透明）：
  需求（用户 2026-11-10）：鼠标移上去不要有任何变化，直到倒计时结束才显示边框，并且透明度直接变成 100%。
  落地：Update-PointerState 进入面板时只记时间、不再点亮提示边框；到 hoverMs 才 Set-Interactive true
    （这一步出实线边框）+ Form.Opacity = 1.0 + Sync-PanelLayeredAlpha；离开回穿透时把透明度恢复成配置值。
    自检对应断言改成「刚进入无变化」「到点边框 + 不透明」。

0.3.27（2026-11-10 · 悬停进交互改成可调，默认 1.5 秒）：
  需求（用户 2026-11-10）：悬停时间加到 1.5 秒试试，或者临时给个输入框方便自己调。
  落地：ui.hoverMs（毫秒，默认 1500，夹 200~5000）；Update-PointerState 用这个值判「悬停多久进交互」；
    设置窗「数据」区加一个「悬停进交互 [1500] 毫秒」输入框，点关闭即保存并立即生效。
  自带自检的悬停断言同步改成 1.4 秒不进 / 1.5 秒进。

0.3.26（2026-11-10 · 图钉：侧边面板不再穿透，钉住才开穿透 + 可拖动）：
  需求（用户 2026-11-10）：①收成侧边栏后展开的面板不要再走"悬停 0.6 秒才能点"那套穿透逻辑；
    ②加图钉：钉住后不再收回侧边栏，这时才开穿透逻辑、面板拖动也恢复；
    拖动不许出屏，碰到边就顶住，两边都顶死就完全不动。
  落地：①未钉住时 Show-Panel 强制 Set-Interactive $true 并停掉悬停/离开定时器；Update-PointerState
    与 Invoke-PanelDeactivate 在未钉住时不再退穿透（auto 模式失焦仍按原逻辑收起）。
  ②图钉按钮 $script:BtnPin（GDI 画的图钉，蓝=钉住/灰=未钉）；Toggle-Pin：钉住→FromWhale=false、Edge=none、
    出 ×、收箭头、Set-Interactive false 开穿透、可拖动；取消→ Set-Collapsed 收回小鲸鱼。Pinned 存 ui.pinned。
  ③拖动恢复（只在钉住时起手），Update-PanelDrag 用 Get-ClampedWindowPos 把窗口夹在工作区内：
    碰到哪条边就顶住；窗口比工作区还大时两条边都顶死 = 不动；钉住状态下不再触发"拖到边收成鲸鱼"。

0.3.25（2026-11-10 · 卷帘放慢 + 每行淡入）：
  需求（用户 2026-11-10）：弹出速度没问题了，但事项划入太快，想要点优雅的感觉。
  落地：RollTimer 从 10ms/4 行 改成 18ms/1 行（75 条约 1.35 秒，像卷帘慢慢落下来）；
    每行加入时先比 BaseColor 浅一档，再用 8 拍（约 144ms）渐变到原色，出现时有淡入感。
    淡入与卷帘共用 RollTimer 的拍子；Stop-RowRoll 会把没淡完的行直接落到目标色。

0.3.24（2026-11-10 · 展开只弹空白面板，事项卷帘式从上到下一个一个显出来）：
  需求（用户 2026-11-10）：弹出只弹空白主界面，然后事项像卷帘一样从上到下"咻咻咻"一个个显出来。
  落地：①Build-Rows 拆成 Get-RowSpecs（算出该有哪些行）+ Add-RowSpec（造一行控件的工厂）；
  ②Start-RowRoll / Step-RowRoll / Stop-RowRoll：清空 Flow 后按 10ms 一拍、每拍 4 行把事项依次加上，
    75 条约 200ms 铺完，看起来就是从上往下卷出来；
  ③展开动画打开时：先清空列表（空白面板）+ 滑入，OpenFillTimer 到点后 Load-State→Update-Status→Start-RowRoll；
    收起/隐藏时停掉卷帘定时器，避免关掉还在补行。

0.3.23（2026-11-10 · 点开后立刻滑入，列表内容稍后填）：
  需求（用户 2026-11-10）：动画时长没问题，是"点完到开始滑"的间隔久，要缩短。
  落地：展开时不再同步 Refresh-All（量 75 条要建几十个控件，几百 ms，全压在这段间隔里），
    先显示面板 + 藏鲸鱼 + 立即开滑；Refresh-All 交给 OpenFillTimer（180ms 一次性）在
    滑入之后做。面板里保留上一次的行，填新内容时再换，所以滑入时不是白板。
    另外在动画起点写一条 [PANEL] 展开耗时日志，方便以后量。

0.3.22（2026-11-10 · 展开动画零延迟：先把面板备好，再藏鲸鱼开滑）：
  需求（用户 2026-11-10）：点小鲸鱼弹出有点慢——鲸鱼先消失、面板过一会儿才出来；
    希望单击后鲸鱼瞬间消失、直接开始弹出动画。
  落地：动画打开时不再在开头就 Hide 鲸鱼，而是让面板先在屏外把内容建好（Refresh-All/Build-Rows），
    等一切就绪、Start-SlideAnim 的那一刻才 Hide 鲸鱼——用户看到"鲸鱼一消失，面板同时滑出来"。
    非动画路径（托盘打开、自检 AnimOff）行为不变。

0.3.21（2026-11-10 · 换边 / 展开 / 收回 三个滑动动画）：
  需求（用户 2026-11-10）：①拖小鲸鱼时鼠标越过屏幕中线，鲸鱼要"嗖一下"跑到对应侧的边；
    ②打开主界面、收回主界面也要有弹出/缩回动画。
  落地：①Update-WhaleSideFromX：按鼠标 X 与工作区中线判断左右；换边时用 Start-SlideAnim
    把鲸鱼 X 从当前位置滑到目标边（130ms，ease-out）。拖拽中 Y 仍直接跟手。
  ②Start-SlideAnim：一个 12ms 的 SlideTimer 做 ease-out 位移；Show-Panel -FromWhale 打开时从屏外
    滑入（160ms），Set-Collapsed 收回时先滑出屏外（140ms）再真正 Hide（-NoAnim 递归收尾）。
    自检/无动画环境用 $script:AnimOff 直接落位。

0.3.20（2026-11-10 · 小鲸鱼可拖动定位 + 主窗口不可拖 + 收回保持鲸鱼原位）：
  需求（用户 2026-11-10）：①主窗口的拖动取消，只能拖小鲸鱼：按住拖=定位、松手固定、单击=打开主界面；
    ②小鲸鱼拖到底就留在底部，主界面收起后小鲸鱼要回原来的位置，不能按窗口中心重算。
  落地：①新增 Start-WhaleDrag / Update-WhaleDrag / End-WhaleDrag：按下记起点和当前 Top，
    Move 按鼠标位移上下挪并夹在工作区内，Up 时位移 <3px 当单击（打开主界面），否则落盘 WhaleY。
    小鲸鱼 MouseDown/Move/Up 接上，右键菜单仍在 MouseUp 右键。
  ②Set-Collapsed 收起时不再重算 WhaleY（0.3.19 的按窗口中心定位撤掉），只按 Edge 更新 WhaleSide。
  ③面板标题条/标题不再挂 Add-PanelDragHandlers，光标也从 SizeAll 改回默认（拖动只剩右下角缩放）。

0.3.19（2026-11-10 · 侧边条拖动从原位起手 + 收回按窗口中心重定位）：
  需求（用户 2026-11-10）：①拖到边上收成侧边条时，位置要"在原地开始上下移"，
    不要被拽到鼠标点上；侧边条最高顶到工作区顶、最低底到工作区底，鼠标可以更靠上/更下。
  ②侧边条跟手挪过之后位置是固定的，但主窗口再收回来时要按窗口中心重新定位，不能老停在原位。
  落地：①Enter-BarPhase 记 BarBaseTop = 面板中心 - 条高/2（夹在工作区内）、BarBaseMouseY = 当前鼠标 Y；
    bar 态每拍 newTop = BarBaseTop + (鼠标Y - BarBaseMouseY)，再夹到 [WorkArea.Top, Bottom-BarH]。
  ②Set-Collapsed 收起时不再判 Edge 是不是 none，一律按 Form 中心重算 WhaleY（Set-WhalePosition 会夹）。

0.3.18（2026-11-10 · 小鲸鱼展开纵向对齐 + 拖动收起箭头跟着消失）：
  需求（用户 2026-11-10）：①点小鲸鱼弹出的主界面要跟小鲸鱼中心对齐，鲸鱼靠上/靠下时改成贴
    工作区顶部/底部（任务栏之上）；②移动主界面收回到小鲸鱼后，收起箭头会留在原地不动。
  落地：①Show-Panel -FromWhale：横向贴屏边的同时，纵向 y = 鲸鱼中心 - 面板高/2，
    再夹到 [WorkArea.Top, WorkArea.Bottom - H]。
  ②Enter-BarPhase（拖到屏幕边直接收成侧边栏）以前只 Hide 面板，没管箭头 → 补 Hide-CollapseTab
    并把 FromWhale 清掉；Exit-BarPhase 拖出来时 Update-CollapseChrome 恢复 ×；End-PanelDrag 的
    bar 分支再兜一次 Hide-CollapseTab。

0.3.17（2026-11-10 · 冒泡只在收成小鲸鱼时冒）：
  需求（用户 2026-11-10）：点小鲸鱼打开主界面后冒泡就暂停；只有小鲸鱼（收起）状态才冒泡，
    只剩主界面不冒。
  落地：Test-BubbleContext 改为「小鲸鱼可见 且 主界面不可见」才算能冒；
    Show-Panel 打开面板时立刻 Hide-Bubble；Set-Collapsed 收回小鲸鱼时 Restart-BubbleSchedule
    （回到鲸鱼状态后按 15~N 秒重新起算）。
  自检改：小鲸鱼在 → 能冒；主界面开着 → 不冒；两个都关 → 不冒；另外气泡 UI 检查期间用
    $script:SelfTestForceBubble 临时放行（那些断言直接调 Show-Bubble，不经过 Tick）。

0.3.16（2026-11-10 · 收起箭头朝里、贴面板内侧边）：
  需求（用户 2026-11-10）：箭头方向反了——「在右侧边栏，箭头要在界面左侧，朝右；
    在左侧边栏，箭头要在界面右侧，朝左」。
  落地：Position-CollapseTab 按面板在屏幕的哪半边判断边栏侧：
    右半边 → 箭头贴面板左沿外面、画 ▶（朝面板/屏幕右边，也就是收起方向）；
    左半边 → 箭头贴面板右沿外面、画 ◀（朝面板/屏幕左边）。
    整块仍在面板外；屏幕那侧没空间时退回贴面板内侧相应边沿。

0.3.15（2026-11-10 · 箭头固定左侧且全部露出 + 小鲸鱼展开贴屏边）：
  需求（用户 2026-11-10）：①收起按钮放左边；②箭头有 2/3 被主窗口压住，要露出来；
    ③点小鲸鱼打开时，窗口右侧要贴着屏幕侧边。
  落地：①Position-CollapseTab 固定 side=left，箭头画成 ◀；x = 面板左边再往外让出整个宽度 → 完全在面板外，
    不再被面板压住；面板贴屏幕左边没地方时退回贴在面板内侧左沿（仍可见）。
  ②Show-Panel -FromWhale：按 WinCfg.WhaleSide 把面板横向贴到那条屏边（右侧 = WorkArea.Right - W；
    左侧 = WorkArea.Left），并把 Edge 记成该侧、X 落盘，下次打开仍贴边。
  自检改：箭头必须在面板左侧外沿、面板必须贴屏边。

0.3.14（2026-11-10 · 侧边展开的收起箭头 + 小鲸鱼右键菜单）：
  需求（用户 2026-11-10）：①点小鲸鱼展开后，主界面不该再用「×」把整窗连小鲸鱼一起关掉，
    应改成贴在面板侧边的横向三角箭头，点了收回侧边栏；②小鲸鱼要右键菜单，里面有「关闭」；
    ③顺带修：面板和小鲸鱼都关掉后冒泡还在冒（现在全隐藏就不冒了）。
  落地：①Show-Panel/Set-Collapsed 带 -FromWhale 标志：从小鲸鱼或侧边栏展开 → 隐藏 ×、
    在面板右/左边缘竖直居中显示 18×64 收起箭头（独立小窗，向屏内一侧凸出 8px，点击收回侧边栏）；
    托盘直接打开的面板仍是 ×。箭头随面板移动/缩放跟位。
  ②小鲸鱼右键菜单：显示待办 / 新增待办… / 新建清单… / 清单管理… / 设置… / 关闭小鲸鱼 / 退出待办托盘。
  ③冒泡 Tick 增加「面板和小鲸鱼都不在 → 不冒」。

0.3.13（2026-11-10 · 清单管理：改名 + 移除）：
  需求（用户 2026-11-10）：0.3.12 只能新建，补上「删除清单 / 改名」。
  落地：①清单下拉再加一项「⚙ 清单管理…」（托盘右键也加「清单管理…」）→ 一个窗：
    列出所有清单（名称）+ 选中项的数据文件路径 + 名称输入框 → 「改名」/「移除」/「关闭」。
  ②改名：config.lists[].name 改掉，同时把该清单 todos.json 里的 name 也改掉（scope/id 不动）；
    重名 / 空名拒绝；改完下拉重画、当前选择按序号保持。
  ③移除：先弹系统确认框（写明「只从托盘移除、数据文件保留 + 路径」）→ 只从 config.lists 去掉一条，
    **不删数据文件**；至少保留一个清单；移除的正好是当前选中清单则回到「全部清单」，
    它不是当前选择则当前选择序号往前挪一位。移除后冒泡重排。

0.3.12（2026-11-09 · 多清单：能新建 + 冒泡跟随选中清单）：
  需求（用户 2026-11-09）：①清单功能要能新建（现在没有入口）；②冒泡别只从全部清单里挑，
    要跟主界面选中的清单走——选「全部清单」就所有清单轮流，选中某个清单就只轮这个清单的。
  落地：①清单下拉最后加一项「＋ 新建清单…」，托盘右键也加「新建清单…」：
    选一个文件夹 → 在该文件夹下建 .todo\todos.json（和「工作」清单同构）→ 登记进
    config.lists（id = 'list' + 路径哈希）→ 自动切到新清单并刷新；重名 / 同一文件夹已在清单里 /
    目录下已有 .todo\todos.json 都拒绝，红字说原因，不写任何文件。
    只建数据文件，不碰 AGENTS.md；要 agent 协作仍用 todo.cmd init。
  ②Get-BubbleEntry 按 $script:FilterListIndex 过滤；切换清单时 Restart-BubbleSchedule 重排轮播，
    旧气泡立刻收起。

0.3.11（2026-11-09 · 小鲸鱼冒泡）：
  需求：小鲸鱼时不时冒泡，依次显示 3★（红）→ 2★（黄）→ 普通；没有红黄就轮到普通；
        每个冒泡 6 秒（$script:BubbleSeconds，后续可改）；设置里能关、能调「最长间隔」（上限 60 秒）；
        气泡不透明、不可选中、鼠标完全没反应。
  实现：BubbleTimer 250ms 看表 → 随机 15~N 秒冒一个（N = 设置值，≤60）；
        气泡 260×88 圆角白卡（左侧红/黄/灰色条 + 标题 + 角标），
        EXSTYLE = LAYERED|TRANSPARENT|NOACTIVATE|TOOLWINDOW，alpha 固定 255（不透明）；
        位置贴着鲸鱼（面板展开时贴面板）竖直居中，越界自动夹回工作区。
        打开小窗 / 关闭冒泡开关 → 立刻收起。

0.3.10（2026-11-09 · 新增弹窗输入框几秒后失焦）：
  用户：点「新增」后几秒内窗口刷新一下，输入焦点/输入法图标没了，得再点一次。
  根因：弹窗开着时面板的悬停逻辑（100ms）还在跑；光标在弹窗上、几何上又落回面板范围内，
        0.6 秒后 Set-Interactive → Apply-PanelExStyle → SetWindowPos(SWP_FRAMECHANGED)，
        把焦点从弹窗输入框抢回面板。
  修：ChildOpen>0 时 Update-PointerState / Set-Interactive 直接返回（不动 EXSTYLE、不激活面板）；
      打开小窗时连悬停/离开定时器一起停，关掉再恢复。

0.3.9（2026-11-09 · 删除确认改系统弹窗 + 15 秒撤销）：
  ① 删除确认框改成系统 MessageBox。日志坐实了旧问题：点了自绘窗的「删除」但 Tag 没置位，
     于是「未确认，取消」。自绘窗叠在 TopMost 面板上点不到按钮，换系统框一劳永逸；
     确认结果写日志（[DELETE] 确认框结果 Yes/No）。
  ② 删除后 15 秒内可撤销：列表里留一行「已删除：xxx」（下划线 + 灰字）+「撤销」按钮；
     撤销按删除前原文写回；15 秒到点或关面板，撤销行消失（数据本来就是真删）。

0.3.8（2026-11-09 · 鼠标在面板里不倒计时）：
  用户：点具体行、编辑的时候，3 秒自动收回还在走 → 改成鼠标只要在面板范围内就不计时。
  落地：Test-PointerInPanel() 读光标判在不在面板；WhaleTimer 每拍发现鼠标在里面就把
        截止时间推到 now+N（不计时），离开时从零重新起算；Start-AutoHide 同样受这条约束，
        只有离开面板的那一刻才开始自动隐藏倒计时。小窗口（ChildOpen）逻辑不变。
  自检新增 4 条：在里面不启动倒计时 / 到点不收回 / 离开开始隐藏倒计时 / 离开自动收回重新计时。

0.3.7（2026-11-09 · 删除必达 + 小窗口期间不收起）：
  ① 小窗口（新增/编辑/删除确认/设置/导出菜单）打开期间：大面板保持显示，
     自动隐藏、小鲸鱼「展开后 N 秒自动收回」全部暂停；关窗后从零重新计时。
     用户原话：二次确认/新增小窗的时候，大窗口要保持显示，直到小窗关掉才开始计时。
  ② 删除链路每一步落日志（[DELETE] 点删除 / 未确认 / 执行结果 / 异常）。
     以前执行阶段抛异常会被 WinForms 事件处理器吞掉（表现就是"确认完没删"），
     现在会写 ERROR，下次再出直接看日志定位。
  ③ 自检补两条真路径：编辑态点行内真 🗑（Tag→确认框→真删）、
     「小窗开着到点也不收 + 关窗后重新计时」。

0.3.6（2026-11-09 · 拖拽改「以鼠标为准」）：
  旧：拖到边 ±10px 也不收，松手 400ms 后才吸附+收起；而且收起时窗口被 Hide，
      Capture 丢失，MouseMove 不再来 —— 「按住拖成侧边栏」根本做不到。
  新：拖动/缩放统一由 20ms 定时器读 GetCursorPos + 左键状态驱动（标题条/抓手只负责起手）：
      ① 窗口边碰到左右边（≤10px）→ 立刻收成 24×72 侧边栏，纵向位置 = 鼠标 Y（居中）；
      ② 按住不放上下拖 → 侧边栏跟着鼠标走；把窗口拖离边 >60px → 恢复成窗口；
      ③ 松手 → 侧边栏就地固定（edge/whaleY/collapsed 落盘），不再有"松手吸附"。
  删掉：Get-SnapPosition / Invoke-WindowSettled / WindowSaveTimer / GeometryLive /
      DragCtl / MouseMove+MouseUp 拖拽分支 —— 收边已经实时，这些都没有调用点了。

0.3.5（T20261029-06 · M4-3 勾完 5 秒不消失）：
  DoneFadeTimer 第一拍（1s）expired=0 就 Stop()，而 DoneFadeAt 是「现在+5s」，
  之后没人再 Start → 勾完的项永远不消失（0.2.3b 起就有）。
  修：无到期只 return，不定 Stop；停表只留 DoneFadeAt 为空这一条。
  自检加真等待断言：勾掉 ≤6s 消失、data 仍 done、导出仍含、连勾两项各自计时、关开不复活。

0.3.4（T20261029-02 · 鲸鱼两条 B）：
  B-① 鲸鱼窗只 -bor 了 WS_EX_LAYERED、从没 SetLayeredWindowAttributes，
      屏上根本不画（GetLayeredWindowAttributes ok=False alpha=0）。
      抽 Set-WinAlpha($hwnd,$opacity)（alpha 下限 1），Initialize-Whale 末尾
      与 Show-Whale 各补一次。
  B-② collapsed=true 重启后点鲸鱼零反应：Show-Whale 负责置 PanelCollapsed=true，
      否则 Set-Collapsed $false 第一句就 early-return。
  自检改为对鲸鱼句柄读 GetLayeredWindowAttributes + 因果（alpha 打 0 → Show-Whale 补回），
  不再用标志位。

0.3.1（热修 D1/D2/P6）：
  D1 拖动：0.3.0 只在 Form 上挂 WM_NCHITTEST，但面板有 60 个 child HWND，
     真鼠标命中先落子窗口 → 钩子根本没被调用（只有 1px 边框能拖）。
     改为「标题条/标题文字 MouseDown + 手动跟踪 + Capture」，同一套函数
     既走真鼠标、也能被自检用真 WM_LBUTTONDOWN 消息驱动。
  D2 缩放：右下角加 18×18 抓手（自绘斜线），MouseDown/Move/Up 自己算尺寸，
     最小 320×240（不依赖无边框窗的 SC_SIZE）。
  P6-auto：auto 模式由托盘/鲸鱼**显式进入交互态时**抢一次焦点（0.2.3b 原行为），
     失焦即收起；always 只回穿透不收起；悬停进交互不抢焦点（P3 不变）。

0.3.0（M5-M8）新增（交互模型大版本）：
  M5 双态：穿透态（默认，鼠标点穿）↔ 交互态（可点/可拖，1px 边框）；
     进交互 = 托盘左键 或 悬停 0.6 秒；移开 1.5 秒/失焦回穿透。
  M6 拖动/缩放/吸附/持久化：WM_NCHITTEST 返回 HTCAPTION / HTBOTTOMRIGHT；
     config.ui.window = {x,y,w,h,edge,collapsed,whaleSide,...}，最小 320×240。
  M7 侧边小鲸鱼：拖到左右边缘吸附收成 24px 独立小窗；点击展开；3 秒自动收回。
  M8 抵抗 Win+D：拦 WM_WINDOWPOSCHANGING 的 SWP_HIDEWINDOW；WS_EX_TOOLWINDOW 不进 Alt+Tab。

0.2.0（M1）新增：
  R1 启动不留可误关的窗口 —— 启动方式改为 start-todo-tray.vbs（wscript 宿主，
     零控制台窗口）；本文件不再改变进程宿主，只做程序本体。
  R3 设置项 —— config.json 的 ui 段：mode(auto|always) / hideSeconds /
     opacity / topmost，面板底部「设置」与托盘右键「设置…」进入。
  R4 × 行为不变（只收界面，托盘还在）。

v1 范围：
  1. 托盘图标用 GDI 画「未完成条数」+ 悬停提示
  2. 左键 → 工作区右上角浮出面板，列出 todos.json 的未完成项
  3. 勾选 → 写回 JSON（原子替换），托盘数字即时更新
  4. 失焦 / Esc 自动收起
  5. 数据路径全部来自 config.json，代码里不写死任何清单名

用法：
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File todo-tray.ps1
  powershell.exe ... -File todo-tray.ps1 -ConfigPath "D:\x\data\config.json"
  powershell.exe ... -File todo-tray.ps1 -SelfTest      # 无界面自检，ExitCode 0 = 通过

注意：本文件必须存成 UTF-8 带 BOM（Windows PowerShell 5.1 否则按 GBK 读，中文乱码/语法错）。
