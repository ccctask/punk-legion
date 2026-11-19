## Context
观察 1022 西阀实战截图。参考《帝国时代 IV》Smart 模式依据选中和受伤状态决定是否展示血条，以及《帝国时代 II》多选显示数量、单选显示单位详情的做法。https://www.ageofempires.com/news/age-of-empires-iv-patch-51148/ 和 https://www.ageofempires.com/learn-to-play/control-resources-aoe2/ 。
## Decisions
泵房多选时用选择圈和已选数识别小队，单选时显示该机自定义名称。守卫数沿用阀门状态提示。避免加入每帧的文字避让计算。多选切成单选、失去选中机体或重入时刷新。长名不得阻挡指令与阀门信息。
## Verification
重放已有西阀满编片段的权威位置与阵容，验证全选、单选、返回全队和失去所选目标的画面及输入。覆盖 960×540 与 640×360。使用新场次或新构造的位置场景。
