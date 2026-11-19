# Godot快速回归试点

探索场景组合G3已获[限定根签](../../openspec/changes/archive/2026-11-14-m14-expedition-scene-composition/verification/root-review.md)，实际入口及历史命令见[专用README](../../openspec/changes/archive/2026-11-14-m14-expedition-scene-composition/verification/testing/README.md)。a3连续六组通过，a1/a2失败保留；这是场景/本机HTTP切片，不是ENet、Android或当前试玩整合。旧门/目录已用，未来另run、锁与批准。

当前动作生产者的J1/J2/J3/R1/W1最小工具见[action_contract](action_contract/README.md)；a3 GD+a4 Python组合已获[限定根签](../../openspec/changes/archive/2026-11-14-m04-current-action-contract/verification/root-review.md)，原失败保留、旧门全关闭，未来另run/锁/门。构造资格与正式行为分门，正式需要test_lead新锁和主代理另行批准；该入口不运行下方旧整组、HTTP或迁移夹具。

状态：GUT 9.6.1隔离试点已执行，主代理采纳签收另见[运行报告](../../docs/testing/runs/2026-11-12-gut-pilot.md)。原试点对象为当时工作树11个生产文件闭包；新增alerts准备当前闭包为13文件，不是签名1076 APK执行。

## 目录与可比装配合同

[目录合同工具](catalog_contract/README.md)使用新最小stage实际加载生产Catalog/Rules，并严格对照服务端JSON与四个已解析装配/编队样例。该入口复用Windows OwnedJob、固定4.6.1和源锁机制，无GUT插件、import或旧用户数据；不执行本页下面的旧大组入口。

正式运行由test_lead绑定当前生产集合、实际工具/解释器/引擎与11交付保护的新锁，再取得主代理唯一门；每个run必须新目录。本轮真实导出/四样例与工具控制已获[限定根签](../../openspec/changes/archive/2026-11-14-m03-catalog-contract-check/verification/root-review.md)，原门已关闭、原目录已用，后续需新锁新门；失败拒绝、范围与命令模板详见工具README。

## 输入与运行

在仓库根目录使用本机Python和已固定的Godot 4.6.1。每个新候选使用新的run-id，旧工作区、label及失败记录不能覆盖。

这是当前Windows本机的有界试点入口，不是新clone开箱即用的通用测试安装器。运行前须具备：

- 本机固定Godot 4.6.1 console引擎，SHA须为 `bd9e27c6994a128aaab45cdda4d372de87b91900618ba2de55c6aa29248d5b56`；资源归属使用Windows Job和PowerShell。`--engine`可显式指定文件，省略时仍使用旧默认 `C:/Users/alienware/AppData/Local/PunkLegion/tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe`；当前本机须使用下例LocalCache路径，不会自动扫描或下载引擎。
- 既有保护产物 `build/private-beta/snapshots/rc-1076/`（515源文件及source-manifest.json）与 `build/private-beta/PunkLegion-beta-1076.apk`。它们仅用于本轮前后未改动保护，不会被执行或重签；新clone缺少这些忽略产物时须先准备对应前置条件，不能把此入口当成脱离候选产物的公共CI命令。
- 已固定的 `tests/godot/vendor/gut-9.6.1.zip`、锁和许可证，以及本机Python。去除候选产物耦合属于后续明确需求，本轮不泛化。

日常按变更选最小组只执行一次；只有新失败、相关代码变化或明确比较需求才补跑，不默认重复成功用例。下例仅选rules；需要其他组时按变更影响修改选集，冷暖连跑仅用于明确的比较需求。

```powershell
$runId = 'gut-check-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$gutEngine = 'C:/Users/alienware/AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Local/PunkLegion/tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'
python -B tests/godot/run.py prepare --run-id $runId --engine $gutEngine
python -B tests/godot/run.py run --run-id $runId --label rules --groups rules --engine $gutEngine
```

`prepare`核源/包保护、复制必要生产依赖和固定GUT到 `build/qa/<run-id>/project`，导入小型测试工程，记录编辑器及子进程并清理。`run`只执行所选组；可用 `--groups rules` 或 `--groups scene,async` 选最小影响集。改变生产或测试源码后，旧工作区会拒绝漂移，重新准备候选；不要直接覆盖stage文件求通过。

