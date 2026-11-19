- [x] 1.1 Implement building placement, connected power, station interaction and authoritative shared research state with an idempotent ledger.
- [x] 1.2 Expose the learned recipe, its cost and capacity checks through normal warehouse crafting; verify original physical identity through actual refit.
- [x] 1.3 Independently play build, power, research, craft and fit on a fresh account; exercise duplicate requests, outages, full inventory and existing workshop research.

主代理以两套独立新账号核对。HTTP 并发研究和制造各返回同一回执，总消耗为 1 结构、4 通用零件、1 能源，断电后仍能制造。960×540 Godot 窗口从基地点击建站、研究、仓库制造到换装，与原机体和实体目镜编号逐一对应。[窗口实测](verification/root-window/result.json) · [研究站截图](verification/root-window/station.png) · [费用与重登](verification/root-stock.json) · [满仓与两站检查](verification/development/check_api.py) · [源清单](verification/root-manifest.json)。
