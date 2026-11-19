# M22 内测运维手册（历史能力与示例）

状态：历史M22工具能力说明，2026-11-13已校正适用边界；维护者为档案服务与房间值班开发。当前1077客户端＋1076-delivery-r2后端的日常入口是[当前交付与维护](current-playable-delivery.md)，实际服务配置来自其稳定runtime与OPERATIONS；本页不提供当前部署/在线状态证明。

**以下项目名、卷名、监控、备份/恢复/回退和演练命令均为历史示例，不可复制作为当前默认操作。** 当前root已接管独立`punk-private-beta-1077-health-r1`，准确查询/重启/停止入口见[健康OPERATIONS](../build/private-beta/operations/1077-health-r1/OPERATIONS.md)及[实际runtime](../build/private-beta/operations/1077-health-r1/runtime.json)；它在原r2六业务服务之外，复用外网与四只读结果卷，只写本轮独立history。不要启动旧监控模板或为健康采样重建六服。当前按需诊断与受限补偿见[operator稳定入口](../build/private-beta/operations/1077-operator-r1/OPERATIONS.md)及[准入台账](../build/private-beta/operations/1077-operator-r1/runtime.json)：双角色当前GET和新库补偿已分别签收，无常驻operator，当前玩家POST须另有对应授权。本文保留原示例用于追溯，不授权执行。旧库恢复、跨版本导入、重投旧版本战报及迁移只有用户明确授权本次数据迁移后才可安排，遵循[测试数据与数据迁移规则](../AGENTS.md#测试数据与数据迁移)。

## 历史：本机健康采样与告警

历史方案的监控对象是本机 `punk-private-beta` 内测服；采样器为独立的 `punk-beta-health` 项目，无发布端口，配置为随 Docker 自动重启。游戏的四个结果卷以只读方式挂载，采样器在自己的 `punk-beta-health_history` 卷中保留最近七天的 SQLite 样本和告警事件。实际源码入口为[health.py](../tools/operations/health.py)及[旧health.compose.yaml](../deploy/health.compose.yaml)；后者默认外部卷/网络仍指早期项目，不是当前r2监控配置。当前sampler使用同SHA脚本和单独稳定配置，已由[root签收](../build/private-beta/operations/1077-health-r1/root-acceptance.md)；以下仍为历史命令，不用于当前维护。

```powershell
docker compose -p punk-beta-health -f deploy/health.compose.yaml up -d
docker compose -p punk-beta-health -f deploy/health.compose.yaml exec -T sampler python -B /app/health.py report --limit 20
docker compose -p punk-beta-health -f deploy/health.compose.yaml logs --since 1h sampler
```

每 30 秒读取档案的公开协议接口并记录耗时，然后查看演习、单人探索、组队探索与营地的待投文件数量和最老文件的年龄。HTTP 超时为 3 秒。采样器只读文件名及修改时间。秘宝的权威结果直接写入档案，未纳入四类文件队列。此处只度量档案可达性与投递积压，战场 UDP 的实际连接需另跑内测版端点握手。

连续三次 HTTP 失败、连续三次最老待投结果达到 120 秒，或连续三次无法枚举结果卷时，各告警分别标为 `profile_unreachable`、`result_overdue`、`queues_unreadable`。首次告警和首次恢复各写入一条事件并输出容器日志。查询结果的 `active` 为当前告警，`events[].active` 的 1/0 分别表示发生与恢复，`time` 是 UTC Unix 秒。没有样本或最新样本超过 90 秒时 `stale=true`。存在告警或过期返回退出码 2，正常返回 0；历史库无法打开则返回 1。

采样器停止时，可用 `docker compose -p punk-beta-health -f deploy/health.compose.yaml run --rm --no-deps sampler python -B /app/health.py report --limit 20` 离线查询同一卷，并根据 `stale` 排查其容器。档案异常先检查 profile 日志；积压先用下文场次诊断查对应房间结果与处理状态；读取异常先核对 Compose 项目名和卷挂载。更换受测游戏实例时，设置 `HEALTH_GAME_PROJECT` 并给采样器另取项目名，使不同实例各有独立监控历史。

## 历史：统一恢复点（不属当前日常流程）

以下[snapshot.py](../tools/operations/snapshot.py)示例会停止服务、读取或写入卷；不是玩家账号恢复。不得以版本发布或本页存在为恢复/迁移授权。

在仓库根目录运行，宿主使用 Python 3.11+、Docker Compose，恢复目标使用同一套配置和兼容镜像。记录构建提交、镜像 ID、房间日程、环境与端口映射。备份目录保存玩家档案和恢复凭证，限值班账户访问。另行保管部署配置及运维角色策略。

```powershell
python tools/operations/snapshot.py capture --project punk-legion --bundle D:/private-backups/before-upgrade
docker compose -p punk-restore create
python tools/operations/snapshot.py restore --project punk-restore --bundle D:/private-backups/before-upgrade
docker compose -p punk-restore start profile
docker compose -p punk-restore start room expedition party camp treasure
```

开始前安排维护窗口。复制器先停权威房间再停档案，并检查五卷均无运行中容器使用。它校验 SQLite 完整性，将归属、商店权益、任务锁、房间进度和待投递结果一起冻结为清单及五个 ZIP，同时记录源容器实际镜像与原有启动状态，完成后按原状态重启。源工程和恢复工程同时使用时，为后者设置独立端口。已存在的备份目录和有数据的目标卷都会拒绝覆盖。

历史恢复工具先核对五卷列表、SHA-256、ZIP 完整性及安全路径，再逐卷写入并核对 SQLite 版本与流水数；原流程随后要求玩家重登、共享room-auth及旧场次/库存核对。这段描述仅保留原设计，不是当前验收安排；新验收必须本轮生成数据，禁止自行复制旧库、安排旧场次恢复或迁移调试。

## 历史：升级失败与交易差额

以下rollback与旧快照恢复不属于当前流程；只读reconcile能力也不授权准备旧数据或重投。任何真实问题先保留同次证据，由root明确下一范围。

升级前保留可启动的旧镜像及对应恢复点。回退前再冻结当前所有卷至独立目录，保留两份原件，用已记录的旧版部署文件和旧镜像启动匹配的旧快照。旧二进制会拒绝更高版本的档案。将旧库成功启动、玩家重新登录和数据核对记入值班记录。

```powershell
python tools/operations/snapshot.py reconcile --bundle D:/private-backups/before-upgrade --later D:/private-backups/after-upgrade
```

输出列出后一个恢复点新增的物资流水 ID 与操作类型，另逐笔列出商店订单 ID、事件序号、商品和状态（创建、已付、发货、退款等）。旧行消失、订单不可变字段或历史事件变化、订单状态与事件不符、已装备外观缺失权益都会中止核对。逐条核对真实来源、权益和归属。日程编辑、配置及没有经济流水的操作需按其业务记录单独核查。对账命令只读。能重投的场次从房间凭证重投；有明确物资差额时才用下述补偿。涉及权益、营地主或其他不可用小额物资表达的差异交模块负责人处置。

## 历史：值班查询与小额补偿

以下[operations.py](../services/profile/operations.py)与旧启动命令仅供源码/历史追溯；当前执行从[稳定operator工具](../build/private-beta/operations/1077-operator-r1/OPERATIONS.md)及已签准入台账进入。当前工具按次启动、一次请求后清理，不是原r2六服常驻接口；不得直接照旧命令另起进程、覆盖凭据或向玩家补偿。玩家忘记密码走[游戏账号恢复](current-playable-delivery.md#玩家安装账号与故障恢复)。

在归档容器内以独立进程启动，预先将受限角色文件只读挂载到指定位置。该服务监听容器自身回环地址，值班工具通过同一容器网络命名空间访问。每名操作者有独立高熵口令，策略仅存 SHA-256 小写摘要，格式为 `{"operator_id":{"role":"viewer","sha256":"64位摘要"}}`。撤权或轮换后重启运维进程载入策略。

```powershell
docker compose -p punk-legion exec profile python operations.py --db /data/player.sqlite --policy /run/secrets/ops-policy.json --port 24679
```

请求携带独立的 Bearer 凭证。`viewer` 可读 `GET /ops/battles/<场次ID>`，数据库连接只读。响应含匹配的参战者、任务状态与流水引用，以及可访问卷上的存档文件类型。玩家角色仅能使用自己的游戏接口。诊断输出和拒绝日志均限制字段，勿将真实凭证、快照或原始请求体贴入工单。

`compensator` 可凭已核对的场次向 `POST /ops/compensations` 提交 `owner, incident, key, reason, resource, amount`。原因枚举为 `missed_reward`、`rollback_reconciliation`、`duplicate_charge`。每次一种基础资源 1–3 单位，依仓容实际入账；仓满可清仓后以原键重试。记下实际入账、操作人、时间、流水号及原因。相同键与参数返回已有流水，换键重复同一场次、同一玩家、同一原因会被拒绝。

## 历史：复测入口（须按任务另选，不整组执行）

以下命令是原M22选集，不是本轮可直接运行的回归清单。尤其`check_backup_drill.py`带旧镜像/恢复演练，不可按当前默认无迁移任务执行；任何入口须先审调用夹具，正式测试由test_lead在root明确范围与预算后执行。本次文档审查未运行这些脚本。

在仓库根目录运行。并发和恢复演练使用独立临时工程、独立端口及数据卷，运行后清理这些临时工程。旧镜像参数需要本机已有且能启动匹配数据库的实际历史档案镜像 ID。经济脚本固定模拟时钟、每日行为和种子，时间投影采用权威结算契约。

```powershell
New-Item -ItemType Directory -Force build/m22
python services/profile/check_economy.py --output build/m22/economy.json
python services/profile/check_soak.py --godot $godot --clients 4 --rounds 3 --output build/m22/soak.json
python services/profile/check_backup_drill.py --godot $godot --previous-image $oldImage --output build/m22
python services/profile/check_operations.py
```

