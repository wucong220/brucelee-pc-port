# Bruce Lee `.mesh` 几何取证（2026-10-29）

本记录只保存哈希、计数、记录布局和少量验证值，不包含原版网格、权重或纹理二进制。

## 四个外部 Mesh

Object 文件通过引用 ID `0、5、6、7` 指向四个外部 `.mesh`：

| Object ID | 资源 | 解码字节 | SHA-256 |
|---:|---|---:|---|
| 0 | hair skinned | 6,690 | `8c03d12b23935081895b5eeef6c0ec3c035450fb6d717767bcccc7a5ecaaa061` |
| 5 | hair shadows | 2,672 | `66eb32128652caa1a8520ab3adc40d18a2d62bf94474768277edf03beccf31cb` |
| 6 | body shadows | 39,196 | `9710fa9547973b3ae63487a21c8bf99708979ef4a5b259c75e3c0a6e57c3717e` |
| 7 | body skinned | 133,606 | `0860e38296521c9be073d58daf772eda4538bcc8a8eea57dc334153f2ce7f86f` |

四份资源均使用当前已验证的 CTX3 DATA 布局。`indices` 是 `uint16` 元素，`vertices` 的 stride 由 `vertexformat` 决定。

## 顶点布局

| `vertexformat` | Stride | 已验证字段 |
|---|---:|---|
| `0x42` | 20 | `position: float32[3]` + `uv: float32[2]` |
| `0x342` | 40 | position + UV + 4 × `uint8` 局部骨骼索引 + 4 × `float32` 权重 |

两个 body 网格的四权重均非负、总和为 1，实测权重和最大误差为 0。两个 hair 网格只包含位置和 UV。

网格计数如下：

| 资源 | 顶点 | 索引 | 三角形 | Subsets | 骨骼 |
|---|---:|---:|---:|---:|---:|
| hair skinned | 213 | 843 | 281 | 1 | 0 |
| hair shadows | 70 | 264 | 88 | 1 | 0 |
| body shadows | 664 | 2,724 | 908 | 1 | 30 |
| body skinned | 2,448 | 10,080 | 3,360 | 3 | 67 |

body skinned 有 1 个退化三角形，其余网格没有退化三角形；所有索引都小于对应顶点数。

## Subsets

每个 subset 的 `rangeidx` 和 `rangevtx` 都是两个 `uint32` 的区间 `[start,end)`。body skinned 的三个 subset 连续覆盖完整网格：

| Subset | 索引范围 | 顶点范围 | 局部骨骼映射 |
|---:|---|---|---:|
| 0 | `0–6141` | `0–1445` | 31 |
| 1 | `6141–8505` | `1445–2075` | 31 |
| 2 | `8505–10080` | `2075–2448` | 18 |

`skl` 的单字节数组把顶点内局部骨骼索引映射为全局骨骼索引。body shadows 没有 subset 局部映射，其顶点骨骼索引直接指全局骨骼。所有映射后的索引都落在对应 skeleton 范围内。

## Mesh 内置绑定骨架

两个 body 网格包含独立于 `.Skl` 动画骨架的绑定数据：

- body skinned：67 个骨骼名、67 × `float32[3]` 位置、67 × `float32[4]` 四元数、67 × 12 个 `float32` 矩阵。
- body shadows：30 个骨骼名和相同维度的位置、四元数、矩阵数组。

四元数模长与 1 的最大误差约 `7.24e-8`。使用 `(x,y,z,w)` 构造正向旋转矩阵 `R` 后，12 浮点矩阵前三列与 `Rᵀ` 逐项匹配，最大误差约 `1.03e-7`。矩阵按三行存储，每行前三个数是逆旋转行，第四个数是该行平移分量：

```text
[Rt_row0, tx, Rt_row1, ty, Rt_row2, tz]
```

`Rt · position + translation` 在 97 个 mesh 骨骼上的最大残差约 `1.15e-5`，因此将其标记为逆绑定矩阵候选。原生加载器是否另有坐标变换仍待确认。

顶点在 `X-Z` 平面投影得到直立人物轮廓，在 `Y-Z` 平面投影得到正常侧面轮廓；因此当前几何轴可确认是 `X` 横向、`Y` 纵深、`Z` 向上。转换到 Godot 的 Y-up 坐标时仍需确认前向轴、手性和符号选择。

## 当前工具

`tools/kdf_mesh.py` 只读解码后的 Mesh 资源，默认输出：

- 顶点数、索引数、三角形数、退化三角形数、位置边界；
- `vertexformat`、stride、权重和误差；
- subset 区间、材质及 local→global 骨骼映射；
- mesh 内置 skeleton；
- 前三个顶点预览和所有未验证坐标边界。

`--vertices` 和 `--indices` 仅在明确需要时输出完整数组。下一步是把已验证的位置、UV、索引、权重和骨骼映射转换为仓库外的 glTF/OBJ 中间文件，并核对坐标轴与矩阵布局。

`tools/mesh_to_obj.py` 提供受限 OBJ 中间导出，仅写位置、UV、subset 和三角面；它强制输出到仓库外且非明显同步目录，并在结果中明确 `skin_data_included=false`。OBJ 不保存四权重、绑定矩阵或动画，因此不会替代后续 glTF/Godot 蒙皮转换。

`tools/character_to_gltf.py` 在给定独立 `.Skl` 时可生成仓库外的静态 GLB：按骨骼名称建立 Mesh skeleton 到 Skl 层级的两阶段映射，写入 Skl 局部 TRS、Mesh 逆绑定矩阵、四权重和 subset primitives。场景根节点把原版 Z-up 转到 glTF Y-up，但不包含动画，因此只用于蒙皮静态姿态和 Godot/glTF 导入验证。

当前导出器实际生成的 body GLB 为 143,264 字节，SHA-256 为 `4743298aa10b6e19a34d9d5897e45e6eebc45e2f4781e1a328c5fde2b9b40718`。文件包含 76 个节点、67 个 skin joints、3 个 subset primitive。Mesh 与 Skl 静态姿态对照的最大位置误差为 `0.000605`、最大旋转矩阵误差为 `0.000422`。该静态几何已在内置浏览器的标准 glTF 查看器中完整显示，面部、手指、衣物和双脚均正常；原始矩阵版本与独立 CPU 蒙皮尚需在 Godot 实机中复验。

独立验收还计算了完整的 `Skl 全局矩阵 × Mesh 逆绑定矩阵`。67 个 joint 的最大旋转误差仍为 `0.000422`，最大平移误差为 `0.068762`；后者是前述微小旋转差乘上约 160 个单位的头部坐标后的结果。以网格最大边长 `166.336` 归一化后为 `0.000413`，最差 joint 为 `r eyelid down`。对全部 2,448 个顶点和四权重做静态线性蒙皮后，最大实际顶点位移约为 `0.004025` 个源单位。导出器直接保留原版 Mesh 的 67 个 12-float 逆绑定矩阵，不再用四元数和平移二次重建，也不拿 Skl 静态姿态反算矩阵覆盖原数据；因此不能把该检查描述为所有 joint 都严格等于单位矩阵。完整指标现在随 `rest_pose_validation` 的 `skin_matrix_*`、`skin_vertex_*` 和 `relative_to_model_span` 字段输出。
