# M06 整场测量准备

维护者：test_lead。对应 [m06-full-pump-playtest-readiness](../../../openspec/changes/m06-full-pump-playtest-readiness/tasks.md)。下文是准备历史；其后唯一获批的隔离运行已在正常泵房准备入口受阻，见[失败提交](../../../openspec/changes/m06-full-pump-playtest-readiness/verification/blocked-entry-report.md)。没有创建游戏mission或采得整场性能；临时服务/设备已收尾，后续行动等待root定案。

2026-11-13唯一keytool调用通过：现成私钥条目恰好一个，公开别名 `androiddebugkey`，证书SHA256 `10cdd8cac007ad56a711e6c63f42e6782c3d4687f8491ce1a313a1e735bea927`，与正式发行证书不同。口令由既有Godot设置经环境传入，未猜测、展示、写盘或创建密钥。

[实际报告](../../../build/qa/m06-keytool-20261113-a1/report.json)记录keytool退出0、Job耗时1.256秒、未超时；PID33480/keytool和29608/conhost的创建身份及终态可核，Job和同身份存活列表均空。[公开证书列表](../../../build/qa/m06-keytool-20261113-a1/keytool-job/godot.log)为原始输出。准备与保护核对另计，不把这次工具预检当作游戏性能结果。

[前保护记录](../../../build/qa/m06-keytool-20261113-a1/protected-before.json)与[后记录](../../../build/qa/m06-keytool-20261113-a1/protected-after.json)一致；515冻结源逐文件验证通过，正式APK/meta、Godot设置/debugstore、原签收来源和实际发行vault/issued均未变。普通Local下不存在完整vault，入口依据已签signing-origin解析原Codex LocalCache位置，仅哈希保护，不解密发行密钥；路径前置在唯一attempt之前核验。

有限试玩材料已提交：[玩家入口](../playtest/player-start.md)、[已知限制](../playtest/known-limitations.md)、[观察员空白模板](../playtest/observer-template.md)。只引用1076正式包，诊断包不作试玩分发；真人、人耳、实体设备反馈仍待实际观察。

一次[诊断构建](../../../build/diagnostics/m06-full-pump-playtest-readiness/report.json)实际8.124秒，低于120秒预算；489有效载荷中487相同，仅六端点cfg及唯一sparse索引变化。原package/code1076和协议5保留，v2/v3验签、16K对齐通过。输出SHA256 `489e9a82df585229cbf9ac08e7a201d05e59bbb748e07a36334833282432b0ad`，只作隔离测量，不作玩家下载。align/sign/verify/verify-alignment四个Job退出0且子树清空；前后保护相同，无Godot重导出、密钥新建或发行写入。

主代理已签预检与任务3.1材料，见[准备审查](../../../openspec/changes/m06-full-pump-playtest-readiness/verification/root-preparation-review.md)；构建提交及后续阶段由同一独立审查记录确认，不自行勾选任务。当前试玩六服恢复属于独立维护，见[恢复记录](../../../build/qa/restore-1076-20261113-a1/result.json)，不计为本轮新场次。
