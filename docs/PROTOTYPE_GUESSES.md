# 原型自创规则清单（无原版证据）

本文只列 **PC 原型自己定、没有原版静态证据** 的规则。原版数据已恢复的字段
（帧数、伤害、攻击半径、impact、reaction return frame、link 序列）不在此列。
每条的“状态”只有三种：`证据`（原生指令/数据已核对）、`候选`（数据存在但
运行时语义未闭合）、`自创`（原型决定，原版无证据）。

## 输入与连段

| # | 规则 | 位置 | 状态 | 说明 |
|---|---|---|---|---|
| 1 | `J/K/L/U → a/b/c/d` | `prototype_controls.gd` | 自创 | 原版 `input.config` 的虚拟键到设备码映射未闭合；PC 键位是原型选择 |
| 2 | `D` 无匹配时回退成 `kick` | `main.gd::_handle_fighter_attack_input` | 自创 | 已删除（第 16 轮）：基础攻击改为单键 link，匹配不到就什么都不做 |
| 3 | 连段窗口 0.52s/1.35s | `fighter.gd` `COMBO_MAX_GAP_SECONDS` / `COMBO_MAX_TOTAL_SECONDS` | 已删除（第 1/5 轮） | 已换成原生 link 帧窗口 + 500ms 事件过期 |
| 4 | 连段优先级“后完成者替换” | `fighter.gd::record_standing_combo_press` | 已删除（第 1 轮） | 改为按原生 link 原始顺序遍历 |
| 5 | 每次按键入队、目标排最后 | `fighter.gd::request_attack_or_queue` / `_try_begin_pending_standing_combo` | 已删除（第 1 轮） | 已换成 `InputSequenceCheck → FollowLink → ConsumeEvents` 事件消费模型 |
| 6 | 招架 = 0.5s 内按三次 Shift | `fighter.gd::record_parry_press` | 已删除（第 14 轮） | 改为原生 `candocounter` link：下+右，`countertime`+`ragethird`；吸收窗口读 `impactable` 组（parryhigh 第 30 帧前） |
| 7 | 地面攻击输入 `aaa/abb/bcc/bdd`、`K,L,L`/`K,U,U` | `fighter.gd` 地面序列 / `main.gd` | 已删除（第 11 轮） | 改为 `facedownidle/faceupidle` 的直接 link（单键） |
| 8 | Heavy 作为无来源独立招式 | `fighter.gd` `heavy` 元数据 | 已删除（第 17 轮） | 原注释即写 "No recovered fighting-set mapping for this prototype attack yet"；数据里没有 heavy，已从代码、AI、训练、测试中移除 |
| 9 | 抓取距离 0.7 | `PROTOTYPE_GRAB_DISTANCE` | 部分证据（第 19 轮） | link 条件 `grabdistance` 改用动作 `attack.grab_distance`（grab1=70、endattack1=150，按 source→world 换算）；常量只作缺数据回退 |
| 10 | 怒气消耗 33/66 | `SPECIAL_RAGE_COSTS` / `PARRY_RAGE_COSTS` | 部分修复（第 21 轮） | 原生 link 路径不再扣怒气（`ragethird`/`rage2thirds` 只做门槛）；AI 分支仍按原型扣费 |

## 战斗数值与判定

| # | 规则 | 位置 | 状态 | 说明 |
|---|---|---|---|---|
| 11 | `prototype_push` | `fighting_set_low_attacks.json` 字段 | 自创 | 原版 push 未映射，现用原型值 |
| 12 | 命中距离公式与候选缩放 | `fighter.gd::attack_reach_world` | 证据 + 候选 | 公式来自原生；`173.416 → 1.8` 的候选缩放是 CANDIDATE |
| 13 | hitstun/blockstun 时长 | `fighter.gd` reaction 映射 | 证据 | 来自 `brucelee.set` reaction return frame |
| 14 | AI 出招/格挡决策 | `main.gd` AI 分支 | 自创 | 原型行为，不是原版 AI |
| 15 | 摄像机取景 | `main.gd::_update_fight_camera` | 自创 | 注释已写 "prototype framing choices" |

## 训练与欣赏

| # | 规则 | 位置 | 状态 | 说明 |
|---|---|---|---|---|
| 16 | 25 课目录、起点选择、成功条件 | `move_training_catalog.json` / `move_training.gd` | 自创 | 训练页本身是 PC 原型功能 |
| 17 | `_prime_source_attack` 固定 `state_time = 1.5` | `move_training.gd` | 已修复（第 8/13 轮） | 现在按目标/入口 link 的帧窗口计算 `state_time` |
| 18 | 训练时每帧强制木桩状态 | `move_training.gd::_process` | 自创 | 为了让中间攻击不破坏 special/grab 条件 |
| 19 | 欣赏模式直接写 `state`、强制 `request_attack` | `move_gallery.gd` | 保留为预览功能 | 欣赏模式不是输入路径，只是逐招播放；真实对战/训练已走原生 link |
| 20 | 主菜单/暂停/训练/欣赏界面 | `prototype_menu.gd` 等 | 自创 | PC 原型 UI，不是原版菜单 |

## 已有原版证据、原型后来照做的部分（第 1–18 轮已落地）

