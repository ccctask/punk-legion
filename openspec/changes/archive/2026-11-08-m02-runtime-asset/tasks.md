## 1. 机器人样板
- [x] 1.1 校验冻结版本与内容哈希，目标 GLB 与 r07 manifest 一致
- [x] 1.2 实现可复用模型场景、动作与换装、独立预览
- [x] 1.3 Godot 4.6.1 在临时干净项目中完成 GLB 导入，Compatibility 在 GTX 1080 产出 [实际渲染](godot-preview.png)。[双实例检查](check_instances.gd) 验证默认与替代头/武器互斥、Idle 与 Move 分别运行，以及 Death 返回 Idle 后左履带恢复。复验命令见下。
- [x] 1.4 主代理独立验收

在游戏根目录加载资源后，运行 Godot CLI 加参数 `--headless --path game --script <check_instances.gd 的绝对路径>` 检查实例。独立运行 `res://assets/steam_crawler/preview.tscn`，按 1–4 检查动作、H/W 更换头和武器。桌面样板使用单台模型，Android、同屏预算和完整场景样板待对应模块复测。
