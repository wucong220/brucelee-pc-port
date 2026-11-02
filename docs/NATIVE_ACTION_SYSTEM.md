# 原版动作系统：反编译结论

来源：`libdefault.so`（SHA-256 `1da7a30c…`）经 Ghidra 12.2 分析后的 C 伪代码，
本机路径 `D:\BruceLeeWork\ghidra-out`、`ghidra-out2`。本文只记录结论与地址，
不复制反编译源码，也不含原版载荷。

## 实现状态（2026-11-02，数据驱动版）

`godot/scripts/fighter.gd` 已按这套链路重写，原型的 FIFO 攻击队列、0.52/1.35 秒
时间窗、`_standing_combo_pending_*` 和手写的 `STANDING_COMBO_SEQUENCES` 都已删除：

- `godot/data/native_links.json`：由 `tools/export_native_links.py` 从
  `brucelee.set` 只读导出，含 200 个动作的组窗口、396 条 link 的原始顺序、
  `keysequence`、`keystatus`、`time`、`entry_frame`、`linking_frame`、
  `conditions` 和 `input_reset`。
- `keysequence`/`keystatus` 是**按输入布局选择的备选**，不是三步：
  `CLinkDescr::GetKeySequence(index)` 返回 `link + index*0x14 + 0x30`，
  `index = fighter+0x1c`，由 `CBeatEmUpMatch::LoadFighter` 写入。
  `adreno_200/input.config` 显示触屏布局 `control_profile=0`（a/b），
  键盘布局 `control_profile=1`（a/b/c/d）；PC 端取索引 **1**
  （`LINK_SEQUENCE_INDEX`）。四键因此对应
  a=highpunch1、b=lowpunch1、c=highkick1、d=lowkick1。
- `_try_follow_links()`：每次物理更新按**原始 link 顺序**遍历当前动作的 link，
  依次做窗口、序列、按键状态、条件检查；不再人为规定“源 link 优先”。
- 窗口：直接 link 用 `link.time`；组 link 用当前动作对应组的窗口
  （`TimeWindowCheck` 的 group 分支）。
- `_native_link_status_ok()`：把 `main.gd` 每帧送入的按键状态向量与
  link 的 `keystatus`（`pressed`/`released`）比较，对应 `InputStatusCheck`。
- `_consume_link_events()`：只标记匹配事件；`input_reset == "true"` 时才清空整个
  事件向量（对应 link `+0xe0` 分支的近似）。
- `_begin_chained_attack()`：命中后直接切目标动画，不再排队。

验证：`validate_link_input.gd`（J J J → `punch` + `high_punch2`、后段窗口 →
`high_punch`、事件不重复触发）、`validate_move_gallery.gd`（25 招）、
`validate_menu_confirm_attack.gd`、`smoke_test.gd`。

**训练（2026-11-02 第 13 轮）：26 课全部通过**
`CFighter::LoadFightingSetFromKDF` 为每个动画单独建表
（`+0xf8/+0x100/+0x104/+0x108`）：遍历全部 link，把 link 的 `from_group`
与动画自己的**组名向量**比对，命中的追加进这张表。该向量由
`CAnimationDescr::ParseFromKDF` 从 KDF 的 **`groups`** 字段填充
（Ghidra 里 `DAT_0023e660 + 0x23e200` 解析出的字符串就是 `groups`）。
因此每动画表 = “当前动画拥有的各组名下、按全局顺序的 link”，与移植里的
`_native_link_applies` 组过滤等价；不存在额外的隐藏白名单。

之前 15 课失败不是 link 表问题，而是**前置选错**：
- `highpunch3` 的 `combolevel3=[0,85]` 与 `candobasicattacks=[21,85]` 重叠，
  单键 `highpunch1` 的 `a` 会合法抢先
- `highpunch2` 的 `combolevel3=[14,31]` 与 `candobasicattacks=[32,81]` **不重叠**，
  在 14–31 帧里只有 miss link 可用
把 `special_punch_low/high` 的前置改成 `high_punch2` 后，15、16 通过；
`grab1/grab2` 用 `stepright`/`stepleft` 前置也通过。26 课现在全部 PASS。

`heavy` 数据里根本不存在，第 17 轮已从代码、AI 出招表、训练和测试中完全删除。动画 `ordinal` 不是连招顺序
（`lowpunch1=22`、`highpunch1=13`），不能用它做过滤。

