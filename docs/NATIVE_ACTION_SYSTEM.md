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

**训练（2026-11-02 第 8 轮）**：27 课的前置和按键改成从 `native_links.json`
索引 1 的序列自动生成；`special_kick_high` 用 `stepback` 前置、
`special_kick_low` 用 `stepleft` + miss→hit 自动 link。`validate_training_full`
目前通过 1–14，15 起失败：`specialpunchlowmiss` 的 link 需要三键
`out,right,a` 才能匹配，但同一帧里 `highpunch1` 的单键 `a` link 在全局顺序里
更靠前，会先把 `a` 消费掉。原版是按**当前动画自己的 link 表**扫描，该表可能
不包含低阶 link；这份表的构建/排序规则还没恢复，所以 15 起先停住，不靠自定优先级硬修。

三段 `startup/active/recovery` 状态机、地面攻击和 parry 输入仍是原型实现，
尚未换成 link 数据驱动的状态进入。

旧模型的测试 `validate_attack_queue`、`validate_all_combo_queue`、
`validate_combo_timing`、`validate_standing_combos` 及依赖 pending 的
方向/特殊招测试已删除——它们验证的是被删掉的队列/时间窗语义，不再适用。


## 输入到招式的真实链路

### 第三轮补充：移动动作也是 link 来源

`_current_action_name()` 现在在站立状态返回当前移动动作名（`stepback` /
`stepfwd` / `moveleft` / `moveright`）。原生数据里 `specialkickhigh` 的 link
来源就是 `stepback`（`from: stepback`，`ragethird`），所以不返回移动动作名时
这招永远无法按原生输入触发。

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
