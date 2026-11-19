## ADDED Requirements
### Requirement: 当前匹配状态反馈
锈轨大厅 SHALL 在新搜索期间清除旧的取消反馈和无关的上一场摘要。

#### Scenario: 取消后再次寻找
- **WHEN** 玩家在已确认取消后再次寻找并收到等待状态
- **THEN** 等候区与下方提示均与当前搜索一致，匹配成功后可正常准备