**attacktofloor 输入已改成原生 link（第 10 轮）**
- 删除了 `try_attack_to_floor_press`、`AttackToFloorInputResult`、
  `ATTACK_TO_FLOOR_SEQUENCES` 和 `_ground_attack_input_history` 里对应的
  原型路径；`main.gd` 的 b/c/d 不再拦截
- 键盘布局索引 1 下，`candobasicattacks -> attacktofloor` 的序列是单键
  `c`（C 键），条件 `oppposelaying`，窗口按当前动作的
  `candobasicattacks` 组
- `validate_ground_pose`、`validate_attacktofloor_from_parry`、
  `validate_brick_facedown_impact` 已改成单键 C 驱动

**地面攻击输入已改成原生 link（第 11 轮）**
- 删除了 `record_virtual_press`、`GROUND_ATTACK_SEQUENCES`、
  `_matches_ground_attack_sequence`、`_ground_attack_input_history` 和
  `GROUND_ATTACK_INPUT_PROTOTYPE_WINDOW_SECONDS`
- `facedownidle -> facedownattack`、`faceupidle -> faceupattack` 是原生直接
  link；索引 1 下 a/b/c/d 都是单键，状态由 `_begin_ground_attack()` 进入
- 目标 clip 缺失时 fail closed（Brick 的候选没有地面攻击 clip，不会误播）
- `main.gd`、`move_gallery.gd`、`validate_facedown_attack` 全部改走
  `record_standing_combo_press`

**parry 输入已改成原生 link（第 14 轮）**
- 删除 `record_parry_press`、`PARRY_RAGE_COSTS`、`_parry_press_times`、`main.gd`
  的 `_update_parry_input`（Shift 三次 + guard 的原型）
- 原生 `parryhigh`：`candocounter` 组、variant 1 序列 `down,right`，
  条件 `countertime` + `ragethird`；`parryattack` 是从 `parryhigh` 的空序列
  自动衔接
- `counter_time` 在动作记录的 **`attack.counter_time`** 里（不是动作顶层），
  例如 `lowpunch1` / `highpunch1` 都是 `[0,8]`；`tools/export_native_links.py`
  已把它导出到 `native_links.json` 的 `counter_time` 字段
- `countertime` 条件现在按对手当前动作的 `counter_time` 帧窗口判定；
  `validate_parry` 同时验证帧 0（窗口内）能招架、帧 9（窗口外）不能
- 原生没有 `parry_low`；训练和招式目录已移除该课，现有 25 项

**第 19 轮补充**：`grabdistance` 条件也改成数据驱动。`tools/export_native_links.py`
把动作 `attack.grab_distance` 导出到 `native_links.json`（例如 grab1=70、
endattack1=150、grab2=90、specialpunchlowhit=120），条件按
`grab_distance * source_units_to_world` 与世界距离比较；常量 0.7 只在缺数据时回退。

**第 20 轮补充**：转向也改成数据驱动。`tools/export_native_links.py` 导出动作的
`facing` 窗口到 `native_links.json`；`_facing_window_ok()` 只在当前动作的
`facing` 帧区间内允许转身（grab1 `[0,1]`，endattack1 的 `[1,0]` 视为锁定）。

**第 21 轮补充**：删除了自创的 `_try_special_chain`、
`SPECIAL_CHAIN_WINDOW/MISSES` 和 `special_punch_low_miss` 提前收招帧。
miss→hit（special/grab）与 parry→parryattack 都由原生空序列 link 完成；
link 路径也不再按 `SPECIAL_RAGE_COSTS` 扣怒气（原生只有 `ragethird`/`rage2thirds`
门槛，没有按 link 收费的字段）。训练 25 课与招架测试仍全过。

**第 22 轮补充**：`tools/export_native_links.py` 导出每个动作首个 impact 的
`height/strength/direction`；`oppattackheight*/oppattackstrength*/oppattackdir*`
条件现在按**对手自己的攻击配置**里的 `source_impact` 判定（Brick 的 m03 攻击同样能解析），缺数据时再回退到 `native_links.json` 的 impact（例：lowpunch1 = medium/normal/frontal，
highkick3 = high/hard/fromright）。这些条件主要服务于 `impact*/block*/stun*`
反应链接，而反应动画目标仍需要 `CStateManager` 才能驱动，目前仍由
`reaction_for_incoming` 处理。

