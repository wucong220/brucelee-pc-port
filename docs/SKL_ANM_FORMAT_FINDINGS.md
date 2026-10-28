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

## 当前阻塞

- `nodeid`、`parentid`、`treesize` 和 `offset` 在 DATA 属性序列表中的实际布局未知。
- `firstframe`、`duration`、`framerate` 的实际类型、单位和位置未知。
- 尚不知道三套动作具体使用 `RawFloatSample`、`RawFixedSample` 或 `WaveletSample`。
- `quantizedbits/radix`、Huffman 码表和压缩通道的编码尚未恢复。
- `.obj` 对外部网格、纹理和 shader 资源的引用解析尚未完成。

在获得可验证的骨骼父子层级和至少一组姿态变换之前，不编写 glTF/Godot 动画导出器，也不宣称模型已可导入。
