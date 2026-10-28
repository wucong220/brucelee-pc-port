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

## 当前阻塞

- 数值骨架层级扫描器已能恢复 nodeid、parentid、treesize 和子树关系；节点名称引用的完整通用编码尚未实现。
- `duration` 的单位、局部/世界坐标和四元数分量约定尚未确认。
- `quantizedbits/radix`、Huffman 码表和压缩通道的编码尚未恢复。
- `.obj` 对外部网格、纹理和 shader 资源的引用解析尚未完成。

在获得可验证的骨骼父子层级和至少一组姿态变换之前，不编写 glTF/Godot 动画导出器，也不宣称模型已可导入。

## 当前工具

- `tools/kdf_data.py`：解析 CTX3 字符串表、DATA 计数、分组偏移、属性记录和数据区。
- `tools/kdf_animation.py`：提取已验证的 `firstframe/duration/framerate/version/pose` 和分组区间；不解码压缩通道。
- `tools/kdf_skeleton.py`：按 `type → nodeid → parentid → treesize → offset` 扫描 Skl 节点，验证唯一根、父节点存在、无环和子树规模。

这些工具只读取本机解码资源。Skl 名称引用和 Wavelet/Huffman 解码仍必须用完整原包继续验证。
