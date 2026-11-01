# ARM PIC GOT 引用扫描记录

## 实际结果

本机只读输入 `%LOCALAPPDATA%\BruceLee-PC-Port\binaries\libdefault.so` 的 SHA-256 为 `1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70`。ELF `.rel.dyn` 地址 `0x00604d50` 的重定位类型数值为 `0x15`，动态符号名为 `_ZN3krm3anm13gid_PositionsE`。槽地址是 ELF 虚拟地址，不是运行时绝对地址。

使用 512 字节窗口，工具找到三条候选 `ldr`：`0x00407648`、`0x00411294`、`0x004147e0`。首条已核对其指令链：`0x004075a4` 加载 literal，`0x004075ac` 以 PC 构建 GOT base `0x005fd418`；`0x0040763c` 加载 `0x004076ec` 的值 `0x7938`；`0x00407648 ldr r1, [r4, r3]` 的有效地址是 `0x005fd418 + 0x7938 = 0x00604d50`。另外两条是工具候选，尚未独立验证控制流。

显式使用 `--window 64` 返回空列表；现默认窗口为 512 字节：首条引用从最早来源 `0x4075a4` 到 `0x407648` 间距 164 字节。初版还在调用和所有分支清空寄存器，因而即使窗口加大也漏掉该正例；现保留遵守 AAPCS 的被调用方保存寄存器，并启发式传播前向条件分支状态。

## 复现

依赖 Python Capstone 模块，本机使用 Python 3.12 和 Capstone 5.0.7；模块缺失时工具明确报错。另使用现有 `native_hierarchy_links.file_offset`。工具只读输入，验证小端 ARM ELF32，扫描可执行 PT_LOAD，追踪 PC-relative literal LDR、ADD 和寄存器索引 LDR 的常量及来源；PC 取指令地址加 8，32 位回绕。输出 JSON 包含十进制地址、指令、literal 地址及值。

在仓库根目录执行：

```powershell
py -3.12 -B -m unittest discover -s tests -p test_native_arm_got_refs.py -v
py -3.12 -B tools\native_arm_got_refs.py "$env:LOCALAPPDATA\BruceLee-PC-Port\binaries\libdefault.so"
py -3.12 -B tools\native_arm_got_refs.py "$env:LOCALAPPDATA\BruceLee-PC-Port\binaries\libdefault.so" --window 64
```

上述命令本机退出码均为 0；7 项测试通过，覆盖 literal/add/index、调用保存寄存器、前向条件分支、覆盖、错误槽、窗口过期、未映射 literal、移位索引排除、最早来源窗口边界与缺少 Capstone 的导入/命令行行为。动态重定位使用现有 `_section` helper 读取 `.rel.dyn`、`.dynsym` 与 `.dynstr` 得出；原始库未写入或复制到仓库。

## 局限

这是候选搜索而非完整控制流分析。前向条件分支在目标处以启发式合并状态，不能保证不同路径值一致或证明可达；调用保留 r4–r11 假设目标遵守 AAPCS。扫描不支持 Thumb、条件指令常量传播、后向分支分析、寄存器搬运、其他算术、移位索引、栈或内存传播、立即数偏移目标 LDR 和运行时重定位后值。可执行段混有 literal 数据时线性反汇编可能误认指令。候选需人工核验指令边界、路径和语义；空结果不证明没有其他引用。
