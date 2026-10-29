# PC 原生移植路线：从可玩的占位原型到尽量忠于原版

## 技术路线选择

**选定：Godot 4.7.x（标准版、GDScript）+ 独立资源转换工具 + 干净重建的 PC 运行时。**

目标产物是 `Windows x86_64 EXE + PCK/资源包`，不安装安卓子系统，不调用原 APK ARM 代码。未来可以根据复杂度将独立的资源解析器迁移为 C++ GDExtension，但首阶段不需要。

**为什么不直接二进制翻译**：原 `.so` 依赖 Android NDK 和原生渲染、输入、音频、文件系统。即使解决 ARM→x86 动态翻译，仍必须模拟 Android 运行环境与 EGL/GLES 生命周期，兼容测试面极大。维护成本与原生游戏目标冲突。

**为什么不先全面重写玩法**：原游戏留下大量符号且拥有资源包，先通过逆向获取动作与规则，再设计匹配的数据层，减少错配和返工。

## 分阶段里程碑与验收

| 阶段 | 产物 | 验收标准 | 当前状态 |
|---|---|---|---|
| P0 输入核验 | APK / ZPAK 指纹、资源清单 | 资产哈希、ZIP CRC、CPU 架构、候选符号可复现 | 已完成大部分；未覆盖完整资源 CRC 验证 |
| P1 原生运行框架 | Godot 项目、场景、动作输入、AI、血条 | Godot 本机运行，战斗无脚本错误，Windows 导出为 EXE | 已完成：开发、PCK 和仓库外 release EXE 自检通过 |
| P2 PAK 解包器 | `Core.pakh` 全目录、`Core.pakd000` 完整读取 | 至少 10 个命名文件的字节范围与解压值可证实；全包无越界 | 完成：完整原包实际验证 2144 条流、417 个目录节点、2265 条路径和尾部 CRC |
| P3 资产转换 | 网格、材质、骨骼、动画、场景、声音批量转换 | 至少一套 Bruce Lee 角色模型骨骼及 idle/punch/kick 动画可在 Godot 播放 | 进行中：纹理、Skl/Object、四个 Mesh 及真实 Mesh IBM 已解析；Hair/Body 的 subset → material → diffuse/normal/material 静态绑定和 78 节点场景层级、Link 字段、六类实体创建和 OpenGL 绘制批处理路径和视觉项 subset 提交粒度与 pass 位图来源和批处理三元键和 TBatchID 槽位来源已核对；候选 GLB 的 69 根骨骼和 idle/punch/kick 已在 Godot、PCK 与独立 Windows EXE 中运行。首个对手 Brick Davis 的骨架、Object、Mesh、三张纹理及四条 `m03_*` 动画已静态配对并在仓库外导出候选 GLB；候选 Brick 已作为独立电脑视觉接入，使用 `m03_*` idle/punch/kick/movefwd。Brick 三张 1024×1024 纹理的基础层解码已恢复，当前四条 `m03_*` clip 已接上 `thai.set` 的低段攻击规则；完整 Thai set、AI、knockdown 和逐帧视觉仍未恢复。尚缺完整角色/场景资产批量转换、原版逐帧视觉与 GPU 材质对照 |
| P4 原版战斗还原 | 招式/输入/命中箱/攻击帧/硬直/伤害/连段 | 同一场景下与原版逐帧录像对照，误差记录 | 进行中：lowpunch1/lowkick1 的帧、伤害、攻击半径、角色半径倍率、防守方动画半径和 reaction return frame 已配置驱动；normal 正面受击、格挡动作选择及返回窗口已静态闭合。Brick 的 `lowpunch3/lowkick3` 使用档案里的 8/4/26 和 9/3/29，不再缩放 Bruce 时序；Bruce 防守方的 `all_impct_crotch`、`all_impct_hard_rht_low` 和 `all_block_high_hard` 已在加载包含它们的候选 GLB 时播放。15 段候选另外包含已核对的 `m01_idle_02`、`all_idle_face_down` 和 `all_getup_facedwn`：`highblockhard` 退出后循环 `idle2`，`impacthardrightlow` 退出后循环 `facedownidle`，`facedownidle` 在第 10 到 45 帧用原型 `move_axis.x` 进入 `facedowngetup`，并在第 16 帧回到普通 idle。这不是原版逐帧视觉验收，也不是 knockdown。`facedownidle` 上血量降到 0 时进入 `facedownko`，沿用 `all_idle_face_down`，半径 100，不接受起身。仓库外 16 段候选额外含已核对的 `all_impct_facedwn`：`facedownidle` 受到低高度且非致命的 impact 时进入 `impactfacedown`，半径 80，第 11 帧回到 `facedownidle`。缺这条 clip、中高度攻击，或伤害会把血量降到 0 时，不进入 `impactfacedown`。加载含 `all_getup_facedwn_attack` 的候选 GLB 时，`facedownidle` 接受 `aaa`、`abb`、`bcc`、`bdd` 四条已恢复序列，播放半径 45、35 帧的 `facedownattack`，第 6 到 9 帧造成一次 6 点伤害，第 32 帧回 `idle`；PC 原型用 `J/K/L/U → pressa/pressb/pressc/pressd`，不冒充原版 Android 物理键位，缺 clip 时保持 `facedownidle`。档案字段见 `reports/bruce_facedown_followups.json`，逐帧录像与完整命中盒仍未验收。仓库外 19 段候选只增加 `all_stunned_fall` 和 `all_idle_face_up`，受限候选路径允许 `facedowngetup [5,11]` 或 `facedownattack [24,31]` 受到非致命、非格挡的低段命中后进入 `impacttofloor`，从第 21 帧起播并在第 48 帧进入循环 `faceupidle`；致命命中、缺 clip 和窗口外命中不走该链。加载含 `all_getup_faceup` 的候选 GLB 时，`faceupidle` 在源帧 `[10,45]` 接受候选水平 `move_axis.x`，播放 24 帧、半径 40 的非循环 getup，并在第 20 帧回 idle；档案只给出 `[20,24]` 转换窗口，因此第 20 帧是候选选择。该链尚未解释 incoming 分组的 `time=[0,0]`。`impactfaceup`、`attacktofloor`、`faceupko` 和 `faceupattack` 仍只有档案证据，尚未接入。Godot 的 hitstun/blockstun 已接入候选帧数，reaction root-motion raw track 已导出，push 仍未映射，候选单位换算和逐帧录像对照未完成 |
| P5 体验还原 | 镜头、UI、声音、场景/关卡、菜单、存档 | 选角、连续对战、胜负、重开、存档均可操作 | 未开始 |
| P6 稳定性与发行准备 | EXE 构建、手柄、缩放、异常恢复 | 目标 Windows PC 实测；资源来源及发行授权清晰 | 未开始 |

