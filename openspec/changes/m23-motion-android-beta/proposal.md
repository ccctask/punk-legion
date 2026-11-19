## Why

负责人要求A网络显示、B安全转弯、C轻惯性均验收后更新安卓内测包。B/C改变权威规则，单独重打客户端却继续连接旧服务器不能交付所需体验。

## What Changes

- 以最终批准的共同源冻结客户端与实际服务器，发布唯一新versionCode候选，独立审计签名/端点/ABI/有效载荷。
- 候选服务使用本轮独立新卷/新账号/新场，配置和实际资源台账持久放operations目录，不套用户R2旧卷。
- 复用既有Owner/构建/审计；硬锁旧1082的镜像及Android工具先评审最小参数化，不冒称旧工具已支持新包。
- 执行必要Godot/真实服务/一台Android模拟器切片，root签后登记安卓包和新服务；旧手机服务是否退役据实际设备/活动归属判断。

## Capabilities

### New Capabilities

无；交付与工具整合，不新增玩法要求。

### Modified Capabilities

无；产品行为由m04-authoritative-safe-turning与m04-authoritative-light-inertia约束，本change使用skip_specs。

## Impact

主责M23，关联M05/M06/M14/M22。不做旧数据迁移、旧场回填或兼容fallback；不代负责人真机/听感终验。当前1084/手机1083/原R2在被明确接替前保持原事实，禁止全局Docker清理或按进程名扫杀。
