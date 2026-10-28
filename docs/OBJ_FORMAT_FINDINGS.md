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

该 `.obj` 中不存在 `vertices`、`indices`、`Bones` 或 `Weights` 数值数组。网格本体位于引用 ID `0、5、6、7` 对应的四个外部 `.mesh` 资源；场景树递归、子对象指针语义和材质到网格子集的最终绑定仍未验证。

## 当前工具

`tools/kdf_object.py` 只读解码后的对象资源，解析并校验：

- `0x10` 外部引用数量、`3 × count` 引用表和 `0x70000000` 使用点；
- 78 组 PRS section 引用、浮点有限性与四元数模长；
- 所有 `DATA` section 是否都被 PRS 数组消费；
- 输出保留 `scene_tree_status=unresolved`、`mesh_payload_status=external-resource` 和未验证坐标边界。

下一步应定位四个 `.mesh` 资源，恢复 positions、normals、textures/UV、indices、Bones、Weights 和 subsets。
