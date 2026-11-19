# 实际目录与装配合同校验

状态：本轮首次实际导出及四样例/指定控制已获[限定根签](../../../openspec/changes/archive/2026-11-14-m03-catalog-contract-check/verification/root-review.md)，见[实际报告](../../../openspec/changes/archive/2026-11-14-m03-catalog-contract-check/verification/test-independent-a1-report.md)。原执行门已关闭，已用run目录不得重放；以后须新run-id、新源锁和新主代理门。范围为[本change设计](../../../openspec/changes/archive/2026-11-14-m03-catalog-contract-check/design.md)和[四例预选](../../../openspec/changes/archive/2026-11-14-m03-catalog-contract-check/verification/test-plan.md)。不改生产定义，不跑旧schema夹具、数据库或网络。

`export_catalog.gd`在新最小项目中真实加载Catalog/Rules，先查原字典非有限浮点，再以full_precision导出三字段目录及四具名样例。`contract.py`读原JSON和实际workshop.CATALOG，精确比较键/序列/严格类型及有限数值；用生产Python装配入口验证同一fixture的四例。Python类型/数值/非有限拒绝与Godot序列化前拒绝另列工具控制。合成实体并非真实账号拥有权；不证明战斗时序等价。

由test_lead冻结新工具、生产闭包、解释器/引擎及11交付保护后，主代理批准一次新run。锁必须含`inputs`/`other_sources`/`protected`三组绝对路径→SHA、`production_files`的game/services生产文件集合；当前命名数据集排除`.godot`/`__pycache__`/`.git`和pyc。批准文件绑定`approved=true`、`input_lock_sha256`、仓库相对`work`及四个`case_names`（见contract.CASE_NAMES）。

```powershell
python -B tests/godot/catalog_contract/run.py --run-id <new-run-id> --input-lock <new-lock.json> --approval <root-new-grant.json>
```

固定引擎默认使用[既有测试说明](../README.md)的LocalCache Godot4.6.1绝对路径和bd9e SHA。该工具不下载引擎、不启import、不复制缓存/旧userdata。新stage仅两生产GD、新导出脚本和project配置；解析失败即停，不临场补import。每个run必须新目录，已用目录拒覆盖；原失败和完整输出保留。

统一工作60秒，清理15秒/总75秒，其中worker硬停70秒、owner留最后5秒核源及写报告；check-only最多20秒、真实导出最多30秒、缺导出CLI控制最多5秒，均按剩余公共deadline收紧。owner拥有业务worker，worker以既有OwnedJob顺序拥有单引擎及短命控制/只读host进程；原Job日志含PID/创建身份、退出/超时/空终态，失败与超时也收清子树。其它实例只记录，不按进程名清理。原导出、fixture、四例结果、独立拒绝控制及源锁保留；独立userdata的配置预期路径记入stage-manifest，不冒称已观测实际引擎路径，不删除其它环境。

正常结果需完整导出、四样例、严格比较/有限值及精确MissingExport非零控制全满足。期望拒绝原结果仍`passed=false`，由`control_satisfied`区别于产品失败；不拿任意崩溃或exit0当通过。无HTTP/DB/ENet/容器/设备或当前1077/r2操作；不能据此重签现有APK、全部A04或性能。
