# Godot 真实资源候选集成

本分支提供在仓库外加载 Bruce Lee 候选 GLB 和 Hair/Body 纹理的 Godot 接线。
仓库不包含原版 APK、ZPAK、SO、模型、纹理、动画或转换后的二进制资产。

## 输入

- 候选 GLB：`body_hair_idle_punch_kick_candidate.glb`
- 可选对手 GLB：`brick_candidate_idle_punch_kick.glb`
- 纹理目录：`body_diffuse.png`、`body_normal.png`、`body_material.png`、
  `hair_diffuse.png`、`hair_normal.png`、`hair_material.png`
- Godot 4.7.2 stable

两个输入必须位于开发仓库或导出应用目录外。战斗角色、动画预览和纹理加载器
都会拒绝内部的词法路径；
路径检查会解析符号链接、Windows junction 和缺失尾部路径前最近的真实父目录，
以实际目标位置判断是否落入受保护目录。Windows 解析器作为
`res://tools/resolve_candidate_path.ps1` 随项目打包，运行时解压到 `user://`
再执行；一键验证脚本直接复用同一文件。开发运行时以仓库根目录为边界，导出
运行时以 EXE 所在应用目录为边界。设置环境变量或使用一键验证脚本：

```powershell
.\validate_candidate.ps1 `
  -CandidateGlb 'C:\private\body_hair_idle_punch_kick_candidate.glb' `
  -TextureRoot 'C:\private\candidate-textures' `
  -GodotExe 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe'
