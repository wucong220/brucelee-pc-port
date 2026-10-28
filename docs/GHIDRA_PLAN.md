# Ghidra 研究记录及精确函数入口

目标：用户 APK 内 `lib/armeabi/libdefault.so`，32 位 ARM ELF，`ET_DYN`，符号保留。装载时注意符号的地址映射和 Thumb/ARM 状态。**本机不具有 Ghidra，以下是供下一轮实际逆向用的步骤，而非已经反编译出的代码。**

| 目标 | ELF 符号值 | 证据性质 |
|---|---|---|
| `CPackagerFileSystem::_ReadHeader()` | 0x002df250 | `nm -D -C` 已确认 |
| `CPakDFilesManager::Load(IInputStream*, bool)` | 0x002e2ef4 | `nm -D -C` 已确认，已用 LLVM 对起始指令反汇编 |
| `CPakDFilesManager::GetInputStream(void*)` | 0x002e1224 | `nm -D -C` 已确认 |
| `CPakDFilesManager::GetSize(void*)` | 0x002e0db0 | `nm -D -C` 已确认 |
| `CPakDFilesManager::GetOffset(void*)` | 0x002e0da0 | `nm -D -C` 已确认 |
| `CBeatEmUpGame::LoadFighterAnimations(...)` | 0x0017bb18 | `nm -D -C` 已确认 |
| `CBeatEmUpMatch::KrmInputEventCallback(...)` | 0x00161c20 | `nm -D -C` 已确认 |
| `CAnimationDescr::ParseFromKDF(...)` | 0x0022d6d0 | `nm -D -C` 已确认 |
| `CFighter::AttackDamage()` | 0x001a0358 | `nm -D -C` 已确认 |
| `CFighter::ModifyHealth(int)` | 0x001a03f4 | `nm -D -C` 已确认 |
| `CFighter::IsAttacking()` | 0x001a02c4 | `nm -D -C` 已确认 |
| `StartFight()` | 0x00186b6c | `nm -D -C` 已确认 |

建议流程：
1. 在 WSL2/Linux 的 Ghidra 导入 `libdefault.so`，完成 ARM 分析，检查 import base 和各符号落点。
2. 在 `CPakDFilesManager::Load` 进入 Decompiler，记录从 `IInputStream` 读取 `uint32` 的字段顺序，追踪每次分配、循环的边界，给出 pseudo-code 及字段尺寸；用用户上传 `Core.pakh` 的首 64 字节逐字段验证。
3. 在 `CPakDFilesManager::GetInputStream` 定位实际进入 `Core.pakd000` 的读取调用；观察 offset、压缩模式、单个块与多个块之间的关系。不要仅凭相邻 zlib 头对齐就宣布它是独立文件。
4. 在 32 KiB / 100 KiB / 128 KiB 的三个已完整解压样本上对照：首块已识别为 `1FDKENONCTX3`，第二个为 RIFF/WAV。第 5 个样本可输出 262144 字节但未见 zlib EOF，可能表示分块读取/截断/流拼接，需要回到反编译验证。
5. 把所有新增结论连同函数地址、pseudocode 片段、偏移/大小、MD5/SHA-256、错误条件写进格式规范，并用测试夹具验证，然后才实现批量提取器。
6. 随后寻找 `mesh`、`skl`、`anm` 的 KDF/资源读取例程，写单元测试，最后做 Godot 格式转换。

**手工反汇编基线（无需 Ghidra）**：

```bash
llvm-objdump -d -C --start-address=0x2e2ef4 --stop-address=0x2e3150 libdefault.so
```

文件保留 DWARF sections 及符号信息。原始函数名可大幅降低调查成本，但源级算法、结构和跨文件引用仍需验证。
