# Bruce Lee `.obj` 场景对象取证（2026-10-28）

本记录只保存哈希、偏移、记录结构和资源名称元数据，不包含原版网格、骨骼权重、纹理或二进制样本。

## 已定位资源

| 项目 | 值 |
|---|---:|
| PAKH 路径 | `adreno_200/objects/bl_brucelee_01_High.obj` |
| 索引 | 1097 |
| PAKD 偏移 | 15,363,195 |
| 解码长度 | 15,481 |
| SHA-256 | `d97f09cb4b4f5c05fd3ddd0f3fa73d8d03440f113baa598ecc5891599e3e2a65` |

该文件是 CTX3 场景对象描述，不是 Wavefront OBJ。其 `DATA` 参数为 `M=1115`、`N=234`、`L=3120`，完整边界与共享解析器一致。

## 外部资源引用表

字符串表结束到 `DATA` 之间有 33 字节，等于 `11 × 3`。每组由三个单字节字符串序号组成：

```text
uint8 path_string_index
uint8 basename_string_index
uint8 extension_string_index
```

实际得到 11 条引用，包括四个外部 `.mesh`、一个 `.shd` 和六个哈希式 `.tex`：

| 引用 ID | 路径 |
|---:|---|
| 0 | `objects/hw/bl_brucelee_01_high/meshes/bl_brucelee_01_hair_hw_skhigh.mesh` |
| 1 | `shaders/character.shd` |
| 2–4 | 三条 `.tex` 引用 |
| 5 | `objects/hw/bl_brucelee_01_high/meshes/bl_brucelee_01_hair_hw_shadows.mesh` |
| 6 | `objects/hw/bl_brucelee_01_high/meshes/bl_brucelee_01_body_hw_shadows.mesh` |
| 7 | `objects/hw/bl_brucelee_01_high/meshes/bl_brucelee_01_body_hw_skhigh.mesh` |
| 8–10 | 三条 `.tex` 引用 |

属性值标签 `0x70000000` 指向引用 ID；全文件共 20 次使用，去重后密集覆盖 `0..10`。`mesh`、`shadertype`、`diffuse` 和 `normal` 等键通过该标签连接实际资源。

## DATA 载荷

234 个 section 全部由 78 组 `position → rotation → scale` 变换使用：

```text
(position_key, 1 × float32[3])
(rotation_key, 1 × float32[4])
(scale_key,    1 × float32[3])
```

156 个 section 为 12 字节、78 个 section 为 16 字节，总量正好 3,120 字节。78 个旋转值均为有限数，四元数模长相对 1 的最大误差约 `1.15e-7`。坐标空间和四元数分量顺序仍未确认。

该 `.obj` 中不存在 `vertices`、`indices`、`Bones` 或 `Weights` 数值数组。网格本体位于引用 ID `0、5、6、7` 对应的四个外部 `.mesh` 资源。材质到主网格 subset 的静态归属已经闭合；原生场景节点指针和最终 draw call 仍未验证。

## 当前工具

`tools/kdf_object.py` 只读解码后的对象资源，解析并校验：

- `0x10` 外部引用数量、`3 × count` 引用表和 `0x70000000` 使用点；
- 78 组 PRS section 引用、浮点有限性与四元数模长；
- 所有 `DATA` section 是否都被 PRS 数组消费；
- 当记录 0 是 `0x30000000` 相对字典时，解析 `scene/childs` 层级，并要求每个节点的 PRS section 与 78 组姿态一一对应；
- 输出保留 `mesh_payload_status=external-resource` 和未验证坐标边界。没有相对字典的样本保持 `scene_tree_status=unresolved`。

Hair/Body 主网格、subset 材质和六个纹理资源的静态绑定已经单独闭合，见
[`MATERIAL_TEXTURE_BINDING_FINDINGS.md`](MATERIAL_TEXTURE_BINDING_FINDINGS.md)。
该绑定只证明 OBJ 属性、Mesh subset 材质、程序常量和原生材质初始化数据流一致；
运行时纹理加载、draw call、Adreno 光照与最终像素仍未验证。

