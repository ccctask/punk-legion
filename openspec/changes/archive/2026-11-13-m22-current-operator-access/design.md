# Design

## Context

见proposal。已读当前operations.py、server.transaction/initialize、inventory和check_operations；GET独立mode=ro，写事务无schema操作，initialize只供新库初始化。旧check_operations自身是新临时库/两新号/真实HTTP，不执行其导入的check_profile.run；后者含恢复/删卷，禁止整套运行。现r2实际profile镜像dc6f…acc8/有效c88 server与原六服、health均保持。

## Goals / Non-Goals

交付当前可操作的诊断与补偿两模式，不仅交viewer；正常使用按需启动/一次请求/精确清理，不添常驻后台。当前实测不改任何玩家数据，补偿所有写入仅在本轮新库证明。不新增公网API、自动补偿/自动重试、通用后台或迁移功能；M06与H/U/E/L不随本项关闭。

## Decisions

1. **最小核心修复。** operations.dispatch鉴权仍最先；GET诊断保持URI mode=ro；非POST/错误路由404、非compensator403在server.transaction之前拒绝。补偿参数/事务/幂等/审计不重写。新sidecar独立绑定已修operations.py及实际c88 server，记录各自SHA；原r2六服镜像/绑定和1077冻结源不动，不能称原六服已换ops代码。
2. **稳定双模式。** 持久目录`build/private-beta/operations/1077-operator-r1/`保存版本化工具/源副本/配置/准入台账/OPERATIONS。诊断viewer-only policy、当前player-profiles整个目录RO；补偿compensator-only policy、该整个目录RW以支持SQLite journal。四spool与代码/策略均RO、根RO、network_mode:none/无主机端口；复用固定profile镜像，不build/pull。显式operations.py --db /data/player.sqlite --policy --port24679覆盖原镜像CMD。init:true转发信号/回收子进程；无restart常驻。一次最多一个自有sidecar，finally按实际ID/标签/配置down并核退出容器0，不碰原六服/health/共享。
3. **凭据不接触玩家系统。** 两独立高熵token，仅SHA策略；专用显式store保存当前Windows用户DPAPI密文和非秘密元数据，拒覆盖、ACL限本用户/SYSTEM，不复用签名vault/生成签名材料。容器不挂DPAPI目录或明文token；只绑定本模式策略，选中token解密后只经内存/stdin传docker exec容器内loopback客户端，禁argv/env/日志。不可解密/格式或身份不符在启动前拒绝；真实跨Windows账户未测不可虚称。开发仅用非凭据测试哨兵必要自测；正式/QA token由test_lead获明确运行门后在各自新store初始化。
4. **真实可用工具。** 提供凭据初始化、diagnose（默认viewer，可显式核compensator只读准入）、compensate命令及确切配置/角色选择。工具在POST前保存无秘密的key/参数指纹，成功以实际receipt.changes/ID为准，不能把requested当实发。未知提交保同key/参数与原因、停止且清理，不自动重发/换key；现GET只有receipt摘要，不虚构自动按key核单能力，管理员需据同号账目核查或明确以原键重试。正常生产.update可能影响总库存，核补偿以单ops_credit收据为准。
5. **分层验收。** test_lead先审实现/实际环境/源锁并交最小选集，root再签运行。隔离新DB/新号/本轮incident、同固定镜像+c88/修后ops做真实HTTP：角色/玩家拒绝、只读模式错误POST/错路由正常403/404且无写、5并发同key一收据、换key重复拒/参数冲突、关键参数与仓满/部分入库/脱敏。可复用现成check_operations，不运行含恢复夹具整套。当前生产准入分别启viewer RO和compensator RW，但**只GET**，并核角色策略、实际完整Mount/Image/源/loopback及日志和原服务保护；不向当前玩家POST。当前真实库未写与隔离同镜像写能力的证明分别记录，不冒称当前玩家已获补偿。
6. **资源/交接。** 初始建议隔离HTTP≤180秒、当前两种准入每次≤120秒及每次60秒收尾；0AVD/引擎/游戏peer/新业务服，唯一同时自有operator实例，无保留常驻operator。test_lead细化后root具体放行，不自动补轮。新凭据密文/策略、配置及证据保留；临时容器/客户端/策略暂存必清，命名测试卷默认保留。root审原始断言/账目/资源终态签收，进度代理更新原页；台账记录按需可操作而非虚构当前在线operator。

## Risks / Trade-offs

首轮QA在凭据生成前停止，随后只读原查询因PowerShell安全模块加载失败。修订采用原生Windows安全描述符查询，继续核owner、受保护DACL和仅当前用户/SYSTEM完整权限，不以本地化的icacls输出代替权限门；故障输出按非秘密阶段定位。原失败与空目录保留，新实现及新QA路径另审后运行，见[root首错审查](verification/root-qa-a1-review.md)。原生查询依据[Microsoft安全描述符操作](https://learn.microsoft.com/en-us/windows/win32/secauthz/security-descriptor-operations)与[DACL控制位](https://learn.microsoft.com/en-us/windows/win32/secauthz/security-descriptor-control)，实际宿主行为仍须正式验证。

- 当前RW配置被误当授权补偿真实玩家 → 当前验收仅GET，POST仅隔离新库；正式补偿必须对应已核事件和明确操作命令，不自动跑示例/发资源。
- 凭据进输出或不可用的DPAPI材料 → source/argv/Env/输出检查；错误前置拒绝，不打印原输入。新store与签名vault隔离，现角色策略单独绑定。
- RO拒绝先开写事务 → 生产顺序修复加真实RO HTTP负例，不能只靠客户端禁止来掩盖。
- 无序Mount/Compose数值表示造成假失败 → 按Destination核完整字段/严格宿主路径表示，数值按语义解析，保原始输出；不弱化权限/来源检查或改旧失败。

## Technical references

[Docker none网络仅保留loopback](https://docs.docker.com/engine/network/drivers/none/)；[Compose init转发信号并回收子进程](https://docs.docker.com/reference/compose-file/services/#init)；[Microsoft DPAPI默认用户作用域及返回内存释放](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata)。本项目部署兼容性与实际收尾仍由本机真实验证，不以文档替代。
