# 原生骨骼与动画符号证据（2026-10-28）

本记录只保存 ELF 符号、函数地址和短字符串元数据，不包含原版代码、模型、动画二进制或可分发资源。分析对象是本机从用户提供的电脑版安装包中提取的 `lib/armeabi/libdefault.so`，SHA-256 为 `1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70`。

## ELF 函数入口

下表中的地址是 ELF32 符号值，不是进程加载后的绝对地址；同一 `libdefault.so` 中保留了 `.symtab`、大小和函数名。

| 函数 | 符号值 | 大小 | 已证明内容 |
|---|---:|---:|---|
| `krm::CAnimationDescr::ParseFromKDF(...)` | `0x0022d6d0` | 26840 | 高层动画描述从 KDF 解析的入口 |
| `krm::CAnimationDescr::GetDuration()` | `0x002277ac` | 96 | 动画具有可按描述读取的时长 |
| `krm::anm::CAnimRes::InitFromRes(...)` | `0x00409838` | 2052 | 底层动画资源初始化入口 |
| `krm::anm::CAnimRes::Parse(...)` | `0x00416468` | 940 | 动画资源解析入口 |
| `krm::anm::CAnimRes::UpdateProperties(...)` | `0x00416814` | 1932 | 动画属性表更新入口 |
| `krm::anm::CAnimRes::RegisterHeader(...)` | `0x00417348` | 1720 | 动画 header 注册入口 |
| `krm::anm::CAnimRes::CheckAnimation() const` | `0x00416fa0` | 936 | 动画完整性检查入口 |
| `krm::anmPlayer::SetAnimation(...)` | `0x003f99b0` | 92 | 简化边界入口；完整设置入口在 `0x003f9834` |
| `krm::anmRoot::Update(int)` | `0x00406dbc` | 304 | 动画根更新入口 |
| `krm::anmState::GetNumSamples() const` | `0x003faae4` | 172 | 动画状态公开样本数 |
| `krm::anmState::GetDuration() const` | `0x003fab90` | 164 | 动画状态公开时长 |
| `krm::anmState::SetSpeed(float)` | `0x003faef4` | 308 | 动画速度由独立状态控制 |

## 可读属性与结构名称

| ELF 文件偏移 | 字符串 | 证据含义 |
|---:|---|---|
| `0x005ba970` | `skeleton` | 资源/战斗描述中的骨骼键名 |
| `0x005ba9c8` | `animations` | 动画集合键名 |
| `0x005bb1d0` | `duration` | 时长键名 |
| `0x005bb1e4` | `sample` | 样本键名 |
| `0x005bb6f8` | `animation` | 动画键名 |
| `0x005bdde0` | `frame` | 帧键名 |
| `0x005bde08` | `bone` | 骨骼键名 |
| `0x005bde34` | `my_skeleton` | 角色自身骨骼引用键名 |
| `0x005bde40` | `opp_skeleton` | 对手骨骼引用键名 |
| `0x005bf5c4` | `num_bones` | 骨骼数量键名 |
| `0x005bf5d0` | `array_bone_id` | 骨骼标识数组键名 |
| `0x005bf604` | `num_bones_per_branch` | 骨骼分支数据键名 |
| `0x005c0ca8` | `Bones` | 网格骨骼数据键名 |
| `0x005c0cb0` | `Weights` | 蒙皮权重键名 |
| `0x005c0cd4` | `Skl` | 骨骼资源键名 |
| `0x005c0ef8` | `Weight` | 单权重字段名 |
| `0x005c0f00` | `Bone` | 单骨骼字段名 |
| `0x005c0f60` | `Samplers` | 采样器集合名称 |
| `0x005c1174` | `Frame` | 帧字段名称 |
| `0x005cd338` | `BonePos` | 骨骼位置动画属性名 |
| `0x005cd34c` | `BoneRot` | 骨骼旋转动画属性名 |
| `0x005cdc74` | `Malformed animation header` | 动画文件具有显式 header 校验 |
| `0x005ce058` | `Sample` | 动画 header 字段 |
| `0x005ce060` | `Num Samples` | 动画 header 字段 |
| `0x005ce06c` | `Speed` | 动画 header 字段 |
| `0x005ce074` | `Loop` | 动画 header 字段 |
| `0x005ce07c` | `Smooth` | 动画 header 字段 |
| `0x005d1d20` | `RawFloatSample` | 样本编码候选：原始浮点 |
| `0x005d1d30` | `RawFixedSample` | 样本编码候选：原始定点 |
| `0x005d1d40` | `WaveletSample` | 样本编码候选：小波 |
| `0x005d1e30` | `Pose` | 姿态数据键名 |

着色器字符串还明确出现 `g_vBones`、`g_vWeights`、`g_mSkinPal` 以及每顶点四个骨骼索引和四个权重。这证明模型蒙皮路径存在，但不能据此推断具体 `.obj` 文件的字节布局。

## 边界

- 这些是符号、函数入口和格式键名，不是已反编译成功的算法。
- 目前不知道三个 `m01_*.anm` 分别使用 `RawFloatSample`、`RawFixedSample` 还是 `WaveletSample`。
- 目前不知道 `anmBoneHeader`、采样表、时间步长和层级节点在 KDF DATA 段中的精确尺寸与顺序。
- 尚未证明 `.Skl`、`.anm` 与 `bl_brucelee_01_High.obj` 能绑定并导入 Blender/Godot。
- 下一步必须把上述入口与已定位真实资源的前向偏移、长度、字符串表和数值变化交叉验证后，才能实现转换器。