## 场景层级

实际角色对象的记录 0 是 `0x30000000` 相对字典，根键只有 `scene`。`childs` 的值也是这种字典，键名就是子节点名。这与招式记录使用的相对字典编码一致。它证明资源里的子节点名单，本身还不证明这些名字已经写入原生节点指针。

该文件得到 78 个唯一节点，深度最大 13。类型为 `frame` 75 个、`object` 3 个。每个节点都有一组 `position/rotation/scale`，其 section 集合与上面 78 组姿态完全相同，但树的前序不等于 section 文件顺序。

直接子节点是 `male_01`、`male_01 l clavicle dummy` 和 `male_01 r clavicle dummy`。`male_01` 的 visuals 指向 Body 阴影网格和 Body 主蒙皮网格。Hair 主网格与 Hair 阴影网格分别是深度 9 的 object 节点。`visuals` 下的 `mesh` 值是 `0x70000000` 外部引用，basename 必须与 visual 名一致：Hair 主网格为引用 0，Hair 阴影为引用 5，Body 阴影和 Body 主网格为引用 6 和 7。

## 原生 Link 字段

同一份 `libdefault.so`（SHA-256 `1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70`）里，`CHierarchyNode` 构造函数 `0x3C0E2C`、`Link` `0x3C15C4` 和 `UnLink` `0x3C1D78` 使用同一组字段：

| 偏移 | 构造时 | `Link` | `UnLink` |
|---:|---|---|---|
| `+0xB4` | 0 | 保存父节点 | 作为父节点读取后清零 |
| `+0xB8` | 0 | 原最后一个子节点为空时保存新子节点 | 前驱为空时改成后继 |
| `+0xBC` | 0 | 总是改成新子节点 | 后继为空时改成前驱 |
| `+0xC0` | 0 | 旧尾的后继改为新节点，新节点后继为 0 | 与前驱互相摘链 |
| `+0xC4` | 0 | 新节点前驱改为旧尾 | 与后继互相摘链 |
| `+0xC8` | 构造参数中的 hierarchy root | 一条路径把父节点的值复制给子节点 | 一条路径清零 |

这是双向兄弟链表：`+0xB4` 是父节点，`+0xB8/+0xBC` 是第一个和最后一个子节点，`+0xC0/+0xC4` 是后继和前驱。调用不直接跳到 `0x3C15C4`，而是通过 PLT `0x12B170`。

`CScnFrame::Init` 在 `0x35C2E4` 调用 `CreateChilds`。`CreateChilds` 先扫描资源里的 `0x60000000` 键，只有解析出的字符串对象等于 `krm::gfx::gid_Childs`（`.rel.dyn` `0x603548`）才继续。它随后用 `DictKey/DictVal` 遍历这个值。对每个条目先调用 `CWorld::CreateEntity`；返回空时，`0x35BF70` 调用 `CScnFrame::AddChild`，`AddChild` 在 `0x35B420` 调用 `Link`，然后递归调用 `CreateChilds`。

因此，资源 `childs` 键到帧节点 `Link` 的空返回回退链已经接上。`CreateEntity` 成功时还有另一条分发。

`CreateEntity` 在 `0x378210` 只接受键对象等于 `gid_Type`（`.rel.dyn` `0x604434`）的记录，再把类型值与六个全局对象比较：

| 类型全局对象 | 重定位 | 调用 |
|---|---:|---|
| `gid_Object` | `0x6047B0` | `CreateObject` → `CScnObj::Init` |
| `gid_Camera` | `0x6030B8` | `CreateCamera` → `CScnCam::Init` |
| `gid_Light` | `0x6035C0` | `CreateLight` → `CScnLight::Init` |
| `gid_Group` | `0x603908` | `CreateGroup` → `CScnGrp::Init` |
| `gid_Reflector` | `0x6025A4` | `CreateReflector` → `CScnReflector::Init` |
| `gid_Primitive` | `0x602D60` | `CreateDummy` → `CScnDummy::Init` |

