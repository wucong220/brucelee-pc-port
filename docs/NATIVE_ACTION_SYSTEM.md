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
`high_punch`、事件不重复触发）、`validate_move_gallery.gd`（27 招）、
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

`heavy` 没有原生 link，已从训练与招式欣赏目录移除（26 项），自由对战里仍是
回退攻击，等找到原生入口再处理。动画 `ordinal` 不是连招顺序
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

三段 `startup/active/recovery` 状态机和 parry 输入仍是原型实现，尚未换成
link 数据驱动。

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

### 基础攻击没有单键 link

导出的 396 条 link 中，指向 `lowpunch1` / `lowkick1` 的只有三条键的连段
（`a,b,b` / `b,d,d`），**没有单键 link**。因此 `main.gd` 里“按键直接
`request_attack` 基础招”的回退仍然是原型机制，不是从 link 表读出来的；
在拿到原生默认攻击入口之前，这部分继续标为 prototype。

`CFighter::BasicUpdate`（`0x1b8330`）的完整反编译也确认了这一点：它只推进
动画时钟、按帧区间记录当前帧、处理 `+0xf0/+0xf4` 的待执行 link、更新朝向/
位移，**没有任何攻击按键分支**。`+0xf0/+0xf4` 只在 `BasicUpdate` 里执行
`SetAnimation`，而这些带 `linking_frame` 的 link 目标几乎都是 `idle` 系列
（回站立），不是攻击起手。

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
`fighter+0x1c` 选择，不是三步。当前移植把导出的 3 项当作步骤匹配，是已知近似；
`+0x1c` 的写入点尚未在 139 个 `CFighter` 反编译函数中出现，详见
`INPUT_CONFIG_FINDINGS.md`。

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
