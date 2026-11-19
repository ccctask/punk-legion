# Design

## Context

见proposal.md。run.py的prepare、verify_project与实际argv均引用模块ENGINE常量，manifest已经记录console_launcher及SHA；当前固定值失效，已有同SHA引擎可明确指定。现有六例/83断言与失败门槛已验收，本次不改变它们。

## Goals / Non-Goals

恢复当前机器可运行的快速选集。仅改引擎选择及说明；不抽象多引擎安装器、不重构资源管控、不修游戏大厅、不运行安卓。

## Decisions

- prepare/run新增--engine，默认保持原值。统一解析为真实绝对文件，在任何新工作区写入或进程启动之前核存在与固定SHA，错误提供清晰信息及非零退出。不采用自动扫描，避免悄悄选错可执行文件。
- prepare把实际路径/哈希写入既有manifest。run验证所选路径与本轮manifest身份一致；不同位置但同SHA不静默改候选，要求新工作区。旧工作区不改写或适配。
- 开发者仅修改run.py和入口README，必要自测聚焦参数与拒绝路径；测试代理独立验证缺失文件、错误SHA、工作区身份不符均在启动前拒绝且不覆盖证据。使用同SHA实际引擎创建一个新工作区，单次rules组三例完成真实导入和执行、正确记录argv/manifest/清理；其他组和负控断言未变则复用历史结果，不把复用标成新执行。
- 最多一个Godot runtime，沿用Job有界清理、独立user目录和保护产物核验。无AVD、容器、数据库或网络服务启动（既有runner内部HTTP夹具照常收尾）。开发自测不重复真实rules场次。

## Risks / Trade-offs

当前入口仍依赖本机1076保护产物，保留此既有前置条件并在README说明；不为此泛化公共CI。显式路径与manifest绑定可能拒绝搬动工作区后的运行，选择新建本轮工作区，不修改旧证据。