## 实现分层（避免混合研究与正式运行时代码）

- `tools/`: 离线证据采集，原始文件只读、输出到单独目录。
- `converters/`（未来）：输入源资产 → 输出已解码标准 glTF/PNG/OGG 等，保留文件原始 digest 和元数据。
- `godot/scripts/`: PC 独立状态机、碰撞/动作逻辑、AI、资源调用。
- `godot/assets/`（未来，不纳入公共仓库）：由用户授权持有的源资产转换得到的本地资源。
- `evidence/`: 逆向函数地址、数据格式、期望行为、版本差异、已验证事实/未知。

## 原版机制逆向优先顺序

1. PAK：确认头格式、版本、索引结构，定位两文件偏移/大小/校验/压缩读取代码；优先 `CPakDFilesManager::Load` + `GetInputStream` + `_ReadHeader`。
2. 资产：恢复 `mesh`、`skl`、`anm` 数据块解码；优先追踪 `CAnimationDescr::ParseFromKDF` 和模型加载器。
3. 战斗：`CFighter::AttackDamage`、`CFighter::ModifyHealth`、`CFighter::SetAnimation`、`IsAttacking`、动作记录、状态切换、定时器。
4. 输入和手感：`CBeatEmUpMatch::KrmInputEventCallback`、`CFighter` 行为函数、按键到动作映射；恢复连续输入容错、取消窗口、攻击命中回退。
5. 渲染/视角：原版 OpenGL ES 2.0 的模型、材质映射到 Godot Compatibility Renderer（导入模型后重新验证视觉）。

## 重要依赖与风险

- **R1** 私有载荷格式：PAK、Skl 层级与静态姿态、动画容器、Object 引用、Mesh 几何/权重和五条 wavelet 轨道的候选解码已恢复；原生逐帧对照、动画槽位/坐标语义、材质与 Godot 资产转换仍阻塞完整导入。
- **R2** 缺少原版参考运行/录像：难以确认出招手感、AI、UI 与关卡细节。建议保留原版合法运行录像及输入标注作对照。
- **R3** 老版游戏资源的版本配套：ZIP 内 metadata title 版本与 APK 包名版本可能不一致，需以具体运行情况和加载机制确认。
- **R4** 按需资源/平台差异：即使 ZIP 内有 `data.zpak`，不能断言包含跨机型的全部 shader / GPU 特定贴图变体。
- **R5** 版权与发行：私人研究/兼容性和公开分发不是同一种授权。无需将原版资源放入公开仓库。

## 不应宣称已经完成

- 已得到并验证可运行的占位战斗 Windows EXE/PCK，但尚不是完整原版游戏。
- 候选模型、骨骼及三段动画已在 Godot 运行；完整资产批量转换、Blender 导入流程和发行级视觉仍未验收。
- 尚未复原原始游戏输入手感、命中判定、人物 AI、模式完整性。
- 尚未实现等效 Android 原版内容的全部移植。
