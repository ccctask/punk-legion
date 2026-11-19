# r2三席正常通关及同场SF

2026-11-13，test_lead执行；root已分别签收[功能/资源](../../../openspec/changes/archive/2026-11-13-m23-lobby-delivery-service-bundle/verification/root-r2-functional-review.md)与[测量有效性/预算结论](../../../openspec/changes/archive/2026-11-13-m23-lobby-delivery-service-bundle/verification/root-r2-measurement-review.md)。[原始证据与报告](../../../openspec/changes/archive/2026-11-13-m23-lobby-delivery-service-bundle/verification/r2-run-report.md)。

三席正常245秒通关、各有效指令/一次入场费/个人结果/释放累计完整，手机战报可见。SF保守248.345秒覆盖1.0、满编交火5.521秒155间隔、尾采充分；整场P95 77.455ms/满编交火80.811ms，M06帧预算不通过。

设备553.275秒，peer/collector/reader Job均空，临时两容器和专网已删、六卷保留、进程与凭据零；旧1076/shared及正式/冻结保护不变。无补场，未启动额外四服或333xx切换，r1工具失败仍保留。

当前状态更新：后续接替复验已由root独立[签收并接管](../../../build/private-beta/operations/1076-delivery-r2/handoff-v2/root-acceptance.md)，当前服务为1076-delivery-r2正式333xx六服、APK不变；运行身份见[稳定runtime](../../../build/private-beta/operations/1076-delivery-r2/runtime.json)与[维护入口](../../../build/private-beta/operations/1076-delivery-r2/OPERATIONS.md)。[接替实际报告](../../../openspec/changes/archive/2026-11-13-m23-lobby-delivery-service-bundle/verification/handoff-v2-report.md)保留首轮失败/恢复及v2成功证据。上段“未切换”指本次实战结束当时，不代表当前部署；接替未重跑实战/SF，不改变上述性能失败。
