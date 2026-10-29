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
- 对手 Brick 已加载 `thai.set` 中与当前四条 clip 对应的低段攻击和动画半径，并关闭 Bruce 时序缩放。硬受击和 `highblockhard` 记在 Bruce 防守配置上；这些 clip、`facedownidle` 和 `idle2` 都还没有实现。ATC 纹理、完整 Thai set、AI 和 knockdown 仍未恢复。
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
