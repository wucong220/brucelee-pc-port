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

这四条动画现已按 Brick Davis 的 `adreno_200/set/thai.set` 映射到 `idle`、`lowpunch3`、`lowkick3` 和 `movefwd`。角色条目没有 `radiusscale`，缺省倍率是 `1.0`。动画半径是 `43/40/50/50`。`lowpunch3` 为 8/4/26、伤害 7、攻击半径 80，`larm/medium/hard/frontal`。`lowkick3` 为 9/3/29、伤害 7、攻击半径 70，`lleg/low/hard/fromright`。电脑不再把 Bruce 低段时序缩放到这些 clip 上。这只是当前四条 clip 的规则，不是完整 Thai set、AI 或 knockdown。同名动作的半径和返回帧以各自 set 为准。防守方使用自己的 reaction。Bruce 被这两招打中时使用 `impacthardfrontmid`、`impacthardrightlow` 和 `highblockhard`；对应三条 clip 可在仓库外的 12 段候选中播放。12 段文件仍不含 `facedownidle` 和 `idle2`；15 段 `bruce_candidate_return_states.glb` 只在轨道检查通过时进入这两个返回状态。硬击 clip 缺失时不会改播轻击正面反应。

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

## 正面低段硬受击与跨骨架候选（2026-10-30）

只读解析 `adreno_200/set/thai.set`（SHA-256
`1afe220f7ef590fb136334a5efab251bd30dc90474101f6135f5ab5afbcee586`，
PAKD offset `31343689`）：action 数组第 71 项 `impacthardfrontlow` 的 binary
直接引用 `animation/all_impct_hard_frnt_low.anm`，pose `laying`，radius 80。
link 143 的条件为 `impact`、`oppattackstrengthhard`、
`oppattackheightlow`、`oppattackdirfrontal`，来源组是 `impactable`；link 178
在 `[20,23]` 连到 `facedownidle`。link 63 在同一窗口以 `healthzero` 连到
`facedownko`；两个出口的原生优先级尚未在运行时验证。档案中的 link 不是
当前 Godot 正常对战已实现这些转换的证明。

目标 ANM 的 SHA-256 为
`c38c0b8c3445ec9f4f237c9a882ed960ce6c7b0e333dbdd9e127742d33ff1647`，
其 `anmheader` 引用 `skeletons/bl_brucelee_01_high.skl`。以 Bruce Skl
SHA-256 `4a6d4532b42d6cbee3016b849befc2dc98c089e72fa4cfe291d9550f059412e3`
和 Brick Skl SHA-256
`61fd6723c532499fb94071b0f3ba809feeab623995531ccf31eac00ac57db942`
做只读候选索引比较：61 条轨道中 60 条同索引指向相同名称和类型；
`bonerot` offset 28 在 Bruce 指向 `r eyeball`，在 Brick 指向
`l eyebrow 02`。因此直接用相同索引绑定会错绑该轨道。Brick 的 `r eyeball`
确实存在，旋转索引是 15；Bruce 的是 28。

进一步按节点名称只读比较，动画涉及的 50 个不同名称在两套骨架中均唯一，
并且完整父节点名称链一致。对应节点的静态 `position` 分量在阈值 `1e-5`
下有 48 个不同；`rotation_xyzw_unverified` 和 `scale` 分量无超过该阈值的
差异。这里比较的是解析器所报告的字段，不代表静态变换空间、绑定矩阵或
动画轨道应用语义已经验证。**名称和父链一致不证明重定向可播放或与原版一致**；
严格配对检查继续保留。后续候选入口及其验证范围见下节。

索引比较复现命令（实际执行退出码 0）：

```powershell
py -3.12 -X utf8 -B tools\compare_animation_bindings.py `
  "$env:LOCALAPPDATA\BruceLee-PC-Port\brick-frontlow-anm-20261030\adreno_200\animation\all_impct_hard_frnt_low.anm" `
  "$env:LOCALAPPDATA\BruceLee-PC-Port\validation-f0c9a3a-20261029\adreno_200\skeletons\bl_brucelee_01_High.Skl" `
  "$env:LOCALAPPDATA\BruceLee-PC-Port\brick-opponent-inventory-20261030\adreno_200\skeletons\BL_Brick_Davis_01_High.Skl"
