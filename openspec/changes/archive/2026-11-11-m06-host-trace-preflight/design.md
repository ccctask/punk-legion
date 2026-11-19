## Context

读docs/README、M06的phase-pair.md/scheduling.md/native1010.md及2026-11-11当前短基线归档。旧guest调度已做，host线程名为空；release Godot库仍strip，debug模板build-id不同。无项目ETL可离线复用，已有WPR/tracerpt/Get-WinEvent，未找到WPA/xperf/TraceEvent或.NET SDK。

本机WPR CPU.Light **filemode**系统与事件缓冲各20MiB，不用约1.6GiB的Memory配置。它仍有全宿主调度与采样成本，不称低扰动已验证。模拟器35.3.11的本机QEMU2.12帮助列有-qmp，二进制有query-cpus-fast；这只证明前置可能性，尚未取得实际映射。

## Decisions

### 1. 先验证一个已知线程，暂不采游戏

工具只进本change verification和`build/m06-host-trace-preflight`。先交主代理审核命令/清理/解析入口，获放行才运行。起采前明确WPR没有其他录制，优先使用本机实际支持的唯一instance名，并记录任务、Profile、session、所有子PID与路径。既有录制存在就停止，不cancel别人的session。

一次固定不超过5秒CPU.Light filemode：单个已知PID/TID工作线程，记录QPC频率/单调时间/UTC桥、GetThreadTimes及预定busy→sleep→busy阶段。与ETL生命周期匹配，不以header TID代替payload的New/OldThreadId或ReadyThread目标TID。用内置tracerpt解析，必要时只用已有Get-WinEvent/Windows API备选，不装依赖。保留ETL和摘要；输出只含本轮子进程过滤结果。大XML按流解析，ETL上限256MiB、派生文本512MiB，转换/解析限120秒。

必须实际解出Process/Thread生命周期、ImageLoad、CSwitch（CPU、old/new TID、old状态、时间）、ReadyThread目标及lost事件/缓冲统计，时钟单位与频率须有原始依据，不猜字段。独立从context-switch对积分Running，记录Ready/Wait状态路径与空隙，已知线程同段Running对GetThreadTimes误差不超过max(5ms,5%)，全程丢事件为0。主代理从原始输出独立复算。计数成功但不能解payload不算通过。只允许首次明确配置/入口失败且已清理后主代理批准第二次≤5秒；重写解析器使用同一ETL，不为凑结果不断重采。

### 1a. 首次配置失败与仅剩一次修正机会（2026-11-11）

attempt1正常停止且零残留，但CPU.Light的完整header跨度7.7000175秒，超过原5秒；4.2053757秒的stop请求不覆盖该失败。原失败、初版源和原ETL保留。内置tracerpt未解CSwitch v5/Thread v3，已依据冻结Microsoft PerfView源码在**同一ETL**解码，root独立得到510条目标切换、255个无缺口/重叠Running段和已知sleep的Wait→Ready→Run；整体CPU积分1398.65575ms对GetThreadTimes1375ms，误差满足原标准。这只补齐字段可解释性，未放行设备。

第二次是本change原有两次上限内的**配置修正**，必须另经root静态审核和明确放行。准备单SystemCollector的最小自定义WPRP，仅CpuConfig/ProcessThread/Loader/CSwitch/ReadyThread，无CPU采样、额外事件provider、栈或无关内存/电源信息；按官方CaptureStateOnSave配置移除不需要的全机Loader/ProcessThread结束rundown（如本机schema不接受则停止，不试探启动）。只核本轮worker实际Start/End与ImageLoad，不依赖全机rundown补身份。filemode缓冲预算不高于原40MiB，实际profiledetails须证明唯一collector和keyword集合。

主动stop提前为3.20秒，worker改为0.6秒busy→0.6秒sleep→0.6秒busy，给正常生命周期和停止留余量；完整header仍须≤5秒，CPU误差/零丢失/所有资源门槛不变。源码manifest纳入WPRP，重采入口只能在确认首轮因该配置门槛失败、已清理且收到root显式第二次授权后接受。不得伪改attempt1 completed_capture=true或隐藏失败。第二次失败后本轮不再采，AVD仍禁止；每次ETL/派生文本沿用原限额，原始证据与大小清单保留。

