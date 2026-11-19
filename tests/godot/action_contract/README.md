# Current action producer contract

Authority: [M04 change design](../../../openspec/changes/archive/2026-11-14-m04-current-action-contract/design.md). a3 Godot plus a4 Python received [limited root acceptance](../../../openspec/changes/archive/2026-11-14-m04-current-action-contract/verification/root-review.md). Original failures remain; all former grants are closed and output directories used. Construction qualification is **not** behavior acceptance. Future execution requires a new run, immutable lock and separate root grant; no Android/ENet/current-release claim.

`probe.gd` loads only current Sim/Field/Catalog/Rules/Mission. Runner stages these five sources without Autoload, import, cache or plugins. `probe.py` calls real `treasure_combat.unit/fresh/step` and workshop fit/deployment constructors. No old check_* entry, HTTP, DB, ENet, Docker, ADB or existing user data.

## Gate and resources

```powershell
python -B tests/godot/action_contract/run.py --mode qualification --run-id <new-id> --input-lock <lock.json> --approval <grant.json>
python -B tests/godot/action_contract/run.py --mode formal --run-id <different-id> --input-lock <new-lock.json> --approval <new-root-grant.json>
```

Run only the mode actually granted. Lock has absolute-path SHA256 maps: `production` (all515), `protected` (11), `tools` (four tools, parent README, process_owner.py), `runtime` (Python and both fixed Godot4.6.1 exe). Full production path set must match. Grant: `approved:true`, exact `input_lock_sha256`, `mode`, `work:"build/qa/<new-id>"`, `case_names:["J1","J2","J3","R1","W1"]`. These files do not themselves constitute root approval.

Fixed engine is inherited from [parent instructions](../README.md), never resolved from LOCALAPPDATA. Host process/memory snapshot before execution requires >=512MiB free. OwnedJob records original PIDs/creation identities, commands, timings and exact cleanup for every phase. One engine at a time. Qualification: common work30s / worker hard35 / owner hard40. Formal: common work60 / worker hard70 / owner hard75. GD check-only<=15, GD logic<=20, Python<=10, each constrained by common remaining deadline. Python compile produces no pyc.

## Cases and initial data

| Group | Actual path / oracle |
| --- | --- |
| J1 | Natural initial lock/aim and real repair; own unjammed baseline vs two-source jam. Independently observed due must become exactly +1s (1e-6); actual action quantized within one own tick. Shared protection charges one emitter. |
| J2 | Real first shot/repair establishes future due; ordinary move brings emitters into range during target motion. Target arrival/relock precedes original due. Oracle uses each branch's actual prior action and production interval, independently checked against baseline next action; never jam's own original_due field. |
| J3 | Idle target pulsed once, ordinary emitter retreat, original protection expiry, then declared 8HP wound: next eligible ordinary tick repairs immediately. Python same-run JSON full-state roundtrip/parallel advance. GD independent actual Mission fixture preserves8 NPC IDs, uses new FileAccess.store_var/get_var then actual restore/exact native checkpoint and parallel advancement across protection expiry. |
| R1 | Two arms compete for initial3.25 missingHP with declared last_damage=-10 quiet age. Actual clamp/one charge/paired actor-target-effective output. GD uses real Mission.combat_reports; no permanent-ledger claim. |
| W1 | Current rivet_repeater/cannon at3m/4m, two seconds. Both instance speeds0, target damage0; record original/fixture speeds and initial/final actual distance. Gun damage/range/interval unchanged. Fixed geometry isolates weapons, not movement acceptance. |

Whitelist: legal entities/parts, initial positions/targets, declared wounds/quiet age, empty obstacles for pure Sim, static non-tested opponents and zero damage for actors whose weapon is not compared. J2 tested tech retains production speed and gun stats. Moves use actual Sim.command_move or exact treasure.command input fields. Never assign tested cooldown/last_service/next_shot, lock/aim deadline, not_before, protection, charges or output events. R1 initial last_damage=-10 is a declared wound-age generator. No old formats/compatibility conversion.

Own GD quantum.05s, Python actual STEP.25s; no cross-model first-shot assertion. `--fixture-only` returns `prepared:true`, `passed:false`, `no_step:true` with zero clocks before any step/action loop. Reports separate product/fixture/tool failures and unrun groups; first failure stops subsequent groups/models without retry. GD report JSON is observational; the actual saved Variant preserves vector types. Fresh checkpoint file stays in this run evidence directory.

Output `build/qa/<id>/`: raw per-phase godot.log/process.json, stage hashes, separate model reports, worker/owner results and cleanup identities. `prepared` proves construction only. Formal needs all five nonempty passed groups in both models. Tools never fill tasks/root signoff. Evidence is reviewed independently by test_lead/root.