```

脚本先执行 Python 测试，再运行一次无界面 Godot 导入，随后验证普通战斗 smoke、
真实动画、真实纹理和端到端战斗；最后执行 `--export-pack`，再从生成的 PCK
重跑 smoke、动画、材质和战斗，确保路径解析器与运行时代码实际入包。

每名角色有独立的 GLB、纹理根目录和动作名映射。环境变量
`BRUCELEE_PLAYER_GLB`/`BRUCELEE_PLAYER_TEXTURE_ROOT` 控制玩家，
`BRUCELEE_OPPONENT_GLB`/`BRUCELEE_OPPONENT_TEXTURE_ROOT` 控制电脑。
玩家旧环境变量保持兼容；未配置对手 GLB 时电脑继续使用占位体。对手缺少可选
纹理或 reaction clip 时不会阻止角色加载。

材质配置按角色选择：Bruce 使用 `body_hair`，Brick 使用单组 `body`。
Brick 的三个 `body_*` PNG 都齐全时会把同一身体材质应用到其三-surface Mesh；
当前没有解码后的 Brick PNG，因此运行报告必须保持
`opponent_textures_loaded=false`，并给出未配置原因。

`validate_candidate_textures.gd` 使用程序生成的 4×4 PNG 验证材质装配和 shader
选择；真实纹理文件由 `validate_combat_candidate.gd` 加载。两者都不等于原版
GPU 最终像素、法线方向或 Alpha 混合效果已经验收。

## 已验证

`LOCAL_TESTED + CANDIDATE`：

- 69 根骨骼、idle/punch/kick 三段动画。
- 玩家 Bruce 与电脑 Brick 可同时加载，分别使用 `m01_*` 和 `m03_*` 动作名、
  独立 `AnimationPlayer` 与候选根节点；缺少对手配置时仍可通过单角色和纯占位
  模式。两名角色均按各自实测 GLB 包围盒缩放到 1.8 米，不再共用 Bruce 的源高度。
  无法由严格 CPU-skinning 路径测量的旧玩家候选继续使用原固定源比例回退；
  电脑候选测量失败则记录错误并使用占位体，避免把 Bruce 的比例套给未知对手。
- 对手候选验证加载 69 骨 Brick 模型、一个 3-surface 蒙皮 Mesh 和
  idle/punch/kick/movefwd 四段动作；四条 clip 的中点都会改变骨骼姿态。
- Brick 的 `m03_movefwd` 仍是候选移动视觉。电脑对手的 punch/kick 直接使用
  `thai.set` 的 `lowpunch3`（8/4/26）和 `lowkick3`（9/3/29），不再把 Bruce
  的 `lowpunch1/lowkick1` 时序缩放到 Brick clip。状态总时长等于 clip 时长，
  因为这两条动画帧数就是 set 记录的帧数。这只覆盖当前四条 clip，不是完整 Thai set、AI 或 knockdown。
- 候选 GLB 中 `character` 节点的位置轨道对所有已映射 action 都禁用，避免未经
  语义确认的动画平移直接分离视觉与 `CharacterBody3D` 判定位置。原版 root-motion
  轴和位移用途仍是 `UNVERIFIED`。
- 动画验证固定检查 69 根骨骼、关键骨骼索引/名称以及三段动画时长。
- 候选实际包围盒的最低点为 `Y=-0.093933`；Body 高 `166.336`，含头发总高
  `173.416`。战斗与预览按总高缩放到 `1.8`；运行时每帧把候选可视根固定到
  `Y=0` 地面，脚底不再随物理体沉降到地面以下。
- CPU 包围盒验证只支持当前观察到的单位 Mesh 变换 glTF 绑定布局；战斗集成
  还会独立断言缩放后的世界高度和脚底最低点，不使用实现侧常量作为唯一证据。
- 头发作为 head 下的无蒙皮附件随头部移动。
- Body 使用 opaque shader，Hair 使用 blend shader。
- 六张 Hair/Body 纹理和三项 shader 参数加载成功。
- Hair/Body 的 `diffuse/normal/material` 引用 ID、`Diffuse.program` 纹理常量和
  原生 `CMaterial::Init` 到 `CManager::GetTexture` 的静态数据流已闭合；证据与
  限制见 [`MATERIAL_TEXTURE_BINDING_FINDINGS.md`](MATERIAL_TEXTURE_BINDING_FINDINGS.md)。
- Hair 的 1 个 subset 与 Body 的 3 个 subset 均已静态连接到对应材质和纹理组；
  尚未观察原版 GPU 的最终 draw call 状态。
- 真实 GLB、纹理、idle/punch 动画和战斗状态可在同一场景联动。
- `lowpunch1` 使用帧 5–8、`lowkick1` 使用帧 7–10，基础伤害均为 5。
- 两招的帧数、伤害、半径和 impact 字段由
  `godot/data/fighting_set_low_attacks.json` 加载；Godot `PortFighter` 在 `_ready`
  中校验配置，不再把两招帧、伤害或已恢复的距离公式写死在脚本常量里。
- 原型 AI 对每次玩家攻击只采样一次格挡决定，并在攻击启动帧和有效帧期间保持
  该决定；攻击进入范围后才触发决定，受击打断、恢复帧和回合重置均清除格挡。
  这里只验证原型 AI 的稳定性，不代表恢复原版 AI 格挡概率或决策规则。
- 原生距离链为 `attackRadius × fighter+0x15C + defender.GetRadius()`；
  `fighter+0x15C` 来自 character list 的 `radiusscale`，Bruce 缺省值为 `1.0`。
  两招的 `attackRadius=70`；当前候选 clip 的源半径为
  `m01_idle_01=25`（`Default.set`）、`m01_pnch_low_01=40`、
  `m01_kick_low_01=50`（后两者来自 `brucelee.set`）。
- Godot 用候选模型 `173.416 → 1.8` 的比例把源单位转换为世界单位，因此对手
  idle 时两招的候选距离上限为约 `0.98607`；对手执行低拳或低踢时分别约为
  `1.14176`、`1.24556`。源单位是否与原版场景全局单位完全相同仍为
  `CANDIDATE`，不能把该换算写成原版运行时已实测。
- `prototype_push` 仍是原型值。帧边界、不同防守动画半径、二维欧氏距离临界值、
  `distance == reach` 的闭区间边界、大步长跨阶段不丢时以及单次命中去重由
  Godot 回归测试覆盖。无效 schema 或几何数据不会部分改写已加载的战斗参数。
- 原生命中 link 在 normal/medium/frontal 时选择 `impactlightfrontmid`，返回
  idle 窗口从帧 14 开始；normal/low/frontal 选择 `impactlightfrontlow`，返回
  窗口从帧 13 开始。Godot 现在把这两个 return frame 除以 30 作为候选 hitstun
  时长；对应格挡动作使用帧 12，因此候选 blockstun 为 `12/30` 秒。
- 空 keysequence、keystatus 和 conditions 的原生 size 检查均返回成功，因此这些
  自动 reaction links 只需命中 `TimeWindowCheck`。Godot 实现仍把帧到状态的映射
  标为 `CANDIDATE`，因为原版逐帧执行顺序、blending 和位置修正尚未完整实测。
- `--export-pack` 生成的 PCK 包含路径解析器；用 Godot runtime 从该 PCK 运行
  smoke、真实动画、合成/真实纹理和端到端战斗均成功。
- 使用 Godot 4.7.2 stable Windows Export Templates 生成 release EXE/PCK；
  复制到仓库外独立目录后，EXE 内置自检成功加载外部 GLB 和六张纹理，拒绝
  应用目录内路径，并完成动画、世界边界和出拳伤害验证。

本地验证输出：

```text
PROTOTYPE_VALIDATION={"blocked_kick_target_health":99.4,"blockstun_frames":12,"kick_hitstun_frames":13,"ko_and_restart":true,"punch_hitstun_frames":14,"punch_target_health":95.0}
COMBAT_CANDIDATE_VALIDATION={"candidate_loaded":true,"candidate_textures_loaded":true,"candidate_visual_height":1.8,"candidate_world_height":1.6010163,"candidate_world_min_y":-0.0051876,"idle_clip":"m01_idle_01","punch_clip":"m01_pnch_low_01","punch_hitstun_frames":14,"punch_target_health":95.0}
CANDIDATE_TEXTURE_VALIDATION={"body_loaded":true,"body_shader":"character_candidate_opaque.gdshader","failed_profile_remained_unapplied":true,"hair_loaded":true,"hair_shader":"character_candidate.gdshader","invalid_empty_profile_rejected":true}
DUAL_FIGHTER_CANDIDATE_VALIDATION={"body_only_textures":true,"candidate_world_heights":{"Bruce (placeholder)":1.60101628303528,"Opponent (placeholder)":1.73506438732147},"invalid_clip_mapping_fallback":true,"ko_reset_idle":"m03_idle_01","missing_asset_fallback":true,"missing_clip_fallback":true,"move_root_tracks_suppressed":true,"opponent_idle":"m03_idle_01","opponent_pretransformed_grounding":true,"opponent_punch":"m03_pnch_low_01","opponent_textures_loaded":false,"player_bounds_fallback":true,"player_idle":"m01_idle_01","player_pretransformed_grounding":true,"player_punch":"m01_pnch_low_01","player_textures_loaded":true,"punch_and_kick_timing_aligned":true,"skeleton_isolation":true}
CANDIDATE_VALIDATION=PASS
EXPORT_SELF_TEST={"candidate_textures_loaded":true,"candidate_visual_height":1.8,"candidate_world_height":1.61134910583496,"candidate_world_min_y":-0.00488114356994629,"internal_path_rejected":true,"opponent_candidate_loaded":true,"opponent_idle_clip":"m03_idle_01","opponent_texture_reason":"candidate texture root is not configured","opponent_textures_loaded":false,"punch_hitstun_frames":14,"punch_target_health":95.0,"reaction_clip":"all_impct_light_frnt_mid"}
WINDOWS_EXE_VALIDATION=PASS
```

独立 EXE 复核命令：

未取得 Brick PNG 时省略 `-OpponentTextureRoot`，预期
`opponent_textures_loaded=false`。取得三张 `body_*` PNG 后再加入该参数；
当前只用四像素合成 PNG 验证了单身体材质配置能进入独立 EXE，
这不等于 Brick ATC 纹理或原版材质像素已经验收。

```powershell
.\validate_windows_exe.ps1 `
  -CandidateGlb 'C:\private\body_hair_idle_punch_kick_candidate.glb' `
  -OpponentGlb 'C:\private\brick_candidate_idle_punch_kick.glb' `
  -TextureRoot 'C:\private\candidate-textures' `
  -OpponentTextureRoot 'C:\private\brick-textures' `
  -GodotExe 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe'
```

