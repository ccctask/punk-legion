## Context
营地与锈轨已能直接点敌人，秘宝只把落点转成移动。传统即时战略把同一个指令解释为攻击选中敌人或移动到地面。参考[暴雪基础操作说明](https://news.blizzard.com/en-us/article/4552956/game-guide-basic-unit-controls)。
## Decisions
优先识别手机屏幕上点中的敌机，候选重叠按与触点的距离和稳定顺序选择。排除阵亡和已撤离机体。原有职责或单机选择决定指挥对象。确保一次点按只产生一个指令。
## Risks / Trade-offs
同一触屏事件可能被 Godot 模拟为鼠标点击。验证真触控与桌面输入，复测 UI 按钮、远处地块和组内指挥。
