# Proposal

## Why

成功大厅GET交付候选已独立验收，但当前1076仍未整合，M06完整三席测量也仍缺实际战斗。需要可追溯的服务修订接替现有试玩，并将一次正常三席出征/结算与同场性能记录合并，避免重编客户端及重复联机流程。

## What Changes

- 冻结服务修订1076-delivery-r1：以rc1076为基底，仅消费已签server.py SHA c88f75eb8c86856fecf13a5ee55b3aafca991df54cd643e9cf1461f968b0b82f，正式APK/客户端/资产不改、不重签。
- 操作文件、server副本、覆盖清单及运行台账位于稳定operations目录。先用新project/六新卷的profile+party与既有334xx端点包，执行唯一三席正常泵房并复用M06采集工具；按生产全局终局收据界定整场，不把个人withdrawn误作已完成结算，也不把稍后战报UI等待算进战斗分母。
- 功能通过后核其余四服务及五路握手，检查当前真实活动/在途文件后接替333xx六服，保存新旧ID/配置与删除记录；新试玩使用本轮新数据，不导入旧1076数据。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无。已生效android-private-beta、engineering-baseline与device-battle-baseline要求的部署/验收落实，不改变玩法、协议或性能门槛；skip_specs=true。M06原任务的接受条件保持独立，数据不足或超预算不能因为服务整合完成而提升。

## Impact

M23服务交接与M06有限整场前置/同场验收。只新增本change规划/工具/证据及build/private-beta/operations/1076-delivery-r1持久配置，不改生产业务代码或原rc1076/正式APK/签名材料。开发代理准备稳定输入，test_lead执行全部资源/联机/测量/交接，root独立签收，进度代理同步。已签M15及R3/R5不受影响的断言按依赖复用，不重跑故障/经济/渠道矩阵；不迁移、不回放旧数据、不演练保档升级回退。
