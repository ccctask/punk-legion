# Tasks

M00主责。仅工程治理；业务整改各自建change，未实施项不能随本项勾选。负责人要求和正式模块名已核。

## 1. 评审准入与权威入口

- [x] 1.1 主代理建立architecture-review流程/模板，将实现前签收、越界复审、历史例外和小改动简化规则写入AGENTS/OpenSpec context；核入口一致且不要求负责人重复批准技术细节。见[根签](verification/root-review.md)。
- [x] 1.2 建立按原路线seq61的M00–M24边界定位与A01–A12整改台账，更新docs索引/审计后续入口；核当前事实、目标边界、风险、正式验收与实际试玩状态有区分。见[独立文档审查](verification/test-doc-review.md)。

## 2. 真实问题试用与独立审查

- [x] 2.1 只读架构代理交A01/A05的调用链、状态/提交所有者、继承/生命周期、允许范围和最小失败合同；主代理据实记录试用，关键未定项不进入开发派单。见[真实试用](verification/review-examples.md)。
- [x] 2.2 test_lead独立审规则/模板/模块表/整改出口及本地链接，用未定状态所有者、误用全局、机械抽象、跨域写和实际范围扩大等反例检查准入规则；提交报告，不运行游戏或另启测试资源。见[审查](verification/test-doc-review.md)及[规范化源记录](verification/test-doc-final-source-normalized.json)。

## 3. 签收与交接

- [x] 3.1 主代理审独立报告及实际文档，签治理限定范围；进度代理维护原总览/阶段/任务看板，并指向A01/A05下一具体change或待审合同，不能宣称业务修复/性能或全架构整改通过。见[根签](verification/root-review.md)；原三页seq77/55/166已回读限定状态与稳定文档入口。

## Workflow follow-up

- 严格验证后同步已接受engineering-baseline增量并归档，修引用、保历史记录。
- 已完成同步/归档及[独立收尾](verification/test-archive-review.md)、[主代理签收](verification/root-archive-review.md)。
- 各业务修复遵循本门独立建change、实现、自测、正式测试和签收；治理归档不代表这些修复已完成。