两步都须传入同一个实际引擎路径。缺失文件或错误SHA在创建工作区/启动进程前非零拒绝；run还核对manifest里的绝对路径与SHA，不允许悄悄换到另一位置的同版引擎。路径变化时准备新的run-id，不改旧manifest或导入旧运行数据。下面控验命令同样须带 `--engine $gutEngine`。

| 组 | 持久测试 | 实际覆盖 |
|---|---|---|
| rules | [test_rules.gd](test_rules.gd) | 实际Loadout归属/接口/额度及PartyMission显式集合时间、跨owner与重投拒绝 |
| scene | [test_scene.gd](test_scene.gd) | 实际lobby.tscn，SubViewport内根据节点矩形分发鼠标InputEvent，读保护、草案和请求信号 |
| async | [test_async.gd](test_async.gd) | 实际apply_preview.tscn，经临时loopback HTTP500/200及真实在途关闭；不直接调用完成回调 |

新增独立 `--groups alerts`（normal）执行[test_alerts.gd](test_alerts.gd)：真实defense_alerts.tscn按钮鼠标输入、同步切屏、同ID重建和锁定/后台guard；仅此组选集不启HTTP夹具。修前一次3例30断言通过但未重现原生ERROR，见[修前报告](../../openspec/changes/archive/2026-11-13-m23-defense-alert-input-lifecycle/verification/test-baseline-report.md)。这不是Android修复结论；默认原三组选集不含alerts。

每次引擎进程预算默认60秒；`prepare`导入预算90秒，单独计时。运行器使用Windows Job拥有console launcher、实际Godot子进程及可能的导入子进程；只结束这个Job，不按进程名批量清理。HTTP夹具使用同一Python进程内的非daemon线程和端口0，已实测正常、断言失败、空集、pending、HTTP在途超时的关闭/join及监听释放。本试点的控验运行也启动该夹具，以验证错误/空集路径的资源收尾；另有未start、start抛错及线程已退出三个清理分支的独立证明，见运行报告。

## 失败门槛验证

以下是有意拒绝的工具验证，不能称为产品通过。每个命令使用不同label，`passed`保留false，只有严格检查满足时 `control_satisfied` 才为true。

```powershell
python -B tests/godot/run.py run --run-id $runId --label negative-rules --groups rules --mode negative --engine $gutEngine
python -B tests/godot/run.py run --run-id $runId --label negative-scene --groups scene --mode negative --engine $gutEngine
python -B tests/godot/run.py run --run-id $runId --label negative-async --groups async --mode negative --engine $gutEngine
python -B tests/godot/run.py run --run-id $runId --label empty --groups rules --mode empty --engine $gutEngine
python -B tests/godot/run.py run --run-id $runId --label skip --groups rules --mode skip --engine $gutEngine
python -B tests/godot/run.py run --run-id $runId --label timeout --groups async --mode timeout --timeout 2 --engine $gutEngine
```

负对照改变目标测试的预期值，要求实际JUnit目标断言失败、引擎非零且无脚本/引擎错误。空集和pending即使引擎退出0也被wrapper拒绝；超时须实际进入HTTP请求后由Job截止结束并清理，不拿普通断言失败冒充超时。Python入口通过返回0、拒绝返回3；PowerShell工具层可能把非零规范化为shell退出1，原始Godot退出码在报告中独立保存。

HTTP夹具构造未start、start抛错、线程已退出三个清理分支可单独检查，无需启动Godot：

```powershell
$fixtureOut = 'build/qa/fixture-start-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
python -B tests/godot/check_fixture_start_failure.py --out $fixtureOut
```

输出必须解析到本仓库 `build/qa/` 内全新子目录，不能覆盖旧目录或写回任何OpenSpec历史变更。该入口仅验证三个HTTP清理分支，不重复框架用例。

## 输出与版本边界

`build/qa/<run-id>/manifest.json`记录实际生产闭包、stage文件哈希、GUT锁及独立user目录。各label包含 `report.json`、`junit.xml`、`engine/godot.log`、`engine/process.json`、HTTP事件和 `cleanup.json`。stage实际测试哈希与当前runner哈希分开，既有记录不因本地文件后来更新而变成新版本通过。

固定包、来源、提交和下载SHA见[vendor/gut.lock.json](vendor/gut.lock.json)，许可证见[vendor/GUT-LICENSE.md](vendor/GUT-LICENSE.md)。插件不放在game目录，不改正式export。`runtime_endpoints.cfg`是Endpoints已检查文件存在性的可选配置，本隔离非private_beta工程登记为缺失；其他缺失依赖仍拒绝。