**三段相位的帧边界已核对（第 18 轮）**
`startup/active/recovery` 不是凭空编的时长：每一招来自 `brucelee.set` 的
`attack.impacts[].damage_time` 和动画总帧数。以 `lowpunch1` 为例，
`damage_time=[5,8]`、`animation_frame_count=69`，得到
- `startup_frames = 5`（伤害起点）
- `active_frames = 8 - 5 + 1 = 4`（伤害区间长度）
- `recovery_frames = 69 - 9 = 60`（剩余帧）

三者和等于 69，`_parse_attack_config` 还会校验这个等式。所以“相位命名”是移植的
结构，但相位**边界是数据算出来的**，不是自创数值。真正还未替换的是用相位枚举
代替原版的纯动画帧推进（`BasicUpdate` + `CurrentAnimFinished`）。

**第 25 轮**：所有招式的 `startup/active/recovery` 已按 `damage_time` 重新算出并
修正了此前手填偏差（endattack2 由 1/0/234 改为 20/4/211，grab1 active 77→78，
grab2 72→73，specialpunchhighmiss 2→4）。无伤害动作（miss/parry）改用其出边
link 窗口：specialkicklowmiss `[14,16]` → 14/3/33、specialpunchlowmiss `[8,9]` →
8/2/23、parryhigh `[9,10]` → 9/2/51。新增 `tests/test_attack_phase_windows.py`
对全部招式校验，任何手填漂移都会失败。

**第 26 轮补充**：招架的吸收窗口不再写死 25 帧，而是读该动作的
`impactable` 组窗口（`parryhigh = [30,62]`，所以第 30 帧前吸收、之后可被命中）。
Brick 的 `parry_*_brick` 仍暂用 25 作为回退。

**第 27 轮补充**：反应（受击/格挡）选择接入原生反应 link。`_build_native_reactions()`
从 `native_links.json` 生成 26 条受击 + 10 条格挡反应条目（`impact*`/`block*`
目标，条件 `impact` + `oppattackheight/strength/dir`，收招帧取目标动作到
`idle/faceupidle/facedownidle` 的出边 `time`）。选择时只使用候选模型实际拥有的
reaction clip；没有原生条目/片段时仍回退到 `REACTION_PROFILES`。新增
`validate_native_reactions.gd` 验证 hard/high/frontal 命中会选中
`impacthardfronthigh`（`all_impct_hard_frnt_high`）。

**第 28 轮补充**：stun 链的时长也改成读原生 link 窗口。`stun→stun2` 和
`stun2→stunfall` 都是 `[55,61]`，`stunfall→faceupko` 是 `[71,79]`；
`_stun_step_seconds()` 用这些窗口起点计算状态时长，常量 55/71 只作回退。
顺带修正旧代码把 `stun2` 时长写成 71（应为 55）的偏差。
`tests/test_stun_chain_frames.py` 锁定常量与 link 窗口一致。

**第 29 轮补充**：stun 链的**状态顺序**也改成查 link：`_advance_stun_state`
按 `stun→stun2`、`stun2→stunfall`、`stunfall→faceupko` 的出边决定下一状态与时长，
不再写死分支。`_advance_stun_impact_state` 的 `impactstun→stun` 仍由反应强度
映射选择。

**第 31 轮补充**：`impactstun→stun` 的冲击反应也改成查原生 stun 目标。
`_stun_impact_reaction()` 按来袭 impact 的 strength/height 选择
`stunlighthighimpact / stunlightlowimpact / stunmediumimpact / stunhardimpact /
stunbrutalimpact`，动画取该动作 `animation`，收招帧与下一状态取其到
`faceupko/facedownko/stunfall` 的出边 `time`。`validate_native_reactions.gd`
验证 hard→`stunhardimpact`/`faceupko`、brutal→`stunbrutalimpact`/`facedownko`。

旧模型的测试 `validate_attack_queue`、`validate_all_combo_queue`、
`validate_combo_timing`、`validate_standing_combos` 及依赖 pending 的
方向/特殊招测试已删除——它们验证的是被删掉的队列/时间窗语义，不再适用。


## 输入到招式的真实链路

### 第三轮补充：移动动作也是 link 来源