## 边界

- 尚未与原版 Adreno 画面逐帧、逐像素对照；当前只验证了候选材质装配和静态绑定，
  未取得原版运行时 `GetTexture` 返回值或 GPU 最终像素。
- 战斗配置已静态闭合攻击半径、角色半径倍率、防守动画半径和距离比较；源单位到
  Godot 世界单位的换算、可能存在的原版位置修正、推力和受击方向仍未与原版逐帧录像对齐。
- 格挡减伤、推力和 `heavy` 仍使用原型规则；`heavy` 仍走占位距离，不套用已恢复公式。
- `height/strength/direction` 已映射到 normal reaction actions；`body_part` 到命中
  部位、受击反馈和推力的运行时映射尚未闭合。
- reaction root-motion 的 `positions` 原始帧值、`bonepos` 存在性和 ANM 哈希已导出，
  但 `positions` 的坐标轴、局部/世界空间语义及帧间增量尚未闭合。Godot 的
  `prototype_push` 未替换；block ANM 没有 `positions` 轨道也不能证明格挡没有位移。
- Windows release EXE/PCK 已在无源码目录验证启动、外部候选资源加载和战斗；
  这不等于完整原版游戏、逐像素视觉或最终发行质量已经验收。
- 对手 Brick 已加载 `thai.set` 中与当前四条 clip 对应的低段攻击和动画半径，并关闭 Bruce 时序缩放。硬受击和 `highblockhard` 记在 Bruce 防守配置上。JSON 的 `clip_implemented` 仍是 false，`facedownidle` 和 `idle2` 的 `return_implemented` 也仍是 false；加载的 GLB 实际含有对应动画且候选轨道检查通过时，hitstun/blockstun 播放该 clip，不再改播轻击正面反应。15 段返回候选含有 `idle2` 和 `facedownidle` 时，退出帧之后进入这两个已核对状态；缺 clip 时仍显式回到普通 idle。这不是原版逐帧视觉验收，也不是 knockdown 或完整 Thai set。ATC 纹理、完整 Thai set、AI 和 knockdown 仍未恢复。
- 本分支测试通过不等于原版角色动画、光照、碰撞或战斗规则已完成运行时复刻。

