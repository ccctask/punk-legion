# Design

## Context

见[proposal](proposal.md)、[只读合同输入](../../../../build/architecture-review/a01-solo-readonly.md)与审计A01。实际Solo顺序为mission.order→忽略_save结果→ACK/full；tick/join/peer_left/周期恢复同样需要发布边界。_save先写progress或result，再写checkpoint；_load当前仅把终局outcome/finished_at叠加到旧Mission，不能将其作为完整终局事实。profile.expire可先于新result可见按progress提交，Armory签名冲突后现每秒重投不会收敛。

评审源SHA：solo.gd `66d2303b6f1f93c2c5466191003c20c5a4cbeffff65d11917ba7724715122368`；solo_mission `677aab9ba553615948107387826458fec99efd0c100d429647322cf256469a33`；armory_mission `3046a72f0df43abdc89d90f3eb09433008c0edbe88313432ac50a742a682e49f`；party `b21ff887d0118a542c3b1c2db6f9462e8473ecd500f206db9d9cd2793e2788d5`；camp `37a4269761283e1dc3b1277c032a653356b848e91194575e7ea9999dc1d0cfd1`；expedition.py `226931d4ce85666930723f1971b71ac530bfa56f1abc5b91312d41b6871c4ad6`。当前工作树不自动代表1077实测。

## Goals / Non-Goals

**Goals:** 所有Solo发布入口遵守同一提交合同，失败可恢复，终局事实和已提交收据各有权威；明确派生影响。

**Non-Goals:** 不承诺未确认命令跨进程exactly-once或每帧落盘，不加WAL/新存档格式；不改变shared _save/_load/_send_delta、party/camp行为、客户端RPC接收、服务鉴权/费用/奖励/冲突校验；不扩无人orphan读回执权限、不导出部署或迁移。

## Decisions

### 状态、依赖与局部组合

主责M14；Solo服务端持Mission、当前peer归属、私有保存屏障/终局停车/异步代次与已认证RAM凭据；Mission持战斗规则和seq；文件持checkpoint与不可变terminal；profile持账务和canonical receipt。方向为Solo编排→Mission/原文件机制/原受信open与settle，profile不读取客户端假回执。无需新Manager/Repository/全局状态或场景重做。普通客户端与party/camp的继承是有限历史例外，维护方M14/M15/M19，约束不变更共享方法语义、不新增同名派生成员，触及共享路径时复审。

### 保存屏障

用Solo专用状态/辅助入口，不与party.pending_checkpoint冲突。非终局完整_save成功才允许命令ACK或full。失败保同RAM实例与seq，暂停该任务新order/step/ACK/full/delta，按原约1秒重试，不逐帧刷错；成功以可靠full通知当前授权peer，不再执行原order。join仍可授权接管但不发布脏Mission；peer_left失败保屏障，不丢回旧offline文件。到期不延长，恢复时先走到期终局。保原周期动态帧语义，不把尚未到保存周期的正常移动等同保存失败。临时保存失败不用会将active变displaced的_issue；服务端限频诊断，无新增HUD协议。

### 终局优先与冲突停车

任何有效.result.json优先走原_terminal/_deliver_disk，不要求旧checkpoint先写成功。启动/重连/周期不得发布_load叠加得到的混合Mission，也不得重算覆盖既有payload。_save机制顺序保持，新增Solo编排绕开此错误调用方式。

RAM已经形成终局但result尚未写成功时，同样冻结原终局再重试；过期只转换仍非终局的dirty Mission，不能把此前win/retreat改expired。文件存在与内容可用分别判断：存在result但打不开、坏JSON或坏shape时安全停车，不能当不存在而回退旧_load/重建活动。使用Solo私有安全读取，不改shared _terminal行为。

settle返回真实result_conflict后停车保文件，不每秒重投、不放宽服务签名。仍连接且已认证者可用其当前RAM secret调用既有open核canonical receipt；该请求可能触发服务到期维护，不能称完全无副作用。凭据只在open授权成功且同peer/请求代次有效后缓存，任务/peer/epoch关联，接管/断线/认证失效/完成/节点退出清理；绝不落盘、写日志或证据。核对一次in-flight，失败保终局，提示既有重连路径并释放控制映射，不无限轮询。

只有校验mission匹配的权威receipt才能_award并统一清本机outbox/session/重试/凭据。open返回deployment不能重启有终局的任务。无凭据冷orphan停车等下一合法_join；该join直接取得原receipt即可收尾。停车仅RAM，重启可再试原payload一次，不保证跨重启永久禁止重投。原payload被接受与读到先提交的到期receipt必须分开记录。

### 异步边界与实施范围

join/settle/核对open均核任务本地代次与当前peer归属；迟到deployment不复活终局，旧回调不清新in-flight/凭据。有效原receipt可完成该任务收尾，但发奖仍需当前授权peer。拟唯一生产文件solo.gd，任何必须改_service共享语义、客户端协议、服务或其它玩法的发现先交root复审。

peer鉴权请求身份与mission交付身份分开：断线或peer ID复用使原鉴权失效，不能仅比较数字peer；已获得的有效mission receipt不因另一peer接管自动作废，发奖则核当前归属。终局退役检查实际unlink结果；删除失败或遗留tmp需保可追溯状态和有界收尾，不能声称磁盘已清、下一次启动也不能因残留旧save复活任务。测试单列本轮新文件的读失败/坏shape、tmp与删除失败，不删除其它环境文件。

终局模式不一定再持有Mission，peer_left和player tick须安全处理只剩outbox的映射；无人在线的保存屏障仍继续有界保存重试。Solo安全读不等于profile.expire对坏spool自动容错，服务现有读文件限制继续登记，不将本项签成服务损坏容错。派生解析和原持久化调用合同须实际验证，不能仅以源SHA未变替代。

本设计经[主代理架构签收](verification/architecture-review.md)及[独立选集预审](verification/test-plan.md)限定通过，完成1.1；**A05执行未终止、root未释放源冻结及正式派单前不得开始实现**。开发自测和正式运行各有具体源/资源门，不凭本设计启动测试。

### 验证与资源

开发代理必要自测，test_lead正式验证，root独立审查。新目录/新任务/新库/合法当前机体；代表性open/rename文件障碍、布尔失败注入分别说明物理写故障与调用合同证据，不填盘或改全局ACL。覆盖order/tick/join/peer_left屏障、同seq恢复一次、过期、terminal部分提交和重启、Armory真实receipt冲突、晚到授权、唯一费用/损伤/占用释放；最小真实ENet流程与party/camp继承检查按实际选集，不能模拟信号代实际网络。无Android/部署必要，具体进程/端口/硬时限由test_lead交锁后root准入。仅补受影响断言，不机械全套旧回归。

总签覆盖核对：3.1/3.2的新Node证据保原限定范围，不能单独证明规格中的same-version restart；在tasks 3.4显式补两真实进程的同轮终局部分提交恢复。生产范围、规格及玩法不变，3.3工具与执行不因补证而扩大；3.4独立工具/准入后只运行缺少的断言。

## Risks / Trade-offs

- 暂存故障期间客户端停在最后已发布画面 → 保可恢复原连接及服务器限频诊断；若需要新玩家反馈协议，另行复审而非偷偷改_issue。
- 原terminal和profile到期结果竞争 → 保已提交receipt，晚结果停车核对，不伪称原payload接受或跨进程竞态消除。
- 父类改动影响M15/M19 → 私有命名和路径隔离、冻结共享实现，最小派生回归。
- 冷orphan没有secret → 等合法重连，保文件/有限重试，不扩权限或持久化秘密。