这六个 `Init` 都有直接调用 `Link` 的指令，地址分别是 `0x36A580`、`0x350C50`、`0x363E24`、`0x35F20C`、`0x371098` 和 `0x355AC0`。对象路径在分配结果为空时不会进入 `Init`。另外，键对象等于 `gid_Animatable`（`0x604074`）时会提前调用同一个 `CreateObject` 并返回。类型不匹配则返回空，回到上面的 `AddChild` 帧回退。

这些是静态调用点，不是 78 个资源节点的运行时逐个证明，也还没有 draw call 绑定。

可用下面的命令复核指令字和九个全局重定位，不把原 SO 写入仓库：

```powershell
py -3.12 tools\native_hierarchy_links.py "$env:LOCALAPPDATA\BruceLee-PC-Port\binaries\libdefault.so"
```

## 场景对象绘制路径

`CScnObj::Commit` 在两处调用 `CRenderTargetBase::Commit`（`0x36E1FC`、`0x36E480`）。该 `Commit` 创建 `CRenderPrimitive` 并加入 `CGeometryBatcher`，不是立即调用 OpenGL。

批处理提交由 `CRenderTargetBase::EndBlock` 在 `0x307598` 调用 `CGeometryBatcher::Commit`。后者在 `0x32D6FC` 绑定 primitive，并在 `0x32D710`、`0x32D774` 调用 `_DrawBatch`。`_DrawBatch` 在 `0x32D348`、`0x32D46C`、`0x32D534`、`0x32D580` 调用 `CRenderPrimitive::Draw`，再进入 `CVariation::Draw`。

`CProgram::Draw` 在 `0x3162EC`、`0x316758` 调用 `glDrawElements`，在 `0x316848` 调用 `glDrawArrays`。对应 PLT 是 `0x1275D0`、`0x128824`，重定位目标分别是 `glDrawElements` 和 `glDrawArrays`。

这闭合了场景对象到 OpenGL 绘制入口的静态路径。它没有证明某个具体对象实际提交了几次 draw call，也没有证明材质状态或最终 GPU 像素。

可用下面的命令复核绘制路径指令，不把原 SO 写入仓库：

```powershell
py -3.12 tools\native_draw_path.py "$env:LOCALAPPDATA\BruceLee-PC-Port\binaries\libdefault.so"
```

## 视觉项与 subset 提交粒度

`CScnObj::Commit` 的外层按 `0x30` 字节遍历视觉项（`0x36E260`、`0x36E4E4`），内层读取当前视觉项的 `+0x14` 数量与 `+0x18` 数组，在 `0x36E1D8`、`0x36E45C` 逐个取出 subset 索引。每次索引通过 `CRenderTargetBase::Commit` 加入批处理，所以静态提交单位是“视觉项 × 通过 pass 过滤的 subset”。

pass 过滤位于 `0x36E1B0`、`0x36E434`：取视觉项 `+0x20` 指向的 `CShaderInstance` 的 `+0x50` 位图，并测试 `1 << pass`。位未置位时不提交该视觉项。两个结构相同的循环分别覆盖两条提交分支。

`CShaderInstance::Init` 在 `0x2FD124` 把 `+0x50` 清零。`CShaderInstance::_Update` 在 `0x2FC5D4` 再次清零，随后循环 32 个 variation 槽位，在 `0x2FC6FC` 调用 `CShader::GetVariation`；有效槽位通过 `0x2FC72C` 的 `1 << slot` 置位，并在 `0x2FC730` 写回 `+0x50`。

`CVisual::Update` 在 `0x37297C`、`0x3729C0` 读取各实例的 `+0x50`，在 `0x372984`、`0x3729C4` 与视觉对象的累计值 OR，并在 `0x372988`、`0x3729C8` 写回 `+0x24`。因此 `CShaderInstance+0x50` 是具体 variation 位图，`CVisual+0x24` 是该视觉对象所有实例位图的并集；`CScnObj::Commit` 仍按单个实例位图决定是否提交。