## 候选受击与格挡视觉

本机九段动画的候选 GLB 包含原有 idle/punch/kick，以及正面轻受击和
格挡各 low/mid/high 三段。战斗状态机按已有 reaction profile 选择可用的
视觉动画；同一种反应被再次触发时从头播放，硬直结束时回到 idle。
旧三段动画 GLB 仍可加载，缺少反应 clip 时使用原有 idle 回退。

反应动画的候选 `character` 平移轨道未证明可用于游戏位置，运行时解析轨道
实际目标后关闭该轨道，并在开始反应时将该节点位置恢复到加载时的值；未知
节点或轨道布局回退到 idle。骨骼和骨架父节点的候选动画仍会改变模型姿态，
这不证明角色视觉位置、穿地、朝向或原版效果已经验收。动作从第 0 帧播放，
`lowblock` 的 linking frame、融合与原版执行顺序仍未闭合。

生成九段 GLB 可使用仓库中的候选转换器；输入准备、命令和复现结果见
[`ANIMATION_CONVERTER_MIGRATION.md`](ANIMATION_CONVERTER_MIGRATION.md)。
所有原版资源及生成的 GLB 仍位于仓库外。

验证命令及结果（本机 Godot 4.7.2）：

```powershell
.\validate_candidate.ps1 -CandidateGlb 'C:\private\reaction_candidate.glb' `
  -TextureRoot 'C:\private\textures' -GodotExe 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe' `
  -ExpectReactionClips
.\validate_candidate.ps1 -CandidateGlb 'C:\private\legacy_candidate.glb' `
  -TextureRoot 'C:\private\textures' -GodotExe 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe' `
  -ExpectLegacyClips
.\validate_windows_exe.ps1 -CandidateGlb 'C:\private\reaction_candidate.glb' `
  -TextureRoot 'C:\private\textures' -GodotExe 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe' `
  -ExpectReactionClips
