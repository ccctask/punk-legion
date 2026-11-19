# Design

## Context

见proposal.md及M06 verification/root-blocked-entry-review.md和next-diagnosis-scope.md。已静态读expedition.gd _request/_response/_valid_party_snapshot与Handler.respond：不同失败合用同一横幅，profile默认不记访问日志，旧logcat过滤输出空。M09已有单次随机header关联、白名单JSON采集与局部.gdc/端点/稀疏索引替换；旧构建绑定1074且建新key不能原样运行。M06已有独立新库/初始6机夹具、设备Job与精确清理，可择需复用而不再跑战斗工具。

## Goals / Non-Goals

仅取得普通泵房待发读取故障的同请求双端证据。无业务修复、无通用追踪平台/菜单、无GUT全矩阵、无新地图玩法、无性能场次或正式版本替换。

## Decisions

1. **冻结诊断副本。** 基于rc1076，工具校验原哈希/唯一替换锚点。只给expedition.gd的pump待发HTTP及隔离server.py加元数据。原文件不动，生成可审源差异；所有分支条件、返回、JSON解析次数、重试/超时/按钮/请求次数及keepalive/写回流程保持。禁止新增flush、sleep、后台线程或业务状态补丁。诊断有日志/header的时序扰动，必须注明。
2. **按实际执行分支记录。** 每HTTP请求用随机不含身份的标签header关联，固定route、method、generation、重试序号、单调耗时。记request启动err、回调result/code/bytes、Content-Length与JSON解析结果、实际拒绝分支（含快照首个拒绝原因、stale/background/cancel）；不为日志重复调用校验或改变先后顺序。启动/退出标记说明包与采集身份。服务仅对合法标签及白名单pump路由记到达、status/字节、write返回或异常；异常原样抛出，不将写回完成等同手机收到。
3. **脱敏采集。** 固定schema与字段白名单；不记token/Authorization、密码、账号、邀请code、请求/响应正文或任意URL/异常文本。只保存专用JSON标记；解析器拒绝额外敏感字段/非法标签与路由。使用godot/Godot双标签并在设备阶段先验证启动标记和一条真实GET的服务/客户端事件都存在；缺一停止，不继续消耗观察窗口。
4. **局部派生。** 复用现成debug key预检结果，工具核相同公开证书/既有配置，通过隔离Godot有界编译生成诊断.gdc；不重签正式包、不生成新key、不完整export。诊断APK允许变化仅该脚本字节码、六端点cfg及稀疏索引；所有其他有效payload、清单/dex/native/资产前后相同，正式APK、515源及签名材料不变。独立验收代理负责实际编译/签名/验签和资源，不由root执行。
5. **分阶段放行。** 开发代理只实现本change工具及必要无引擎Python自检，提交diff/依赖/可复现入口。test_lead独立做字段拒绝与隔离编译/包验证，root先审工具和包来源再放行设备/容器。不做与改动无关的全套框架控验。
6. **唯一真实观察。** 一个独立Compose项目/新卷/三新账号，只起profile，不起战斗房间；沿用正常注册命名及声明的initial_fit生成器，各6台12点、固定一次合法泵房窗口。两API陪测席仅普通大厅join/ready，手机正常UI加入/选机/轮询。初始双端标记通过后，观察首个失败，若达耗尽允许一次普通手动刷新收其结果，再停止；若没有故障则在手机进入三席并选机后最多120秒截止，明确未复现。无出征/mission/战斗peer/SF采样、无强制Ready、无回放旧库、无重复补轮。
7. **预算和收尾。** 全设备生命周期≤20分钟，尽量复用原owner/supervisor，超时留证后同句柄清理。启动前记录共享1076/OGame/资产库及资源预算，保存精确IDs/PID创建身份/端口；完成/失败/超时均关自身设备子树及HTTP并按精确project down删容器/专网，保留命名卷。三人未出征账目、当前试玩与保护产物前后差异、清理数量/终态及准备/执行/清理口径交root；不要只按进程退出0判玩家场景通过。

## Risks / Trade-offs

诊断重签与日志/header可改变时序，未复现只能说明本轮观察结果，不能宣布原故障修复。编译或标记前置失败属于工具/观察失败，不重复启动到绿；提交具体缺口由root定案。只有profile时无真实出征路径，此为有意限于出发前大厅，不对战斗/网络性能作结论。若需要超出允许payload或新工具架构，先交root审查，不自主扩大。

实施澄清：上述不新增flush指HTTP响应wfile/socket流程；允许诊断stdout日志及时flush用于采集positive gate。允许有界中间export-pack仅提取目标.gdc，不做完整APK导出或Gradle，不消费其他重新导出资源。