按已解析的资源和 mesh 数据，`male_01` 的 Body 阴影视觉项有 1 个 subset、Body 主蒙皮视觉项有 3 个 subset；如果两个视觉项都通过同一 pass，最多形成 4 个 primitive 提交。Hair 主网格和 Hair 阴影各为独立 object 视觉项，各有 1 个 subset，分别最多形成 1 个 primitive 提交。

这些是 primitive 入批上限，不是最终 `glDrawElements/glDrawArrays` 次数。批处理器可以合并或拆分，实际次数还取决于 pass 位、运行时视觉状态和批处理键。

可用下面的命令复核 subset 循环指令，不把原 SO 写入仓库：

```powershell
py -3.12 tools\native_visual_commits.py "$env:LOCALAPPDATA\BruceLee-PC-Port\binaries\libdefault.so"
```

可用下面的命令复核 pass 位构造与过滤，不把原 SO 写入仓库：

```powershell
py -3.12 tools\native_pass_mask.py "$env:LOCALAPPDATA\BruceLee-PC-Port\binaries\libdefault.so"
```

## 批处理三元键

`CGeometryBatcher::Add` 在 `0x32CDD0` 把调用参数 `j` 写到批次记录 `+0`，并把 `TBatchID` 的两个 32 位字段写到记录 `+4/+8`。`CGeometryBatcher::Commit` 在 `0x32D6D4/0x32D6E4` 比较相邻记录的 `+0`，在 `0x32D7D0–0x32D7E8` 比较 `+4/+8`，只有三个字段都相同才把记录归入同一个 `_DrawBatch` 组。

组开始前 `0x32D6FC` 只调用一次 `CRenderPrimitive::Bind`，组内的 `_DrawBatch` 调用可复用该绑定状态。字段的业务语义尚未从调用方全部确认，因此这里把它们记为三元键 `(j, TBatchID[0], TBatchID[1])`，不擅自命名为材质、纹理或 shader。

`CShaderInstance` 的两个构造函数 `0x2FC888`、`0x2FC9E8` 都在 `0x2FC944/0x2FCAA4` 取 `+0xD4` 起始地址，并在 `0x2FC95C/0x2FCABC` 用 `MemorySet` 把 0x80 字节填成 `0xFF`。但 `_Update` 的循环在 `0x2FC6DC–0x2FC6E8` 对 `+0xD4` 以 8 字节步长执行 32 次写入（`0x2FC6A4`），所以只能确认“构造时初始化了 0x80 字节”，不能确认完整表只有 16 个槽位。完整表边界、后半部分初始化和业务语义仍未闭合；它不是 `CRenderTargetBase` 的字段。

`CRenderTargetBase::Commit` 的 TBatchID 来源在 `0x3070B8–0x307184`：`r4` 先保存参数中的 `CShaderInstance` 指针，`r5` 保存 `CRenderTargetBase`。读取 `CRenderTargetBase+0xCC` 的当前 render-target 槽位，再以 8 字节 stride 访问 `CShaderInstance+0xD4` 表，复制两个字到传给 `CGeometryBatcher::Add` 的临时 TBatchID。`j` 来自 `Commit` 的最后一个参数 `0x307174` 和 `0x307190`。这是 shader-instance per-target 表到批处理键的来源链，不代表两个键字分别等于材质或纹理。

可用下面的命令复核三元键比较指令，不把原 SO 写入仓库：

```powershell
py -3.12 tools\native_batch_key.py "$env:LOCALAPPDATA\BruceLee-PC-Port\binaries\libdefault.so"
```

可用下面的命令复核 TBatchID 来源，不把原 SO 写入仓库：

```powershell
py -3.12 tools\native_batch_id_source.py "$env:LOCALAPPDATA\BruceLee-PC-Port\binaries\libdefault.so"
```

下一步应继续追踪 `CShaderInstance+0xD4` 两个字段的设置位置，并关联材质/纹理状态。
