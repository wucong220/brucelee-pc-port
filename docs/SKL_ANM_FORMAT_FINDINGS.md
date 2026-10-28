# Bruce Lee `.Skl` / `.anm` 容器取证（2026-10-28）

本记录只保存哈希、偏移、长度和少量格式元数据，不包含原版模型、骨骼、动画或网格二进制。所有资源均由完整原包中的 PAKH 路径、索引和 PAKD 偏移定位，并通过实际解码后的 SHA-256 核对。

## 已定位资源

| 路径 | 索引 | PAKD 偏移 | 解码字节 | SHA-256 |
|---|---:|---:|---:|---|
| `adreno_200/skeletons/bl_brucelee_01_High.Skl` | 713 | 9,982,844 | 16,526 | `4a6d4532b42d6cbee3016b849befc2dc98c089e72fa4cfe291d9550f059412e3` |
| `adreno_200/animation/m01_idle_01.anm` | 653 | 17,145,342 | 11,669 | `adbfa5a598995b0424fb829a95d22d55407aec3fa31d67854d9c6bf6846cfa52` |
| `adreno_200/animation/m01_pnch_low_01.anm` | 1973 | 91,694,440 | 22,669 | `47a40807899674244285eae06de8341660e36b6a987e88e50705edde015bb439` |
| `adreno_200/animation/m01_kick_low_01.anm` | 809 | 93,740,967 | 26,221 | `fe202a35ce7c7c149a7dafe42496f06dc4b95b63c8fceacdff4d6d2ec98b2f03` |
| `adreno_200/objects/bl_brucelee_01_High.obj` | 1097 | 15,363,195 | 15,481 | `d97f09cb4b4f5c05fd3ddd0f3fa73d8d03440f113baa598ecc5891599e3e2a65` |

五个资源均以 `1FDKENONCTX3` 开头。字符串表共 309 条，CRC32 加长度规则全部通过；每个资源末尾 16 字节与 PAKH 资源标识一致。

| 资源 | 字符串数量 | 字符串表结束 | `DATA` 标记 |
|---|---:|---:|---:|
| Skl | 101 | `0x751` | `0x752` |
| idle | 30 | `0x243` | `0x249` |
| punch | 31 | `0x255` | `0x259` |
| kick | 31 | `0x255` | `0x259` |
| object | 116 | `0x980` | `0x9a1` |

## 已验证关系

- `.Skl` 字符串表中连续出现 69 个身体、面部、手指和腿部节点名称；这 69 个名称全部能在 `.obj` 字符串表找到。
- 三条动画的最后三个字符串均为 `skeletons/`、`bl_brucelee_01_high`、`skl`，与已定位骨骼路径一致。
- `punch` 与 `kick` 的 31 个字符串同序同内容；`idle` 比两者少 `positions`。
- 动画字符串表确认存在 `firstframe`、`duration`、`framerate`、`bonepos`、`bonerot`、`positions`、`scales`、`waveletsample`、`rawfixedsample`、`quantizedbits`、`quantizedradix`、`huffman` 和压缩通道等键名。
- 原生符号表存在 `CAnimRes::Parse`、`CAnimRes::RegisterHeader`、`CAnimationDescr::ParseFromKDF`、`anmPlayer::SetAnimation` 和 `anmState::GetDuration/GetNumSamples`，详见 `docs/NATIVE_ANIMATION_EVIDENCE.md`。

这些证据证明三段动画声明了同一骨骼资源，且容器和名称空间已经定位；它尚不证明采样轨道与骨骼节点索引的二进制绑定方式。

## DATA 头部观察

下列是 `DATA` 标记后前四个小端 32 位整数的实际值：

| 资源 | `DATA+4` | `DATA+8` | `DATA+12` | `DATA+16` |
|---|---:|---:|---:|---:|
| Skl | 1401 | 10 | 0 | 3364 |
| idle | 83 | 12 | 0 | 10332 |
| punch | 99 | 14 | 0 | 21180 |
| kick | 99 | 14 | 0 | 24732 |
| object | 1115 | 234 | 0 | 3120 |

这些整数可复现，但语义尚未由二进制结构证明。不能把 `DATA+4` 直接称为帧数或骨骼数。

