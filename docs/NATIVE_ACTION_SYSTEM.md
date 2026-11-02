# 原版动作系统：反编译结论

来源：`libdefault.so`（SHA-256 `1da7a30c…`）经 Ghidra 12.2 分析后的 C 伪代码，
本机路径 `D:\BruceLeeWork\ghidra-out`、`ghidra-out2`。本文只记录结论与地址，
不复制反编译源码，也不含原版载荷。

## 实现状态（2026-11-02）

`godot/scripts/fighter.gd` 已按这套链路重写，原型的 FIFO 攻击队列、0.52/1.35 秒
时间窗和 `_standing_combo_pending_*` 已删除：

- `_link_events`：带 `consumed` 位的输入事件队列。
- `_try_follow_links()`：每次物理更新遍历 link，做窗口/序列/条件检查；
  序列匹配从事件末尾向前扫描并跳过已消费事件。
- `_link_window_ready()`：窗口是当前动画帧区间（`CANDOBASICATTACK_WINDOWS`）。
- `_consume_link_events()`：命中 link 后标记匹配事件。
- `_begin_chained_attack()`：命中后直接切目标动画，不再排队。
- 当前动画自己的 link 优先于通用 `candobasicattacks` link
  （例如 `high_punch → high_punch2` 优先于通用 `a/a/a → high_punch`）。

验证：`validate_link_input.gd`（通用 J J J、源 link 优先、事件不重复触发）、
`validate_training_full.gd`（27 课全部通过）、`validate_move_gallery.gd`（27 招）。

旧模型的测试 `validate_attack_queue`、`validate_all_combo_queue`、
`validate_combo_timing`、`validate_standing_combos` 及依赖 pending 的
方向/特殊招测试已删除——它们验证的是被删掉的队列/时间窗语义，不再适用。


## 输入到招式的真实链路

`CFighter::UserControlUpdate`（`0x1b89c0`）每次更新依次遍历**当前招式的
link 表**（`GetActiveSetAnimation +0x100/+0x104/+0x108`），对每条 link 做四个检查：

| 检查 | 地址 | 语义 |
|---|---|---|
| `TimeWindowCheck` | `0x1b1ee0` | link 窗口是**当前动画帧区间** `[+0xcc,+0xd0]`（或按目标动画索引查表），不是“第一下按键后的时间窗” |
| `InputSequenceCheck` | `0x1b0180` | 从事件向量**末尾向前**扫描；不匹配的事件跳过；`+0x10` 非零（已消费）的匹配事件也跳过 |
| `InputStatusCheck` | `0x1b020c` | link 要求的按键**状态**必须出现在当前 keystatus 向量里（按下/松开） |
| `CheckConditions` | — | link `+0xb8` 的条件表（对手状态、怒气等） |

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

- `CBeatEmUpGame::Update` 里输入事件队列的 `+500` 过期单位（时钟/帧）尚未确认。
- link `+0xb8` 条件表的具体字段语义（`oppposestun`、`ragethird` 等）只恢复了一部分。
- `+0x2c`/`+0x34` 的“当前动画 / 当前帧”换算与 `SetAnimation` 的第 4、5 参数仍需核对。

## 结论

输入层和状态层都必须按 link 模型重写：**每个更新遍历当前招式的 link，
做 TimeWindowCheck + InputSequenceCheck + InputStatusCheck + CheckConditions，
通过后 FollowLink 并 ConsumeEvents**。在这条链路替换掉之前，任何时间窗、
队列、优先级参数都只是猜测。