| 原版机制 | 原生证据 | 现状态 |
|---|---|---|
| `CLinkDescr::GetKeySequence` + `InputSequenceCheck` 反向扫描、跳过不匹配事件 | `docs/INPUT_CONFIG_FINDINGS.md`，`0x1a0180–0x1a0208` | 已实现；序列按输入布局索引 1 选择，窗口是当前动画帧区间 |
| 通过后 `FollowLink`，再 `ConsumeEvents` 标记 `+0x10` | `0x1a8a40–0x1a8b14` | 已实现，FIFO 队列已删除 |
| `CBeatEmUpGame::Update` 按最后事件 `+500` 批量过期 | `0x17c1d8–0x17c294` | 已实现 500 毫秒批量过期（`GetCurrentMili` 来源已闭合） |
| `CStateManager::PreUpdate/PostUpdate`、`SetState` | `docs/FIGHTING_SET_FINDINGS.md` | 仍未接入；目前是自写相位状态机（帧边界来自 `damage_time`） |

## 第二轮审计（反编译之后新增）

以下是在 Ghidra 反编译 `UserControlUpdate/InputStatusCheck/TimeWindowCheck/FollowLink`
之后，才确认属于“原型抽象”而不是原版机制的部分。

| # | 规则 | 位置 | 状态 | 说明 |
|---|---|---|---|---|
| 21 | `startup/active/recovery` 三段相位 + `state_time` 计时 | `fighter.gd` 全状态机 | 部分证据（第 25 轮核对） | 全部攻击的帧边界现在由 `damage_time` 自动算出并校验；无伤害的 miss/parry 用出边 link 窗口（如 parryhigh `[9,10]`、specialkicklowmiss `[14,16]`）；`tests/test_attack_phase_windows.py` 会拦截任何手填漂移。相位命名/切换仍是移植结构，原版是纯动画帧推进 |
| 22 | 每帧按对手位置重算 `facing`、直接写 `rotation.y` | `fighter.gd::_physics_process` | 部分证据（第 20 轮） | 转向现在受动作 `facing` 窗口约束（如 grab1 `[0,1]`、endattack1 反向 `[1,0]` 视为锁定）；`rotation.y` 仍每帧同步到当前 facing，视觉层与原版未完全闭合 |
| 23 | 世界缩放 `1.8 / 173.4159` | `CANDIDATE_SOURCE_HEIGHT` / `CANDIDATE_HEIGHT` | 候选 | 数值来自候选模型高度，不是原版场景缩放 |
| 24 | 根位移 raw Y 逐 clip 符号映射 | `fighter.gd` 注释 "Prototype only: per-clip first-Y sign" | 自创 | 原版 root motion 语义未闭合 |
| 25 | `_attack_hit_landed` / `_attack_connected` / `_multi_impact_applied` 簿记 | `fighter.gd` | 自创 | 原版靠 impact 帧与状态，不存在这些布尔量 |
| 26 | 受击反应链（hitstun→blockstun→返回状态） | `fighter.gd::_advance_timed_states` | 部分证据（第 27 轮） | 受击/格挡反应已从原生 reaction link 生成（26+10 条）并优先选用；stun/stun2/stunfall 的**时长**已读原生 link 窗口，且状态顺序由 `_advance_stun_state` 拼接，未接 CStateManager |
| 27 | 三局两胜、KO、回合重置 | `main.gd` | 自创 | 原型规则 |
| 28 | 音效映射 | `main.gd::_play_hit_audio` | 自创 | 只把候选文件按动作名对上，不是原版事件映射 |
| 29 | 双方初始站位、摄像机取景 | `main.gd` | 自创 | 注释已写 prototype framing |
| 30 | `record_virtual_press` 的地面四条序列 | `fighter.gd` | 已删除（第 11 轮） | 改为原生地面 link |
| 31 | 招架 = 0.5 秒内三次 Shift | `fighter.gd::record_parry_press` | 已删除（第 14 轮） | parry 改走 link + `InputStatusCheck`/`countertime` |
| 32 | Gallery 每招播放时长 = `startup+active+recovery+0.9s` | `move_gallery.gd::_duration` | 自创 | 原版按动画长度和 link 推进，没有这种定时切招 |
| 33 | `_try_special_chain` + `SPECIAL_CHAIN_WINDOW/MISSES` + 提前收招帧 | `fighter.gd` | 已删除（第 21 轮） | miss→hit、parry→parry_attack 都由原生空序列 link 完成；训练/招架测试仍全过 |

## 反编译后确认“该做但没做”的原版机制

| 机制 | 原生位置 | 原型现状 |
|---|---|---|
| `InputStatusCheck`：link 要求的方向键**按住状态** | `0x1b020c` | 完全没实现，只在按键瞬间采样一次方向 |
| `CheckConditions`：link `+0xb8` 条件表全量 | `UserControlUpdate` 内调用 | 只实现了 `oppposestun`、怒气等少数条件 |
| link `+0xe0` 非零时消费**整个事件向量** | `UserControlUpdate` | 没实现 |
| `FollowLink` 按**目标动画索引**延迟 link（`+0xf0/+0xf4`） | `0x1b8040` | 用 FIFO 攻击队列替代 |
| `TimeWindowCheck` 的动画帧窗口 | `0x1b1ee0` | 用时间窗替代 |

## 结论


真正“瞎搞”的核心不是数值，而是 **输入与状态的两条主路径**：

1. 用自创的时间窗 + FIFO 队列，替代原版 `InputSequenceCheck/FollowLink/ConsumeEvents`。
2. 用自写 state 赋值，替代 `CStateManager/SetState` 的统一状态进入。

数值（push、rage、grab 距离、AI、摄像机）是次要问题，可以逐步用证据替换；
上面两条不换，动作系统会一直是“看起来像，但手感不对”。
