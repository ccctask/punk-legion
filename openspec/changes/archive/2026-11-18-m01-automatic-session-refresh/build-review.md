# 安卓构建工具最小差异准入

root，2026-11-17。适用本change最终候选，尚未批准执行签发或冻结未审源。

已读既有build_integration_candidate.py inputs与artifact/audit_artifact.py candidate_binding/main。两者还把上轮540实体及2345源manifest写死，新增已审PageRefresh场景后必须绑定本次实际源，不能复制另一套构建/审计平台或沿旧常量冒当前包。

允许最小工具修订：

1. 原监督builder的集合数量断言改用已root锁定输入的source_count（正整数）；仍完整比较manifest键集合与每实体SHA，保双OwnedJob、原签名库、唯一递增ledger、暂存转换仅三文件、预算及清理。
2. 原artifact candidate-lock在现4项基础上新增source_manifest_sha256及source_count，root approval继续绑定candidate-lock和输入锁SHA。验证格式后，用这两个明确权威值替代2345/540常量，保全部有效资源映射、Probe排除、模板、原生ABI/DEX、签名/AXML及负控断言。不由未经批准metadata自行选择期望源。
3. 原站点源SITES_SHA256等无关保护保持，不改模拟、地图和费用；如实际候选改到这些保护源，先回root核准范围。

构建/快照/签发只在最终实际源审和必要正式测试通过后另给精确输入门。准备版本暂定1084 LAN192.168.31.170，实际需核未发行及原签名；不执行迁移，不动现行用户R2六服务／手机。新包来源与仍运行后端镜像分别记录，不能宣称服务器同步升级。

修改由受派开发代理实施并交差异/轻量纯校验，test_lead独立审计实际包；root只审门与结果。不得用本准入顺带安装SDK、改签名、重打旧包或重写资源管理器。