`_current_action_name()` 现在在站立状态返回当前移动动作名（`stepback` /
`stepfwd` / `stepleft` / `stepright`）。原生数据里 `specialkickhigh` 的 link
来源就是 `stepback`（`from: stepback`，`ragethird`），所以不返回移动动作名时
这招永远无法按原生输入触发。

第 12 轮把“播放用动作名”和“link 用动作名”分开了：`_movement_action()` 仍返回
`moveleft/moveright`（视觉 clip），而 `_native_movement_action()` 返回原生 link
来源 `stepleft/stepright`；否则水平移动会改播 step 动画，`validate_brick_ground_entry`
的移动循环断言就会失败。

### 基础攻击就是单键 link（第 16 轮修正）

先前按索引 0 读 `keysequence` 时，指向 `lowpunch1`/`lowkick1` 的只有
`a,b,b`/`b,d,d`，于是误判“没有单键 link、需要默认攻击入口”。切到键盘布局
（索引 1）后，四条基础攻击各有单键 link：

- `pressa` → `highpunch1`（高拳）
- `pressb` → `lowpunch1`（低拳）
- `pressc` → `highkick1`（高腿）
- `pressd` → `lowkick1`（低腿）

所以 `main.gd` 里“按键直接 `request_attack` 基础招”的回退是多余的，
第 16 轮已删除；现在所有攻击键只走原生 link 表，匹配不到就什么都不做。

`CFighter::BasicUpdate`（`0x1b8330`）的完整反编译也确认它**没有任何攻击按键
分支**：它只推进动画时钟、按帧区间记录当前帧、处理 `+0xf0/+0xf4` 的待执行
link、更新朝向/位移。`+0xf0/+0xf4` 只在 `BasicUpdate` 里执行 `SetAnimation`，
而这些带 `linking_frame` 的 link 目标几乎都是 `idle` 系列（回站立），不是攻击起手。

`CFighter::UserControlUpdate`（`0x1b89c0`）每次更新依次遍历**当前招式的
link 表**（`GetActiveSetAnimation +0x100/+0x104/+0x108`），对每条 link 做四个检查：

| 检查 | 地址 | 语义 |
|---|---|---|
| `TimeWindowCheck` | `0x1b1ee0` | link 窗口是**当前动画帧区间** `[+0xcc,+0xd0]`（或按目标动画索引查表），不是“第一下按键后的时间窗” |
| `InputSequenceCheck` | `0x1b0180` | 从事件向量**末尾向前**扫描；不匹配的事件跳过；`+0x10` 非零（已消费）的匹配事件也跳过 |
| `InputStatusCheck` | `0x1b020c` | link 要求的按键**状态**必须出现在当前 keystatus 向量里（按下/松开） |
| `CheckConditions` | — | link `+0xb8` 的条件表（对手状态、怒气等） |

`CLinkDescr::GetKeySequence(index)` 的实际实现是
`return this + index * 0x14 + 0x30`：每条 link 有**多组备选序列**，由
`fighter+0x1c` 选择（该值来自 `CSettings.input_layout`）。当前移植按
`LINK_SEQUENCE_INDEX = 1` 选择键盘布局这一组，不是把 3 项当成三个步骤；
`+0x1c` 的写入点见 `INPUT_CONFIG_FINDINGS.md`。

四项全部通过才执行：

1. `FollowLink`（`0x1b8040`）：目标动画索引大于当前索引时，只把 link 挂到
   `fighter+0xf0/+0xf4` **延迟执行**；否则立即 `SetAnimation`，速度比取
   `link+0xdc / fighter+0x30`；抓取类还要摆双方位置。
2. `ConsumeEvents`（`0x1b0b1c`）：把匹配到的事件 `+0x10` 标 1；没消费完会写
   调试日志。
3. 若 link `+0xe0` 非零，把**整个事件向量**的 `+0x10` 都标 1。

## 与 PC 原型的差别

| 原版 | 原型（自创） |
|---|---|
| 招式由 link 驱动；窗口是动画帧区间 | FIFO 攻击队列 + 0.52s/1.35s 输入时间窗 |
| 事件有“已消费”标记，`ConsumeEvents` 精确标记 | 队列按按键逐条入队，目标排最后 |
| `FollowLink` 延迟的是 **link**（按目标动画索引） | 延迟的是“攻击”，目标排在已排队攻击之后 |
| `InputStatusCheck` 检查方向键**状态** | 只在按键瞬间采样一次方向 |