这些测试不覆盖真实ENet、数据库费用/个人结算、Android原生HOME/输入或设备帧率。正式包SHA保持不变只证明未修改它，不证明已执行或验收1076。其他测试选择与复用规则见[测试索引](../../docs/testing/README.md)。


## 工坊固定触摸传播诊断（候选入口，未执行）

依据[M23系统评审](../../openspec/changes/m23-architecture-release-integration/verification/root-workshop-scroll-diagnostic-development-review.md)，现scroll_pointer_probe.gd新增固定`--mode workshop-diagnostic`。需要test_lead新source lock/新fixture receipt及root运行门；不得重用原M00已消费command/工作目录。

沿原隔离stage/`process_owner.owned_run`运行`--script res://tests/scroll_pointer_probe.gd -- --fixture <本轮新绝对JSON> --out <本轮新目录> --mode workshop-diagnostic`。这是已有入口的一个固定分支，无新runner/资源Owner；mechanism/production两旧模式及原fixture形状/检查、三代表和disabled门不变。诊断仍要求原960×540、touchscreen及触摸转Mouse资格、20秒内部共同界，外层仍原86秒/OwnedJob收尾；不启HTTP/SDK/import/editor/容器。

固定真实`owned/workshop.tscn`只拆出`HUD/Panel`子树进入Tree；业务Root不进入/ready，不调用业务handler。各臂新实例、源filter完全不覆盖、滚值只观察。三个事前节点按序为`Scroll/Body/Shop` Button、`Scroll/Body/Mode` OptionButton与`Scroll/Body/Stock` Label；不执行后换点。呈现变更完整清单为Mode按源workshop.gd::_ready的两条add_item添加“设计与制造”“机库与实装”（不显式select），以及Stock.text=`目录版本 <当前Catalog.VERSION> · 全新GUI诊断，无账号数据`，源为本轮实际loadout/catalog.gd VERSION，记录在每臂presentation字段（含Mode item_count/text/selected初值及来源）；没有库存/账号/旧场数据或服务读取，不执行业务_ready/handler、不接业务信号，不切visibility或改布局结构。Mode的两项来自脚本_ready，并非原scene预填。

三臂均从固定节点真实rect中心向上，以同一公式`min(64, 起点距clip顶部余量−4)`像素、300ms调用原_drag；距离须大于原scroll_deadzone、起终点在clip内、源初始滚值0且余量>10，并核无其它STOP控件覆盖起点。资格不符保存现象/首错，不改点、不写scroll、不调filter追绿。原_drag的12段25ms及touch/motion/release实现逐源文本保持，旧模式仍原轨迹。

每臂保存前后PNG（固定前缀workshop-shop/workshop-mode/workshop-stock）、固定rect/clip/deadzone、原始及effective filter链、原action_mode、按下后真实hover路径、Mouse/scroll_started/位移、pressed/toggled/GUI intent、可见popup前后；Mode另记item_count/text及selected前后，并只读记录其原PopupMenu visibility_changed，记录真实路径/可见值/时刻并保留Press打开/Release关闭的瞬时轨迹；常规16条，上限后的首条原事件另存并关闭该观察器、明确失败及后续未观察，不静默丢弃或冒完整；Label的实际hit可为其PASS祖先，因为Label本身IGNORE。自然不滚、GUI意图或popup变化均是观察，不因前臂自然阻断跳过后臂。held输入、Canvas/子树和未入Tree业务Root沿原_clear_arm/_finish清理。

`diagnostic_complete`表示三臂输入/图证完整与无工具失败；`passed`在此模式仅同样属于诊断工具完整性。`product_scroll_passed=null`始终保留，没有将不滚改成产品绿。这三个起点不涵盖LineEdit、正常工坊动态使能/业务HTTP或Android真实手势；Mode结果仅限本次固定下拉节点，不泛化全部OptionButton。

来源基线沿原34c SOURCE及M00 stage源投影，不把该stage冒1080完整71f。测试侧已只读发现原20缓存中的12个scn与1080实际成员不同，不能照搬旧缓存冒同包。正式新stage须按1080已签payload精确物化其实际20成员并保存来源/散列，另经静态stage门；不需要import/SDK。新运行前须核工坊实际依赖与1080源同bytes、有效缓存及本轮probe；新fixture沿现生成器合同创建全新UUID/receipt，未消费字段不冒业务验收。若窄stage/导入资源来源不够，停回root，禁止为诊断启动import/SDK或造新平台。


