# Brick Davis 对手资源链

## 范围与状态

首个电脑对手目标选择 `BL_Brick_Davis_01_High`。本记录闭合静态资源路径、
SHA-256、角色 Object、骨架、身体 Mesh、纹理属性及四条 `m03_*` 动画与
Brick 骨架的引用关系，并在仓库外生成候选 GLB。候选 Brick 现已能作为电脑角色
的独立视觉接入 Godot 场景，但仍需区分视觉与规则：
其战斗 set、命中参数、AI、纹理运行时采样和原版视觉表现仍为 `UNVERIFIED`。

原始资源及候选 GLB 不进入仓库。安全元数据报告为
[`reports/brick_opponent_inventory.json`](../reports/brick_opponent_inventory.json)，
SHA-256 为
`cfeeb1ce7de6693aa27432971984ad36b68037ee9aeb294febb8626d91151720`。

## 已闭合资源

| 类型 | 路径/结果 | 证据 |
|---|---|---|
| 骨架 | `adreno_200/skeletons/BL_Brick_Davis_01_High.Skl` | 74 节点、70 bone、3 object |
| 角色 Object | `adreno_200/objects/BL_Brick_Davis_01_High.obj` | 76 场景节点、7 个外部引用（含前置空 sentinel） |
| 身体 Mesh | `.../meshes/bl_brick_davis_01_body_hw_kinetic.Mesh` | 2,495 顶点、3,657 三角形、3 subset、67 skin bone |
| 阴影 Mesh | `.../meshes/bl_brick_davis_01_body_hw_shadows.Mesh` | 708 顶点、1,027 三角形、1 subset |
| diffuse | `.../textures/19820ad048bfb97f17e3d9bd4118004252bf273f.tex` | 1024×1024、`atc_rgb` |
| normal | `.../textures/00b10ae060e9dc141268c2fc23f46a7e69403a5e.tex` | 1024×1024、`atc_rgb` |
| material | `.../textures/5c4dc7f7333f7fc62ae1229fbcdc0f58e877fb1d.tex` | 1024×1024、`r8g8b8a8` |

Object 的 `diffuse/normal/material` 引用与以上三条路径静态一致，身体 Mesh 和
阴影 Mesh 也由 Object 直接引用。Brick Object 的外部引用表有一个前置空
记录；其后运行时引用 ID 相对表内记录偏移一位。解析器保留该 sentinel 并将
引用映射到正确资源，Bruce Object 的无 sentinel 布局继续兼容。

四条动画的 `anmheader` 均引用
`skeletons/bl_brick_davis_01_high.skl`：

| 动画 | 帧数 | FPS |
|---|---:|---:|
| `m03_idle_01` | 120 | 30 |
| `m03_pnch_low_01` | 38 | 30 |
| `m03_kck_low_01` | 41 | 30 |
| `m03_movefwd` | 21 | 30 |

这四条动画现已按 Brick Davis 的 `adreno_200/set/thai.set` 映射到 `idle`、`lowpunch3`、`lowkick3` 和 `movefwd`。角色条目没有 `radiusscale`，缺省倍率是 `1.0`。动画半径是 `43/40/50/50`。`lowpunch3` 为 8/4/26、伤害 7、攻击半径 80，`larm/medium/hard/frontal`。`lowkick3` 为 9/3/29、伤害 7、攻击半径 70，`lleg/low/hard/fromright`。电脑不再把 Bruce 低段时序缩放到这些 clip 上。这只是当前四条 clip 的规则，不是完整 Thai set、AI 或 knockdown。同名动作的半径和返回帧以各自 set 为准。防守方使用自己的 reaction。Bruce 被这两招打中时使用 `impacthardfrontmid`、`impacthardrightlow` 和 `highblockhard`；对应 clip 以及 `facedownidle`、`idle2` 都还没有进入候选。硬击 clip 缺失时不会改播轻击正面反应。

## 本地候选导出

使用当前主分支的通用候选转换器：

```powershell
py -3.12 -X utf8 -B tools\character_to_gltf.py `
  'C:\private\...\bl_brick_davis_01_body_hw_kinetic.Mesh' `
  --skeleton 'C:\private\...\BL_Brick_Davis_01_High.Skl' `
  --include-object-transforms `
  --expected-skeleton-reference 'skeletons/bl_brick_davis_01_high.skl' `
  --expected-skeleton-sha256 '<local skeleton SHA-256>' `
  --animation 'C:\private\...\m03_idle_01.anm' `
  --animation 'C:\private\...\m03_pnch_low_01.anm' `
  --animation 'C:\private\...\m03_kck_low_01.anm' `
  --animation 'C:\private\...\m03_movefwd.anm' `
  --output 'C:\private\brick_candidate_idle_punch_kick.glb'
```

本机候选 GLB 为 324,572 字节，SHA-256 为
`23cf00b4a05a30b4b87929500bc039ce877caf7975b36918d562a446b3f6e076`。
转换器报告 69 根导出骨架 joint、2,495 顶点、3,657 三角形、3 subset 和 67
skin joint；静态姿态残余误差相对模型跨度约 `1.75e-6`。导出成功不证明原版
身体姿态或坐标空间已验收。

Godot 4.7.2 无界面候选验证结果：

```text
OPPONENT_CANDIDATE_VALIDATION={"animations":[{"length":4.0,"name":"m03_idle_01","tracks":65},{"length":1.26600003242493,"name":"m03_pnch_low_01","tracks":66},{"length":1.36600005626678,"name":"m03_kck_low_01","tracks":66},{"length":0.699999988079071,"name":"m03_movefwd","tracks":69}],"bones":69,"skinned_surfaces":3}
```

该验证加载一个 69 骨 Brick 模型、一个 3-surface skinned Mesh 和四条动画，
并确认每条动画在中点会改变骨架姿态。它不验证贴图最终像素、动画方向、原版
动作选择、碰撞、命中、AI 或游戏内可见效果。

## 复现与检查

```powershell
py -3.12 -X utf8 -B tools\opponent_resource_inventory.py `
  'D:\private\Bruce Lee Dragon Warrior v1.15.26.zip' `
  --report reports\brick_opponent_inventory.json

& $GodotExe --headless --path godot `
  --script res://tests/validate_opponent_candidate.gd -- `
  'C:\private\brick_candidate_idle_punch_kick.glb'

.\validate_candidate.ps1 -CandidateGlb 'C:\private\bruce_candidate.glb' `
  -OpponentGlb 'C:\private\brick_candidate_idle_punch_kick.glb' `
  -TextureRoot 'C:\private\bruce-textures' `
  -OpponentTextureRoot 'C:\private\brick-textures' `
  -GodotExe 'C:\Tools\Godot.exe'
```

报告生成器只读取原包，输出路径哈希和结构元数据，不导出原始字节。实际纹理
正文未包含在报告中。双角色资源选择已从 `is_player` 解耦：玩家和电脑分别
保存 GLB、纹理根目录、动作映射和候选动画节点。设置
`BRUCELEE_OPPONENT_GLB` 后可同时加载 Brick；未设置时电脑回退到占位体。
当前仓库外候选 GLB 没有解码后的 Brick PNG，因此实际运行报告
`opponent_textures_loaded=false`。材质加载器已支持 Brick 的单身体纹理组；
只有在三个 `body_*` PNG 全部存在并通过测试后，才可把运行时纹理标为已加载。
对手低段攻击已经使用上面的 `thai.set` 帧数、伤害和半径。视觉接入仍然不代表完整 Thai set、AI、knockdown 或原版逐帧画面已经恢复。