## 还没闭合的点

- `CBeatEmUpGame::Update` 里输入事件队列的 `+500` 过期已确认是 **500 毫秒**
  （事件时间戳来自 `krt::time::GetCurrentMili()`），已按“最后事件 +500ms
  整批标记已消费”实现。
- link `+0xb8` 条件表的具体字段语义（`oppposestun`、`ragethird` 等）只恢复了一部分。
- `+0x2c`/`+0x34` 的“当前动画 / 当前帧”换算与 `SetAnimation` 的第 4、5 参数仍需核对。

## 结论

输入层和状态层都必须按 link 模型重写：**每个更新遍历当前招式的 link，
做 TimeWindowCheck + InputSequenceCheck + InputStatusCheck + CheckConditions，
通过后 FollowLink 并 ConsumeEvents**。在这条链路替换掉之前，任何时间窗、
队列、优先级参数都只是猜测。

## ChatGPT 审查后的修复（2026-11-02）

审查结论为 Request Changes，指出两个 P1 和若干 P2。已修复：

- **P1-1**：`main.gd` 不再把仍按住的方向塞进攻击事件；`_standing_combo_modifiers()`
  已删除。方向键按下本来就是独立事件（`_record_direction_press()`），
  `InputStatusCheck` 继续读按住状态。
- **P1-2**：`_consume_link_events()` 对空 `steps` 直接返回，修复
  `steps[-1]` 越界；新增 `validate_real_key_path.gd` 覆盖真实键盘路径、
  空序列衔接和 `parryhigh→parryattack`。
- **P2 entry_frame**：`_begin_chained_attack(kind, start_frame)` 按
  link `entry_frame` 进入目标动画的对应帧；`_native_entry_frame()` 从
  `native_links.json` 读取（attacktofloor=9）。
- **P2 收招 link**：`_native_recovery_return()` 用当前动作到
  `idle/idle2/idle3` 的出边决定收招状态与 entry_frame（lowpunch3→idle2
  `[51,81]` entry 5、specialpunchhighmiss→idle2 `[116,122]`、
  specialkickhigh→idle3 `[53,57]`）。
- **P2 动作状态/退出帧**：facedownattack/faceupattack/attacktofloor 的退出帧、
  impactstun 起始帧均改读 link 窗口（`_native_link_start_frame`）。
- **P2 pose 条件**：`oppposestand/oppposelaying/oppposestun` 改为对手动作
  `pose`（stand/laying/stun/crouch/jump），不再用状态枚举近似。
- **P2 linking_frame**：`_native_link_window_ok()` 现在要求当前帧达到
  `linking_frame` 才允许 FollowLink。
- **数据/回退**：`native_links.json` 现在写入 `source.set_sha256`；
  `grabdistance` 无数据时 fail closed（不再退回 0.7）；
  `source_state_time_for_target` 无窗口时回退动画起点 0，不再用 1.5 秒。
- 新增 `validate_p2_recovered_links.gd` 覆盖 entry_frame、收招 link 和 pose。

第二轮补充（2026-11-02）：
- `ConsumeEvents` 已按反编译语义改成“从末尾按字符串匹配并写 `+0x10=1`，
  不检查原值”。
- `blending` 帧已传入衔接函数并触发候选视觉混合；`unique` 仍是角色专属
  语义 ID（如 `grababrucelee`），候选模型没有对应 clip，暂未参与行为。
- 怒气改为数据驱动：动作 `action.rage` 正值是命中怒气增益
  （lowpunch1=5、highkick3=10），负值是特殊技消耗
  （specialpunchlowmiss/specialkicklowmiss=-66，命中动作=0），
  link 路径按该值扣费；`RAGE_MAX=100` 和 AI 的 33/66 门槛仍为原型假设。
- 反应链的 13/15/20/40、23/21/14 帧回退已改读对应的出边 link 起始帧。

仍未完全处理：`unique` 的角色专属 clip 映射；`RAGE_MAX` 与 AI 怒气
扣费。CI 新增 `godot-parse` 作业，会下载 Godot 4.7.2 对全部 GDScript
做 `--check-only` 解析；运行时 Godot 回归和真实 EXE 构建仍只能在本机
执行（候选资源和原始 APK 不在仓库内）。
