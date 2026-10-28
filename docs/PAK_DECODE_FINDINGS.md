# Core.pakh / Core.pakd000 实测解析进展（2026-10-28）

本报告根据用户提供的 `Bruce Lee Dragon Warrior v1.15.26.zip` 中 `data.zpak` 进行**只读实测**，不包含原版资源、模型、动画或音频数据，也不意味着这些资源可公开分发。

## 完整验证过的发现

- `Core.pakh` 头签名 `8KAP`；偏移 `0x10` 是 `DTRS`，偏移 `0x14` 是资源条目数 **2144**。
- 偏移 `0x18` 开始为 **2144 × 36 字节**的表，至文件偏移 **77208**；紧接着有值为 1 的 32 位字段，之后出现资源目录字符串。
- 36 字节记录的已观察字段布局：`<I16sIIII`，即升序唯一的 32 位 key、16 字节尚未解释的字段、恒为 0 的 32 位字段、解码长度、物理存储长度及暂未确定语义的 flag。**不要把 16 字节未知字段解释为 MD5 或目录哈希。**
- 2144 条记录的存储长度之和 **109,641,135 字节**，与 `Core.pakd000` 文件大小逐字节一致。
- `Core.pakd000` 中每个资源以 `uint32(262144) + uint32(首块压缩长度)` 开头，后续块只有 `uint32(压缩长度)`。整个资源是**跨压缩块连续的 zlib 流**，直到 zlib EOF 为止。不能像旧版 `pak_probe.py` 那样要求每块都有独立的 zlib EOF。
- 实际顺序处理全部 **2144 个数据流**并解压到 zlib EOF，累计 **325,791,952 字节**；最终位置恰好为 `109,641,135`。每条解压/存储长度组合的多重集合与索引 2144 条记录**完全一致**。
- **1886** 个数据流可凭唯一的 `(解压大小,存储大小)` 二元组找到唯一索引；另外 **258** 个因两个字段相同，必须等待目录哈希/其他字段解析才能判定具体索引。
- 实测第 5 条物理资源存储 **313405** 字节，4 个连续压缩块，解码 **787024** 字节，在索引中唯一对应 ordinal **157**。过去将其称作“截断 zlib”是误判。
- 目前恢复的是**完整数据流和长度映射**，并不是完整的原文件名/格式映射；暂未验证 `mesh`/`skl`/`anm` 文件格式，也未将原版角色导入 Godot。

## 可复现命令

Windows PowerShell（在仓库根目录）：

```powershell
py -3.12 -m unittest discover -s tests -v
py -3.12 tools/pak_extract.py "D:\BruceLee\Bruce Lee Dragon Warrior v1.15.26.zip" --report "$env:LOCALAPPDATA\BruceLee-PC-Port\pak-verification.json"
```

如需导出解压后的原始资源，仅写到**仓库外的本机目录**：

```powershell
py -3.12 tools/pak_extract.py "D:\BruceLee\Bruce Lee Dragon Warrior v1.15.26.zip" --extract "$env:LOCALAPPDATA\BruceLee-PC-Port\decoded-resources"
```

输出 `.bin` 为原始解码数据，文件名中 `disk_NNNN` 表示数据流物理顺序；`key_...` 仅表示长度唯一匹配时的索引 key，**不是游戏资源名称**；`ambiguous` 表示存在多个候选。命令只读取原始 ZIP，不覆盖已有导出文件；如遇异常，可能保留此前已写出的部分文件，应在人工检查后清理。

## 下一步（真正关系到 PC 游戏移植）

1. 逆向 `Core.pakh` 尾部的路径目录与各资源 key 的关系，消除 258 条重复长度的歧义，并把资源还原成原版路径/名称。
2. 对解出的 `m01_`、`m02_`、`BL_BruceLee_` 资源识别私有动画、网格和骨骼编码；开发本地转换器。
3. 在 Godot PC 原型中先导入一个真实李小龙模型以及 idle/punch/kick 三套实际动画，再进入攻击帧和判定规则复原。

本次真实扫描已通过；Godot 实机运行和 Windows EXE 导出仍未验证。
