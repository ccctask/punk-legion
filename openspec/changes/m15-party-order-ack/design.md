# Design

## Context

root于2026-11-17签收本系统评审供限定实现。必读docs/architecture-review.md、docs/module-boundaries.md及[M04只读输入](../m04-unit-movement-clearance/verification/auto-replan-pump1082-a2-readonly-input.md)。a2 seq4→终局5、near成立但无Collect与源码窗口吻合，缺收包判定原件，保持因果限制；先证具体网络合同，再正式整场验证，不重复未知业务写。

## Goals / Non-Goals

让已持久接受的move/route命令号有独立可靠确认。保留过时位置帧拒绝、原full、存档/未知/失败门和测试等待规则。不重写客户端状态合并，不声称解决所有语义快照更新问题，不改移动/关卡/4米目标条件/规模/经济/采证/P95/时限。

## Decisions — 本轮实现落位与生命周期

| 职责与所有者 | 本轮落位及理由 |
|---|---|
| M15 Party入口鉴权和成员命令 | `game/net/party.gd::_order`已校验当前sender→room→owner，调用真实PartyMission.party_order；确认应属于此权威路径，不归M04模拟或M06测试helper |
| 个人序号/行为原子规则 | 原PartyMission持有commander_sequence及模拟提交，文件与规则不改；false拒绝不发布成功 |
| 持久提交及未知冻结 | 原_save_before_publish为唯一成功前置，false/未知走原pending_checkpoint，不发ACK；不把内存接受等同持久成功 |
| 可靠确认传输 | 成功保存后，仅move/route新增一次继承的 `_ack.rpc_id(from,id,number,m.last_notice)`；复用Solo已存在RPC，不新协议/字段/Autoload/manager。原_full及其他发布分支保持 |
| 客户端时序/反馈 | 现Solo._ack按active/同id推进seq并按尝试号清反馈，无elapsed依赖；现_accept仍拒过时位置，客户端不改，场次退出/新连接既有状态释放不增字段 |

调用链是客户端command→Party._order→PartyMission→保存成功→ACK+原full→既有客户端消费者；传输不拥有目标/账本，测试helper不得伪造ACK或删等待门。创建、身份配置、连接/活动、保存未知暂停、结果、断线/销毁均沿原Owner，新增ACK没有持久状态或独立生命周期。

备选：在共享Solo._accept中合并过时全帧的语义字段会波及单人/组队/营地/Factory及kinematics边界，本轮未证必要，不采用。只删helper ACK门或重发未知Route会掩盖进度丢失，不采用。

## 独立验证与交付

开发只交单文件前后像/diff及保存门后调用/RPC声明未变静核；正式测试归test_lead。先复用现网络/OwnedJob测试入口，提出最小真实ENet选集：新delta先推进时钟、旧full随后由实际消费者拒绝时，真实已提交move/route ACK仍推进seq且位置不退；保存false/未知、no_space/旧尝试/跨场不误确认。不为此造代理网络平台或镜像业务规则；测试工具具体落位另审后才编写/运行。

优先服务器独立修订，保已签APK1082不无效重打。官方[RPC文档](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#remote-procedure-calls)的签名合同支持评估复用，但本项目仍须实测：没有新增/变更RPC声明、返回或NodePath，实际当前客户端与新服务器真实通信通过后才认兼容。新服务器冻结/镜像41及完整Android组合另门；只有相同tick/Sim依赖的原20Hz断言可逐项复用，不拿旧服务器验证新增ACK。

## Risks / Trade-offs

- 额外小ACK不替代full元数据；保原full及当前snapshot语义，整场验证实际目标推进。
- a2唯一因未证，控制重现先证窗口，整场失败需按新原件再评审，不提前承诺胜利。
- 新服与现有APK是两份源身份；M23清楚登记客户端源与后端修订，实际RPC/正常新数据验证后绑定，不称同一manifest。

## Scope and acceptance control

只批准原auto_replan_dev修改party.gd上述成功发布点，新增状态/协议、跨模块写入或扩大范围须回root。无SDK/容器/引擎/设备运行许可；dev自检不代独立验收。当前采用新数据/新卷/新场，不导旧库，不读旧格式适配或重投旧战报。任务/原件/主签分别记录，旧a2超时与清理原件保留。
