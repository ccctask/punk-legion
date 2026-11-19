## 1. 休闲组队探索

- [x] 1.1 邀请、加入、选队、准备与队伍预算
- [x] 1.2 共享探索区域、协作目标与各自所有权
- [x] 1.3 离队、重连和每人完整结算
- [x] 1.4 两人和三人实战、单位峰值、模拟器、等待时间
- [x] 1.5 主代理独立验收

[开发自测、实际 Android 截图与多人结果](verification/report.md)

主代理独立启动隔离 Compose 并发运行 [双人](verification/root-two.log) 和 [三人](verification/root-three.log) 普通 Godot UI；每人有不同钻头、各记一胜，另验 [中断/预算/重复结算](verification/root-party-ledger.log)。逐段解码验证 [双人全程](../../../../docs/evidence/m15-party-2.mp4) 与[三人全程](../../../../docs/evidence/m15-party-3.mp4)。移动端 3,688 个呈现间隔 p95 79.64ms，继续在 M06 跟踪；本机主部署 UDP 24569 已就绪。
