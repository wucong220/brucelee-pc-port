# Hair/Body 材质纹理绑定取证（2026-10-29）

本记录只保存资源哈希、引用 ID、名称和函数地址，不包含原版纹理、网格、着色器源码或解码后的二进制载荷。

## 结论

`STATIC_VERIFIED`：

- `Character.shd` 引用的 `Diffuse.program` 声明了三个纹理常量：
  `diffuse`、`normal`、`material`。
- `bl_brucelee_01_High.obj` 的 Hair 主蒙皮网格依次绑定引用 ID `2/3/4`
  到 `diffuse/normal/material`；Body 主蒙皮网格依次绑定 `8/9/10`。
- 程序内嵌的片段着色器源码分别采样 `g_sDiffuse`、`g_sNormal` 和
  `g_sMaterial`；材质采样值 `r` 用作高光强度，`a` 用作光泽输入。
- 原生 `krm::gfx::CMaterial::Init` 对哈希字符串属性执行外部资源解析，
  调用 `CManager::GetTexture`，并把返回的纹理引用写入属性表。

这闭合了“OBJ 属性名 → 外部纹理资源 → 程序纹理常量 → 材质属性表”的静态链路。它不等于原版运行时已经实际加载成功，也不等于 Adreno 光照、混合、mip 和最终像素已经对齐。

## 输入指纹

| 项目 | 值 |
|---|---:|
| ELF SHA-256 | `1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70` |
| Object SHA-256 | `d97f09cb4b4f5c05fd3ddd0f3fa73d8d03440f113baa598ecc5891599e3e2a65` |
| Program SHA-256 | `124523adf6639e65f02e925a8f507b4911005639efabf5a8b1be1e9002bd6908` |
| Shader SHA-256 | `dcfc1433ee5bfdb9dc810001666adbb902fd03cdbfbd031fc36f6a6a69b5a90b` |

`Diffuse.program` 的 26 个字符串均满足当前观察到的
`CRC32 + byte_length` 标识规则。其 DATA 头为 81 条记录、3 个偏移、
profile word `15`、44 字节 payload；着色器源码位于其后，工具只报告存在状态，不返回源码。

## 程序纹理常量

| 记录序号 | 属性名 |
|---:|---|
| 19 | `diffuse` |
| 21 | `normal` |
| 23 | `material` |

工具从内嵌源码中的 `uniform sampler2D g_s…` 声明取得属性名提示，再要求字符串表和
`(string_ordinal, 0x40000004)` 常量记录各自唯一。当前三条记录的第二字均为
`0x40000004`，第一字分别为 `diffuse/normal/material` 的字符串序号。
未知 profile word、缺失或重复的采样器/名称/记录会失败关闭。

## Object 外部资源映射

| 部件 | 属性 | 引用 ID | 资源 |
|---|---:|---:|---|
| Hair | `diffuse` | 2 | `64185f0f4548bb1fa3a1ebc12b320f106f085b34.tex` |
| Hair | `normal` | 3 | `fca1fb7b78bbd0c27c67bafeafa0aba16284b52d.tex` |
| Hair | `material` | 4 | `63641d8746445ad3ded8a3b271e9862bcba325fa.tex` |
| Body | `diffuse` | 8 | `53240d6f00f3e53b33ded2b75bcfe74324761382.tex` |
| Body | `normal` | 9 | `826f86b41751ab6f8e92c1c0faa6b732672a082f.tex` |
| Body | `material` | 10 | `fb505d6373c4e948bcba183368bf14c8e6356aed.tex` |

Hair 主网格引用 ID 为 `0`，Body 主网格引用 ID 为 `7`。阴影网格不在这六个纹理属性组中。

## 原生数据流

`krm::gfx::CMaterial::Init` 位于 ELF 偏移 `0x34b000`，大小为 `0xefc`。

1. `0x34b02c–0x34b044` 从 `CShader+0x28` 克隆属性表。
2. `0x34b1d8–0x34b1f0` 以 16 字节步长遍历资源段，匹配属性键标签
   `0x60000000`。
3. `0x34b254–0x34b278` 找到紧随的 `0xA0000000` 值段并构造
   `CResLock`。
4. `0x34b2f8–0x34b30c` 选择哈希字符串属性处理分支。
5. `0x34b50c–0x34b784` 从文件名或 `0x70000000` 引用段取得
   path/basename/extension，并构造 `CResFileId`。
6. `0x34b9b0–0x34b9c0` 调用 `CManager::GetTexture`，并检查返回引用。
7. `0x34ba48–0x34ba74` 增加纹理引用计数并写入当前属性表槽。

这是基于当前 ELF 的正常控制流静态结论。异常分支、资源缺失回退和运行时实际返回值仍需单独验证。

## 复现

以下输入必须位于仓库外：

```powershell
py -3.12 tools\kdf_program.py 'C:\private\Diffuse.program'
py -3.12 tools\material_binding_report.py `
  'C:\private\bl_brucelee_01_High.obj' `
  'C:\private\Diffuse.program' `
  --output reports\material_texture_binding.json
```

仓库内报告只包含哈希、引用 ID、路径名称和证据边界。

## 未验证

- 未在原版 Adreno 设备上捕获 `GetTexture` 返回值和属性表最终内容。
- 未逐像素比较法线空间、sRGB 解码、mip 采样、混合和光照。
- `material.r/a` 到 Godot `SPECULAR/ROUGHNESS` 的映射是候选重建。
- 静态成功不代表所有路径、平台变体或缺失资源回退均成功。
