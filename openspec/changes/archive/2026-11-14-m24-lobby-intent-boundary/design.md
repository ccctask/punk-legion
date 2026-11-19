# Design

## Context

见proposal/A05。G0治理已签并归档，遵循[评审模板](../../../../docs/architecture-review.md)。当前treasure._request在GET忙时保存body引用，_response即使失败仍发queued_post；Back只emit、生命周期到_exit_tree才清理；初始Start可用。服务返回roster只有id/name/points，成员只有name/mine/robots/names/points/confirmed，不能设计不存在的owner ID、装备quote或指纹校验。

## Goals / Non-Goals

**Goals:** 明确页面意图与请求生命周期的局部组合边界，保持成功且未变上下文的一次点击体验，阻止失败读取/过期/关闭导致未授权的新写。

**Non-Goals:** 不改服务API/schema/事务、M03装配、M08账本、战斗、奖励或预算；不统一全项目HTTP、迁移或导出APK。客户端不能解决同点数装备更换或GET→POST竞态，保服务proposal/confirm最终裁定。

## Decisions

### 状态所有者与组合

M24页面拥有有效视图标记、pending_intent（最多一个）、closing、请求序号/实例及页面代次。新增本目录小型RefCounted纯策略组件`lobby_intent.gd`，由页面preload并实例化；提供capture与revalidate，必要的有效视图/按钮可用性用同一规则入口，不复制第二套判定。策略只处理传入的视图和当前选择/好友输入，生成深拷贝的原body及相关上下文；不访问Node/HTTP/token/数据库/Autoload/战斗。页面协调HTTP机制、控件、反馈和原入场流程。该提取有当前五种具体意图分支和独立失败合同，不是为未来造管理器。

既有`/root/Treasure`传输和战斗视图作为登记的局部历史依赖保留，本项不扩大其写权限或替换所有Autoload。A03全域到期事务和A04多模拟均非本修复前置；测试只核相关队伍/机体/回执，不要求整库静止。

### 意图复核矩阵

以下条件除有效视图/页面未关闭外，还须满足当前可见操作准入；body始终保点击时的深拷贝与原机器人顺序。集合比较可规范化，不能改变发出的顺序。

| 操作 | 精确body | 刷新后的相关条件 |
|---|---|---|
| create | event, friend | 同event.id且active、played=false、无group/admission；好友trim输入不变；无关roster变化不丢创建 |
| select | group, revision, robots | 同forming双人group/revision；成员身份(name/mine)一致；当前手选集合不变，所选IDs仍在本人roster且各points不变、符合个人容量 |
| confirm solo | group, risk=true, robots | 同forming单人group且本人未确认；手选IDs/可见points不变且合法，无admission；不添加revision |
| confirm duo | group, risk=true, revision | 同forming双人group/revision、成员身份和各自已提交robots/points不变、双方有名单；本人手选与本人已提交集合一致且本人未确认；队友confirmed推进允许 |
| cancel | group | 同group、本人仍为成员、forming或queued、无admission；不因无关机器人改选取消该意图，不虚构revision |

本人confirmed是当前本人状态，不是全员确认。成员names/显示名等无关显示变化不作为整份overview深相等条件；成员name在当前契约中是可见身份依据，不能声称其替代服务身份认证。新roster看不到同点数装配指纹，仍由服务拒绝loadout_changed等。

### 请求和失效时序

按钮点击先检查view_valid与closing，再capture，避免lambda先访问空overview。已有有效视图且GET在途时允许捕获一个意图，提示正在核对名单；有pending或POST在途时阻止额外写点击，不隐式覆盖为另一操作。控件可用性和点击守卫均需保护。

当前GET成功且结构可用→更新/呈现新视图→取走pending（先清再处理）→revalidate→send至多一次、discard要求重确认或observed显示当前事实。失败GET/超时/同步启动失败/坏结构→view_valid=false、清pending、禁写并反馈；后续成功轮询不复活旧意图。admission→先清pending再走原_join。相关context变化不从新视图重建另一body。

HTTP请求保留本页7秒配置；每次请求身份与页面代次绑定回调，可参考friends.gd退役实例机制，不能让取消/同步错误后旧回调操作新busy/overview。结构验证只覆盖页面实际读取及意图判定所需字段/类型，容许合法空roster、null group/last与匹配admission，不引入通用schema框架。同步错误也走单一失效/退役路径，不重复请求。

不可信响应使用`JSON.new().parse`显式检查Error，坏JSON沿同一失效路径处理，不依赖会输出原生ERROR的静态`JSON.parse_string`。该选择经[Godot4.6.1源码](https://github.com/godotengine/godot/blob/4.6.1-stable/core/io/json.cpp#L587)核对，只调整本页解码机制，不新增公共网络层。

Back先设置closing、失效代次、清pending并退役HTTP，再closed.emit；_exit_tree重复清理应安全。保原音效与已连接战场清理，不把大厅改造扩大为战斗协议修改。已发POST可能仍在服务提交，本地取消仅阻止后续客户端副作用。未知POST恢复只GET读取当前group/member/revision/confirmed/phase/admission/last；群组消失或出现不单独证明原create/cancel回执，不自动重发POST。

### 玩家反馈依据

[FFXIV官方Ready Check](https://na.finalfantasyxiv.com/game_manual/pp/)展示由成员明确回应并呈现当前准备状态的做法。本项只借鉴“确认是当时明确意图、当前事实单独展示”，该资料没有证明其内部断网/HTTP策略；本项目失效/未知写方案依据自身权威契约与移动端短局目标定案。错误提示用“刷新失败，本次待处理操作未发送”“队伍或阵容已变化，请核对后重新确认”等玩家可理解反馈，不显示GET/epoch等实现信息，也不宣称已在途写被撤销。

## 架构评审与实施边界

主责M24；M05权威校验、M15队伍语义仅关联。允许game/treasure/treasure.gd、treasure.tscn的必要大厅初始控件、局部lobby_intent.gd及针对性测试/文档。传输/模拟/服务/部署/其他页面只读。若需要额外生产文件、协议字段、全局抽象或不同的四操作行为，先回root复审。

实现前由root在verification/architecture-review.md签收本合同及源锁；开发代理实现/必要自测，test_lead独立真实输入/HTTP及新库最小集成，root仅审证据和实际范围。A01提交合同另行处理，不与本项共改父类。

## Risks / Trade-offs

- 过度比较整视图 → 按上述操作相关字段，正向验证队友确认推进/取消无关改选。
- 纯helper通过但页面仍发幽灵写 → 正式选集使用真实tscn/SubViewport/InputEvent与真实可控HTTP，断言实际POST和生命周期，不直接触发_response或pressed代替输入。
- 服务全域推进导致假失败 → 新库仅核本操作group/robots.task/receipt费用，保留其他到期合同。
- 减少安卓复测误称手机全过 → 本项验证UI/HTTP合同，既有原生/战斗证据按依赖复用；新源码不自动进入1077，整合发布另有平台门。