四个已逐项验证的资源都符合同一布局：`DATA+4` 是 8 字节属性记录数量 `M`，`DATA+8` 是二进制分组数量 `N`，`DATA+16` 是数据区长度 `L`；`DATA+20` 起有 `N+1` 个分组偏移，随后是 `M×8` 属性表、`L` 字节数据区和末尾 16 字节资源标识。DATA 头长为 `24 + 8M + 4N`。两个计数的结构含义已被四条资源闭合验证，但不能据此把具体属性记录直接命名为帧数或骨骼数。

## Skl 层级与绑定数据

属性表中重复出现 `type → nodeid → parentid → treesize → offset` 序列，共形成 74 个节点：

- 1 个 root、3 个 object、70 个 bone；
- `nodeid` 为 0、2、4……146，全部唯一；
- 除根节点外，`parentid` 均指向已有节点；根节点 `parentid = -2`；
- 74 个节点的 `treesize` 与前序遍历的子树规模全部一致；
- 70 个 `bonepos` 和 70 个 `bonerot` 索引分别完整覆盖 0～69。

节点字段不是统一的标量编码。实际验证的 8 字节键值记录为：

| 字段 | 键记录 | 值记录标记 | 值 |
|---|---|---|---|
| `type` | `(0x60000000, string_ordinal)` | `0x60000000` | 再按字符串序号解释为 `root/object/bone` |
| `nodeid` | `(0x60000000, string_ordinal)` | `0x00000000` | `uint32` |
| `parentid` | `(0x60000000, string_ordinal)` | `0x10000000` | `int32` |
| `treesize` | `(0x60000000, string_ordinal)` | `0x00000000` | `uint32` |
| `offset` | `(0x60000000, string_ordinal)` | `0x30000000` 或 `0x30000003` | 语义仍未确认 |
| `bonepos` / `bonerot` | `(0x60000000, string_ordinal)` | `0x00000000` | 数据索引 |

因此，校验必须同时匹配键名序号和值记录标记；只接受 `(0, value)` 的通用标量扫描器会漏掉全部 `type`、`parentid` 和 `offset` 字段。

ANM 轨道声明使用同类显式相对指针。`bonepos`、`bonerot`、`scales` 和
`positions` 键后的值记录标记高四位为 `3`，其第二个 `uint32` 是从指针记录
到采样块 `type` 起点的相对记录数；指针记录自身的低 28 位是其他标志，不能
当作目标偏移：

```text
sample_start = pointer_record_ordinal + relative_record_offset
```

idle、punch、kick 三份真实 ANM 共 15 条轨道声明均使用该公式指向
`type`/codec 对，15/15 命中。将任一真实指针改动一个记录后，15/15 异常
路径均被解析器拒绝。解析器现在要求显式引用目标为实际采样块，
并按该目标绑定轨道，而不是只依赖声明与采样块的相邻顺序。

指针的 first 字段也在三份真实 ANM 中稳定区分采样类型：
`0x30000003` 对应 `rawfixedsample`（10/10），`0x30000004` 对应
`waveletsample`（5/5）。解析器对这两类已知 codec 同时校验目标记录和标签；
`rawfloatsample` 尚无真实 ANM 样本，不据此猜测其标签。每个 wavelet
`properties` 指针的第二个 `uint32` 在当前真实样本中均指向紧随其后的首个
属性记录，解析器也会拒绝其他目标。

节点名称由节点区前部的 74 组引用表给出，每组占两条 8 字节记录：

```text
(0x60000000, string_ordinal)
(0x30000005 | 0x30000006, relative_record_offset)

node_start = pointer_record_ordinal + relative_record_offset
```

74/74 组名称引用都唯一命中节点起点。该表的显式名称也纠正了仅看邻近字符串得到的候选：`nodeid=2` 是 `character`，`nodeid=4` 是 `skeleton`；`male_01` 与 `skeletonbase` 是节点内部引用，不是节点名称。

骨骼数据区包含 70 组位置、70 组旋转和缩放候选：位置按 `float32[3]`、旋转按 `float32[4]` 读取时，数值有限且 70 个四元数模长与 1 的最大误差约 `1.18e-7`；索引组也各含 70 个 `uint16`。这支持位置/旋转数据与骨骼节点的对应，但本地/世界坐标系及四元数分量约定仍未知。