## 工坊产品GUI正例（候选工具，未执行）

按[M09正例工具AR](../../openspec/changes/m09-workshop-touch-scroll/verification/root-gui-positive-tool-development-review.md)使用新增固定`--mode workshop-production`。只修改原probe/本README，生产workshop.tscn由独立源码门签；测试仍需新fixture/receipt/源锁/准确stage与root单次运行门，禁止原样重放旧M00或M23门。

新模式固定五臂/每臂新子树：Shop、Mode、Stock三drag，Shop fresh短点，Mode fresh短点＋真实Popup键选择。共享原20秒内部界，不增wait/retry或改原_drag时序；三旧模式mechanism/production/workshop-diagnostic不进入新键/正例路径。可通过原脚本CLI固定后缀`--mode workshop-production`选择，不接受任意控件/键配置。

| 臂 | 固定PNG | 必须证明 |
|---|---|---|
| Shop drag | workshop-shop-before/after | 原生PASS/RELEASE、真实Mouse/Scroll事件与滚动位移、零pressed/toggled/request/Popup |
| Mode drag | workshop-mode-before/after | 同原生属性且全过程无Popup visible事件、selected不变 |
| Stock drag | workshop-stock-before/after | 原Label自然滚动对照，无GUI意图 |
| Shop fresh click | workshop-shop-click-before/after | 当前rect/clip原点按下两帧pressed0，放开两帧后同目标pressed一次，不滚/不弹/无请求 |
| Mode fresh click/choice | workshop-mode-click-before/opened/selected | 按下两帧Popup关、pressed0；释放两帧Popup开、pressed1；真实键选择第二项并只一次id_pressed/item_selected，selected0→1、Popup关闭、滚动0 |

共11PNG（后缀均.png）。固定Shop/Mode/Stock源节点、Catalog Stock.text及Mode两项字面显示投影沿原诊断合同；不执行业务Root_ready/Handler、不增加字段/布局/filter/action_mode/选择赋值。新模式仅读取source属性为PASS/RELEASE，不由测试override；原diagnostic默认positive=false，仍只签取证完整、product_scroll_passed=null。

Mode opened记录原position/size/has_focus/get_focused_item/selected及原Window id、主Window id、force_native/embedding标志和时刻。has_focus只记录，不强制OS焦点。鼠标开菜单的自然focused允许-1/0/1：-1只Down一次必须到0，再Down一次必须到1；0只Down一次必须到1；1不Down；其它值拒绝。各键后只核该次准确转移，失败不重发，最后Enter一次；没有set_focused_item/select/activate_item/emit或内部_input调用。

唯一键helper只接受Down/Enter的InputEventKey，一按一放走原Input.parse_input_event，最多2Down＋1Enter（6事件）。按/放均绑定**同一当前get_popup().get_window_id()**；无效ID失败，不猜主0或找替代Window。4.6.1 [Window.get_window_id](https://github.com/godotengine/godot/blob/4.6.1-stable/scene/main/window.cpp#L1646)嵌入时递归返回承载Window id，原生则返回自身id。每对记录window_id/focus/has_focus/时刻，keydown后总先keyup再做断言；即使Enter使Popup隐藏，也保同一按下时ID发keyup。

probe仅新增held_key及其window id两个瞬时清理字段；正常一对后复零/-1，_clear_arm与_finish若发现未释放键，沿原parse_input_event补keyup并明确失败，再释放GUI/Canvas/Root。不会因清理补发变成通过。Popup visibility、原id_pressed和Option item_selected仅本地被动GUI观察，16正常事件上限及首overflow保留/关闭观察/失败合同不变，实例销毁释放连接。

仅五臂全部成立且held touch/key释放才passed/product_scroll_passed=true；首错/部分记录明确失败。该结果仅桌面GUI，真实Popup键选择不是Android触控菜单、业务HTTP、费用或完整经营通过。新stage来源分列原435基线＋53同1080 GUI依赖＋唯一workshop d516候选覆盖＋本probe/project差异＋实际1080已签20缓存，不冒整个stage为1080发布源；无SDK/import/editor/服务/新Owner。
