# Tasks

M22运维准入/M23当前交付。root规划与独立签收，开发实现/必要自测，test_lead正式测试/收尾，进度代理维护原页。不迁移、不向当前玩家补偿、不重建原六服/health/正式APK。

## 1. 最小工具与前置

- [x] 1.1 开发代理修operations路由/角色拒绝顺序，交诊断/补偿双模式按需工具、独立DPAPI/store与单角色策略、稳定operations/1077-operator-r1配置/维护草案及必要源副本；提交差异/源码SHA/必要自测、错误/未知提交及精确清理路径，root审实现与边界。开发不启动Docker/HTTP/当前准入，不初始化正式operator凭据，仅可用非凭据哨兵做必要独立临时自测。见[实现根审](verification/root-development-review.md)，QA五卷已退修、原稳定锁7d517e…fb231已保留；[ACL修订根审](verification/root-native-acl-review.md)签最新7a21锁，正式结果另签。
- [x] 1.2 test_lead独立审源/凭据路径与无迁移夹具、只读实际Docker/镜像/六服/health/DB卷及CLI配置，提交隔离新库与当前只读准入的最小选集、实际输入锁/预算和保护清理方案；root审后分别放行，不能凭旧日志称当前部署通过。见[前置根签](verification/root-preflight-review.md)，最终锁d50ec9…237a0，补实际库存/原收据证据；仅授权2.1 QA运行门。

## 2. 正式验证与当前准入

首轮2.1因凭据初始化工具失败而停止，业务场景未运行；[root失败审查](verification/root-qa-a1-review.md)接受收尾、退回凭据实现。1.1/1.2原签仅对应历史输入，新修订须重审，原运行门不能重试。

- [x] 2.1 test_lead按放行用同固定镜像/实际c88/新ops源及独立新DB/新号/新incident验证真实HTTP权限、RO拒绝无写、5并发同键唯一、异key重复/参数冲突、仓满/部分实际入账、脱敏/凭据失效前置与全部清理；记录原账、源/镜像/配置、真实断言/失败及耗时，root独立签收后才准当前环境操作，不运行旧恢复夹具或M22全套。见[root a3业务签收](verification/root-qa-a3-review.md)，a1/a2首错保留，真实凭据证据复用a2；当前2.2尚未放行。
- [x] 2.2 test_lead按单独运行门初始化当前专用新凭据/store与稳定准入配置，对当前环境分别执行viewer RO与compensator RW的**GET-only**操作和实际身份/权限/来源证明；不得发POST或改当前玩家数据。记录可操作工具与隔离写能力的依赖对应，按实际ID/项目清所有operator容器/客户端，保凭据密文/策略/证据及原六服/health/共享，root审后签收，不宣称常驻operator在线。见[root当前准入签收](verification/root-current-review.md)，实际2GET/0POST、2临时容器删除、40Job空；稳定交接待2.3。
- [x] 2.3 root独立审原始源码/权限/账目/来源/失败与资源终态，签双模式实际可操作及剩余限制；开发/测试更新交付入口、当前准入台账/OPERATIONS/测试索引，进度代理同步原总览/阶段/看板。M06/HU/E/L与整款未完保持，root不重复跑测试矩阵。见[最终签收](verification/root-final-review.md)与稳定接管，原页已同步；归档后补永久链接。

## Workflow follow-up

- 五项签收后严格验证并按skip_specs归档，修文档链接；稳定配置与工具不得依赖已归档活动目录。原JSON/代码/输入锁/失败保留。
- 按需operator无常驻保留，验收所有路径清理容器/客户端；默认保测试卷、密文/策略和证据，不能全局prune或删除原数据。