| 分组 | 区间 `[起,止)` | 已验证布局 |
|---:|---|---|
| 0 | `0x335a–0x36a2` | 70 × `float32[3]` 位置候选 |
| 1 | `0x36a2–0x372e` | 70 × `uint16` 索引 |
| 2 | `0x372e–0x3752` | 3 × `float32[3]` 对象位置候选 |
| 3 | `0x3752–0x375a` | 3 × `uint16` 索引 + 填充 |
| 4 | `0x375a–0x3bba` | 70 × `float32[4]` 旋转候选 |
| 5 | `0x3bba–0x3c46` | 70 × `uint16` 索引 |
| 6 | `0x3c46–0x3c76` | 3 × `float32[4]` 对象旋转候选 |
| 7 | `0x3c76–0x3c7e` | 3 × `uint16` 索引 + 填充 |
| 8 | `0x3c7e–0x3fea` | 73 × `float32[3]` 缩放候选 |
| 9 | `0x3fea–0x407e` | 73 × `uint16` 索引 + 填充 |

骨架工具在验证每个 bone 记录内的索引后，会关联并输出 70 组静态位置、四元数和缩放数值。输出字段 `transform_coordinate_space=unverified` 与 `transform_quaternion_component_order=unverified` 是格式边界，避免把原始浮点数组误当成已经可用于 Godot 的局部变换。

共享 DATA 解析器还识别已验证的数组描述符：

```text
element_count  = descriptor & 0xffff
element_stride = (descriptor & 0x0fff0000) >> 21
```

当描述符高半字节为 `0x4`、元素数量和宽度均非零且段索引有效时，段长度必须等于 `count × stride`，最多允许 3 字节尾部填充。该规则在 Skl、idle、punch、kick 中共 50 组引用上闭合。

## 动画 scalar header 与采样区

三项基本数值直接来自属性表中的严格键值对：

| 字段 | idle | punch | kick |
|---|---:|---:|---:|
| `firstframe` | 0 | 0 | 0 |
| `duration` | 110 | 69 | 86 |
| `framerate` | 30 | 30 | 30 |
| `version` | 7 | 7 | 7 |
| `pose` | 1 | 1 | 1 |

未证明 `duration` 的单位一定是帧，因此工具保留原始整数，不擅自给出秒数。idle、punch、kick 的三维样本数量分别等于 110、69、86；这与 `duration` 数值一致，但压缩通道内容仍未解码。

| 动画 | 第一组 | 第二组 | 第三组 |
|---|---|---|---|
| idle | `rawfixedsample`；110×12B | `waveletsample`；2006×4B | — |
| punch | `waveletsample`；487×4B | `rawfixedsample`；69×12B | `waveletsample`；3268×4B |
| kick | `waveletsample`；566×4B | `rawfixedsample`；86×12B | `waveletsample`；3914×4B |

### 轨道组与采样对象

三条动画都把连续出现的轨道声明和随后的采样对象按同序配对。轨道声明使用
`轨道名 → 0x3xxxxxxx 指针`，采样对象使用
`type → 编解码器名 → data/offset → 数组描述符`。已闭合的组为：

| 动画 | 组 | 轨道声明顺序 | 对应采样 |
|---|---:|---|---|
| idle | 0 | `bonepos`, `bonerot` | 110×12B raw-fixed；2006×4B wavelet |
| idle | 1 | `bonepos`, `bonerot`, `scales` | 9×12B raw-fixed；10×8B raw-fixed；2×12B raw-fixed |
| punch | 0 | `bonepos`, `positions`, `bonerot` | 487×4B wavelet；69×12B raw-fixed；3268×4B wavelet |
| punch | 1 | `bonerot`, `scales` | 2×8B raw-fixed；2×12B raw-fixed |
| kick | 0 | `bonepos`, `positions`, `bonerot` | 566×4B wavelet；86×12B raw-fixed；3914×4B wavelet |
| kick | 1 | `bonerot`, `scales` | 2×8B raw-fixed；2×12B raw-fixed |

这里的“组”是记录顺序和采样数量闭合后的轨道组，不把
`0x3xxxxxxx` 指针值擅自解释成对象 ID。指针标记和值原样保存在 JSON 中，供后续原生加载逻辑复核。

### Raw-fixed 固定点解码

已验证的两类 raw-fixed 元素为：

- `bonepos`、`positions`、`scales`：3 个 little-endian `int32`，按
  `value / 4096.0` 解码为三维向量，即 `FixedPoint<12,int>`。
- `bonerot`：4 个 little-endian `int16`，按
  `value / 16384.0` 解码为四元数，即 `FixedPoint<14,short>`。