```

上述三条命令退出码均为 0；候选验证包含 126 项 Python 测试、开发版与 PCK
下六个反应选择、骨骼变化、重入、返回和未知目标回退，独立 EXE 自检确认
选中 `all_impct_light_frnt_mid`。受击期间检查骨架父节点相对首帧的世界位置
变化不超过 0.5 米，并检查返回 idle 后恢复位置；这个阈值仅用于捕捉明显跳变，
不是原版距离或视觉准确性的证据。尚无原版逐帧对照或可见窗口人工验收。

## 硬受击候选 clip

仓库外 `bruce_candidate_hard_reactions.glb` 在原有九段上增加三条已核对的 Bruce 防守 clip：`all_impct_crotch`、`all_impct_hard_rht_low`、`all_block_high_hard`。GLB JSON 只有这 12 个动画名。`all_impct_crotch` 的 SHA-256 与 `reports/reaction_action_inventory.json` 一致。另外两条的 SHA-256、resource id 和 PAKD offset 与 `reports/brick_thai_low_attack_evidence.json` 的 `bruce_defender_exact_reactions` 一致，并由同一次只读 `read_archive_resource` 复核。原始 ANM 和 GLB 仍留在仓库外。

`all_impct_hard_rht_low` 含一条 raw-fixed `rotations` 轨道。采样为 25 帧 `int16[4]`，按已验证的 `bonerot` Q14 解码后首帧是单位四元数，模长误差与该轨道同一量级。offset 为 0，对应骨架 object `character` 的 `object_rotation_index`。四元数分量顺序，以及对象旋转如何作用到朝向，仍未验证。运行时关闭 character 节点的平移、旋转和缩放，避免把未验证的对象运动当成 fighter push、朝向或体型变化；当前样本的 scale 虽是恒等缩放，代码也不保留这条轨道。骨骼轨道仍播放。

没有加载这些 clip 的旧 GLB 仍可使用。缺失硬击 clip 时不改播轻击正面反应。`return_implemented` 不因本轮改为 true。

## 受击后的返回状态

仓库外 `bruce_candidate_return_states.glb` 在上述 12 段上增加三条从 `adreno_200/set/brucelee.set` 复核的 clip：`m01_idle_02`、`all_idle_face_down`、`all_getup_facedwn`。GLB JSON 只有这 15 个动画名。原始 ANM、GLB 和字节留在仓库外。resource id、PAKD offset 和 SHA-256 见 [`bruce_return_states.json`](../reports/bruce_return_states.json)。

只有当前加载的 GLB 含有所需 clip，并且现有候选轨道检查通过时，才进入返回状态。静态 JSON 的 `return_implemented` 与 `clip_implemented` 保持 false。加载器仍拒绝 `clip_implemented: true`。缺 clip 时，`highblockhard` 和 `impacthardrightlow` 在记录到的退出帧之后回到普通 idle。

`highblockhard` 到达退出帧后进入 `idle2`，循环播放 `m01_idle_02`，动画半径 40。现有移动、拳和踢仍可从 `idle2` 发出：`canmove`、`candobasicattacks` 和 `canblock` 覆盖第 0 到 43 帧。这里不新增攻击。`idle2` 的直接循环是 `idle2 -> idle2`，时间 `[43, 43]`。

`impacthardrightlow` 到达退出帧后进入 `facedownidle`，循环播放 `all_idle_face_down`，动画半径 75。这个状态不接受普通拳或踢。它在第 10 到 45 帧接受一次水平移动输入并进入 `facedowngetup`。负的 `move_axis.x` 代表档案里的 left，正的代表 right。这用的是原型移动轴，不是已核对的原版键盘绑定。`facedownidle` 没有战斗分组。低高度、非格挡、并且伤害后血量仍大于 0 的 impact 进入 `impactfacedown`。血量降到 0 时，档案里更靠前的 `healthzero` 链接进入 `facedownko`。`facedownattack` 仍没有实现。

`facedowngetup` 播放 `all_getup_facedwn`，动画半径 25，并在第 16 帧回到普通 idle 的第 0 帧。档案窗口是 `[16, 19]`，linking frame 为 0。不继续进入 `facedownattack`。这不是完整 knockdown。

`facedownko`、`impactfacedown` 和 `facedownattack` 已用只读的 `read_archive_resource`、`_parse_set` 和 `_animation_metadata` 从 `adreno_200/set/brucelee.set` 核对，字段见 [`bruce_facedown_followups.json`](../reports/bruce_facedown_followups.json)。`facedownattack` 仍只是证据记录，没有实现。`facedownko` 使用已经加载的 `all_idle_face_down`，半径 100，循环 45 帧，不接受起身，也不应用这次致命攻击的原型 push。缺这条倒地 clip 时仍走站立 `ko`。`impactfacedown` 在仓库外 16 段 `bruce_candidate_facedown_impact.glb` 通过现有轨道检查后播放：动画 `all_impct_facedwn`，半径 80，不循环，第 11 帧回到 `facedownidle` 第 0 帧。触发限于 `facedownidle` 的 `impact` + `oppattackheightlow`，且本次伤害不会把血量降到 0；血量降到 0 仍走现有 `ko`。中高度攻击没有这条链接，仍走原来的站立反应。这段不应用原型 push。GLB SHA-256 是 `1952340a02fa64f779ace554a0d15647ea679ee9e6599dc115c3ccfa3a107705`。原始 ANM 和 GLB 留在仓库外。`facedownko` 使用 `all_idle_face_down.anm`，半径 100，45 帧，30 fps；`defeated` 和 `receivedamage` 的窗口都是 `[0, 45]`，第 45 帧连回自身。`impactfacedown` 是档案里的倒地受击动作名，使用 `all_impct_facedwn.anm`，半径 80，11 帧，30 fps；`receivedamage` 窗口是 `[0, 11]`，第 11 帧进入 `facedownidle`。`facedownattack` 使用 `all_getup_facedwn_attack.anm`，半径 45，35 帧，30 fps，第 32 到 35 帧进入 `idle`。分组三元组的末值都是 0。同 set 里的 `impactfaceup`、`impacttofloor`、`attacktofloor`、`faceupko`、`faceupattack`、`faceupidle` 和 `faceupgetup` 只读到动作名，规定字段没有读完，不记为已闭合，也没有另起地面受击名称。

character 节点的平移、旋转和缩放轨道在运行时关闭，骨骼轨道仍播放。12 段硬受击 GLB 不含这三条返回 clip，因此仍在退出帧之后回到普通 idle。
