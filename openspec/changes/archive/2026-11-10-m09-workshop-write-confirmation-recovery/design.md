## Context
[1073现场诊断](../archive/2026-11-10-m09-android-workshop-reply-diagnosis/verification/incident1073/report.md)证实同key连接失败后可成功取得原收据，且没有重复制造。底层网络层原因仍未知。[Godot4.6 HTTPRequest](https://docs.godotengine.org/en/4.6/classes/class_httprequest.html)定义result2为连接建立失败，状态、超时与解析失败应据实际反馈处理。当前换装和初次GET已有0.6秒的一次自动重试及手动恢复。

## Decisions
沿用既有有限策略：每轮确认至多自动重试一次，保留同一action/fields/key。手动重试可开启下一有限轮；本轮重登从保存pending恢复，不另造新编号。覆盖design/build及工坊读取的短暂连接失败、超时、无效正文和服务错误。明确业务拒绝（材料不足等）继续正常显示。沿用换装已有专用核对规则。

成功确认需要正确工坊结构及属于当前动作的收据。制造校验design、robot和installed等既有字段，方案确认其design/revision。若操作原先已完成但当前机体或方案后来变化，确认原收据后显示当前实际状态，避免把有效历史收据无限重投。失败期间不能另发新制造操作，旧库存只作为上次读取。

独立新库构造三类目标：首发连接拒绝后恢复、服务提交后丢回包再重投、连续失败超过一次自动重试。验证手动恢复、应用重启、单笔扣费和机库选中实体。正常制造、方案保存、换装、初次读取及业务拒绝同时核对。测试注入仅限专用实例，清理HTTP/窗口/代理。

## Scope
仅修订恢复及反馈，不修改费用、生产、日常或回包连接策略。测试反馈不得宣称底层连接故障消失。待决问题无。

## 收据归属评审补充
现有design收据只有design/revision、build只有design/robot/installed，无法仅凭同构内容区分同一方案的两笔制造。design/build成功HTTP响应仅在receipt副本中增加confirmation_key，来自已通过operate参数/签名/幂等校验的fields.key。持久化账本不改。客户端先精确比对pending.fields.key，再核对动作、design及现有字段；测试必须拒绝其他操作的同构合法收据。运行日志只可记录原编号哈希。