```

50 节点比较由 `kdf_skeleton.inspect_file` 和 `kdf_animation_binding.bind_animation`
在内存中读取以上三个本机文件，按 `nodeid` 追踪 `parentid` 并按名称比较
`static_transforms` 与 `object_static_transforms`；执行退出码 0。此项结果暂未
封装为可复用命令，不能替代原生变换链或视觉对照。

Validation: `py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q` (201 tests, 1 skipped; exit 0).

## Brick 候选倒地入口

只读解析 `thai.set` 的动作数组，`idle`、`movefwd`、`lowpunch3`、
`lowkick3` 的 `impactable` 窗口分别为 `[0,120]`、`[0,21]`、`[0,38]`、
`[0,41]`，覆盖各自动画的完整档案时长。原型限定 Bruce 的 `faceupattack`
对这四种映射动作产生非致命、非格挡的 hard/low/frontal 命中时，若 Brick
反应与倒地 clip 均通过检查，播放候选 `impacthardfrontlow`，选择窗口
`[20,23]` 的第 20 帧进入 Brick 的 `facedownidle`。移动视觉使用 `movefwd`
候选片段，逻辑状态仍是 idle；攻击各阶段使用同一动作窗口。第 20 帧
是原型状态计时选择，与 GLB 采样时间的精确对应尚未经过原版对照。

反应和倒地 clip 缺失、无效时维持普通受击回退；格挡走 blockstun，
致命走当前 ko。Brick 倒地时不启用 Bruce 起身、倒地反击或倒地受击行为。
组链接 `TimeWindowCheck` 已对其他组做静态追踪，尚未单独核实该入口的完整
运行路径；跨骨架变换、原版优先级、真实位移及逐帧视觉均未验收。

2026-10-30，本机 Godot 4.7.2 headless 执行以下命令，均退出码 0：

```powershell
$godot = "$env:LOCALAPPDATA\BruceLee-PC-Port\godot-portable-773280yg\Godot_v4.7.2-stable_win64_console.exe"
$bruce = "$env:LOCALAPPDATA\BruceLee-PC-Port\attacktofloor-candidate-20261030\bruce_candidate_23.glb"
$brick = "$env:LOCALAPPDATA\BruceLee-PC-Port\brick-retarget-candidate-20261030\brick_candidate_6.glb"
& $godot --headless --path godot --editor --quit
& $godot --headless --path godot --script res://tests/validate_brick_ground_entry.gd -- $bruce $brick
& $godot --headless --path godot --script res://tests/validate_faceup_attack.gd -- $bruce $brick
& $godot --headless --path godot --script res://tests/validate_ground_pose.gd -- $bruce $brick
& $godot --headless --path godot --script res://tests/smoke_test.gd
python -B -X utf8 -m unittest discover -s tests -p 'test*.py' -q
```

Python 测试共 216 项，跳过 1 项，退出码 0。这些检查只验证当前本机候选资源
与原型行为，不证明原版逐帧等价。

逐轨道身份检查使用 `tools/audit_animation_retarget.py`，接收上述同一 ANM、
Bruce Skl 和 Brick Skl 三个路径。它以完整节点类型和父链匹配，拒绝缺失、
重复路径、重复目标通道和冲突的目标通道索引，不输出轨道值或修改资产。
实际资源执行退出码 0：61 条轨道均有唯一候选目标，仅 `bonerot` 的
`r eyeball` 从源索引 28 映射到目标索引 15。这是身份审计，不是动画重定向
或变换空间验证；此工具不会生成 GLB。调用方式可将上述索引比较命令的工具名
替换为 `tools/audit_animation_retarget.py`。

验证命令：`py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q`，
共 206 项、其中 1 项跳过，退出码 0（基于本分支及本地新工具）。

Review follow-up: `py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q` (207 tests, 1 skipped; exit 0, including 4 local untracked retarget-audit tests).

合并 main 后复测：`py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q`，共 208 项、其中 1 项跳过，退出码 0。

PR 审查补充异常父链后：`py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q`，共 209 项、其中 1 项跳过，退出码 0。

候选映射构造器 `tools/retarget_animation_binding.py` 要求调用方明确提供 ANM、
源 Skl、目标 Skl 的 SHA-256 和源引用，先检查来源配对状态，再运行逐轨道
身份审计；它保留原始轨道值并产生单独的目标索引记录，不修改来源记录。
真实资源内存调用退出码 0：61 条轨道，`r eyeball` 的目标旋转索引为 15，
所有轨道值与来源逐项相同。本功能现已用于下述离线 GLB 候选，尚未接入正常战斗；
不是对变换空间或原生行为的验证。

验证：`py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q`，
共 212 项、其中 1 项跳过，退出码 0。

## 六段 Brick 候选导出和 Godot 检查（2026-10-30）

转换器 `--retarget-animation ANM SHA256` 显式启用跨骨架实验，还需指定
`--retarget-source-skeleton`、`--retarget-source-reference`、
`--retarget-source-sha256` 和 `--retarget-target-sha256`。普通动画仍按原本的
严格配对检查。实验路径按 typed-path 识别目标节点，再用当前 pose=1 候选
公式将原始轨道与目标静态姿态组合；该组合未通过原版逐帧对照。导出动画
extras 分别记录来源与目标哈希、来源配对和目标配对未验证状态。

本机仓库外 `brick_candidate_6.glb` 为 414092 字节，SHA-256
`96d05e9652b7ecde39bbb698062e4f2041df4a928aad41d2e866ecf7857528b2`，
含 5 条现有 Brick 动画和跨骨架候选 `all_impct_hard_frnt_low`；导出命令
退出码 0。原资源、导出 GLB 均未提交。

Godot 4.7.2 使用 `--headless --path godot --script
res://tests/validate_brick_retarget.gd -- <仓库外GLB路径>` 检查，退出码 0：
69 根骨骼，受击动画导入后 58 条 Godot 轨道、时长约 0.766 秒，右眼骨骼
恰有一条旋转轨道；按候选导出时间线的第 0、10、20、22 个样本位置检查，骨架变换有限，
且至少一个非眼部骨骼发生变化。导出器将 23 个样本分布在取整的候选时长内，
Godot 导入后重采样为 24 个键；这些时间不等于已验证的原版帧时间。这不验证动画视觉质量、原版姿势或战斗触发。

验证：`py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q`，
共 216 项、其中 1 项跳过，退出码 0。

`validate_ground_pose.gd` 使用本机 Bruce 23 段及 Brick 6 段候选，退出码 0；该测试注入状态，正常对战触发尚未实现。

审查后 Godot 采样检查重跑退出码 0；候选采样时间分别约为 0、0.348182、0.696364、0.766 秒。
