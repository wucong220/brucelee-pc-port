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

实际角色对象的记录 0 是 `0x30000000` 相对字典，根键只有 `scene`。`childs` 的值也是这种字典，键名就是子节点名。这与招式记录使用的相对字典编码一致，但这里只证明资源记录布局，不证明 `CHierarchyNode` 的运行时父指针。

该文件得到 78 个唯一节点，深度最大 13。类型为 `frame` 75 个、`object` 3 个。每个节点都有一组 `position/rotation/scale`，其 section 集合与上面 78 组姿态完全相同，但树的前序不等于 section 文件顺序。

直接子节点是 `male_01`、`male_01 l clavicle dummy` 和 `male_01 r clavicle dummy`。`male_01` 的 visuals 指向 Body 阴影网格和 Body 主蒙皮网格。Hair 主网格与 Hair 阴影网格分别是深度 9 的 object 节点。`visuals` 下的 `mesh` 值是 `0x70000000` 外部引用，basename 必须与 visual 名一致：Hair 主网格为引用 0，Hair 阴影为引用 5，Body 阴影和 Body 主网格为引用 6 和 7。

下一步应继续恢复原生父子指针和最终运行时 draw call 绑定。