真实数据的数值也支持该解释：idle 首个 `bonepos` 向量的 Z 约为
`-19.9214`，第二组 `scales` 的解码值接近 `1.0`。punch 和 kick 的
`positions` 首帧为 `(0,0,0)`，随后以可连续累加的位移增长。没有把
`quantizedradix=12` 与 raw-fixed 的 Q12 混为一谈。

固定点四元数的分量顺序、左右手性以及最终是否需要归一化仍标为
`unverified`，当前只输出数值，不宣称已经可以直接生成 Godot 旋转轨道。
按 Q14 直接展开后，idle 四元数的最大模长误差约为 `6.07e-5`，
punch/kick 约为 `2.18e-6`；这属于源码整数量化误差，不能据此确定原生读取器一定会归一化。

### Wavelet 元数据

Wavelet 的 `offset` 是 `uint16` 索引表，但索引域随轨道不同：

| ANM 轨道 | Skl 索引域 |
|---|---|
| `bonepos` | `bone_position_indices` |
| `bonerot` | `bone_rotation_indices` |
| `scales` | `scale_indices` |
| `positions` | 尚未确认，工具明确标记为 `unverified` |

真实 idle 的 `scales` offset 为 `[0,1]`，若误按位置索引消费会错误绑定到
骨骼节点；因此转换器必须同时检查轨道名和 `offsets.semantics`，不能仅按整数范围判断。

真实样本的 offset 数量、离散通道数和压缩数据分别为：

| 轨道 | 动画 | offset 数 | `compresschannels` | 数据字数 | huffsize | huffcode |
|---|---:|---:|---:|---:|---:|---:|
| `bonerot` | idle | 42 | 168 | 2006 | 12 | 226 |
| `bonepos` | punch | 9 | 27 | 487 | 7 | 541 |
| `bonerot` | punch | 47 | 188 | 3268 | 10 | 1363 |
| `bonepos` | kick | 9 | 27 | 566 | 9 | 494 |
| `bonerot` | kick | 47 | 188 | 3914 | 11 | 1657 |

`compresschannels = offset_count × 3`（位置）或
`offset_count × 4`（旋转）。每个 16 字节 `huffsize` 项按四个 little-endian
`uint32` 读取为：

```text
left_aligned_prefix, bit_length, code_count, huffcode_start
```

已验证所有 `huffcode_start` 连续累加，`code_count` 之和等于
`huffcode` 元素数，生成的前缀彼此不构成前缀。位置轨道 huffcode 为 4 字节
符号，旋转轨道为 2 字节符号；符号的有符号解释仍未由原生读取函数确认。

压缩 `data` 首字分别为 idle 4、punch 3、kick 3，与
`numaproximations` 一致。后续字看起来是 approximation 边界，但在
`CWaveletDecoder<int,float>::UpdateToFrame` 和
`CWaveletDecoder<short,float>::UpdateToFrame` 的位流规则解出前，不把
整个 data section 假定为一条无边界 bitstream。

## 当前阻塞

- 当前 Skl 样本的 74 条名称指针已恢复；其他版本仍需独立验证名称表前边界与指针标记。
- `duration` 的单位、局部/世界坐标和四元数分量约定尚未确认。
- Wavelet 的表结构和通道数已恢复，但 approximation 边界、初始值、位序和逐通道状态重置规则仍未恢复。
- `.obj` 对外部网格、纹理和 shader 资源的引用解析尚未完成。

在坐标空间、四元数分量顺序和动画轨道语义得到验证之前，不把当前静态数组直接当作 Godot 变换，也不宣称模型已可导入。

## 当前工具

- `tools/kdf_data.py`：解析 CTX3 字符串表、DATA 计数、分组偏移、属性记录和数据区。
- `tools/kdf_animation.py`：提取已验证的 header、轨道组、采样对象、offset、Huffman 元数据和 raw-fixed Q12/Q14 值；wavelet 明确标为 `unresolved-wavelet`。默认只输出小预览，`--values` 才展开全部固定点样本和符号。
- `tools/kdf_skeleton.py`：按真实字段标记读取 `type → nodeid → parentid → treesize → offset`，通过相对指针表恢复节点名称，验证唯一根、父节点存在、无环和子树规模；关联每个 bone 的 `scales/bonepos/bonerot` 索引并读取静态变换候选。

这些工具只读取本机解码资源。Wavelet/Huffman 解码和坐标约定仍必须用完整原包继续验证。