第二次是否满足控制时限仍待实测；这是有证据的减量配置修正，不提前承诺低扰动或游戏收益。参考：[官方自定义profile与必要keyword](https://devblogs.microsoft.com/performance-diagnostics/authoring-custom-profiles-part-2/)、[官方SystemProvider结束rundown控制](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/capturestateonsave-in-systemprovider)。

### 2. 解析通过后才验证一次QMP身份

不启动游戏或容器。主代理确认第1门槛后才允许唯一现有AVD（read-only/no-window/no-snapshot，四核），设备总限10分钟；先核可用内存、既有实例和专属端口5073/5564/5565/5079。QMP仅绑定127.0.0.1:5079，不改当前试玩329xx端口。

正常QMP greeting/capabilities后仅query-version、query-status、query-cpus-fast和必要的只读query-commands；如需核guest APIC，仅对返回的qom-path执行qom-get/apic-id。不执行暂停、改CPU、热插拔、内存读取或写入命令。记录两次query-cpus-fast的四个cpu-index/thread-id，必须与同一个已核归属的本机QEMU PID下的四个实际Windows线程对应并保持稳定。guest仅读取online CPU和/proc/cpuinfo及topology，明确QMP属性/APIC与guest逻辑CPU的对应依据；数量相同不足以宣称已映射，无法唯一对齐则保留该缺口。

本门槛不采新的战斗帧/Perfetto，不重试不同AVD参数或增开设备。QMP不支持、TID不在该进程、拓扑不能证实，均保存实际失败并结束，不用猜测替代身份。主代理独立复核查询原文、Windows线程归属与guest拓扑。

### 3. 可支持结论与停止条件

这些结果只决定后续归因工具是否可用，不是三席30FPS或某优化通过。GetThreadDescription描述可变/不唯一，旧Windows源码明确没有命名，不能据源码字符串推实际身份。QMP映射的对象是**vCPU**而非固定Android GLThread；guest任务可迁移。WHvRunVirtualProcessor同步阻塞到虚拟机退出，不能把host等待直接解释为guest未执行。

下一次实战采集仍须另经有界OpenSpec：先确认实际Godot主循环线程（旧GLThread而非Java主TID）、ETW/Perfetto/SF时钟与足够精度、探针OFF→ON→OFF扰动及丢事件。本轮不预授权战斗追踪；现有33.6–42.8ms配准误差不足逐帧归因，也不能从此给GPU毫秒数或无符号引擎函数名。

## Resource closure

所有成功/失败/超时路径保存证据后停止自己启动的WPR session和子进程，复核not recording，不能无归属cancel。采集看门狗独立执行，5秒主动采集限与停止/转换时间分别记录。设备如获放行，先核AVD/序列号再正常ADB退出，关闭专属ADB/监督进程和QMP，复查四端口/PID；不删除AVD/镜像/其他环境数据。root独立核1075六服ID/镜像和正式APK不变。前置失败按原失败事实记录，未执行门槛不伪称实际验证；不勾M06原未验项，不以准备工作替代实际性能出口。

## Sources

- [Microsoft CPU分析：调度与采样的区别](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/cpu-analysis)
- [tracerpt官方命令与原始时间选项](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/tracerpt)
- [线程描述的访问与限制](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getthreaddescription)
- [QEMU只读CPU查询例子](https://www.qemu.org/docs/master/system/cpu-hotplug.html)
- [Android emulator的-qemu透传](https://developer.android.com/studio/run/emulator-commandline)
- [AOSP Windows线程ID实现（源码不等于本机版本已匹配）](https://android.googlesource.com/platform/external/qemu/+/emu-master-dev/util/oslib-win32.c)
- [WHvRunVirtualProcessor同步行为](https://learn.microsoft.com/en-us/virtualization/api/hypervisor-platform/funcs/whvrunvirtualprocessor)
