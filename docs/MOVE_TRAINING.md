# 招式训练（PC 原型）

## 入口

主菜单：

```text
VS FIGHT
GROUND TRAINING
MOVE TRAINING
QUIT GAME
```

`MOVE TRAINING` 是独立于 `GROUND TRAINING` 的 Bruce 玩家招式训练页。

## 规则

- 只训练 Bruce 玩家招式；不使用 Brick 招式。
- 每次只显示当前一项。
- 当前项未成功前不能进入下一项；没有跳过键。
- 训练木桩不会主动攻击，血量锁定，不参与正式对战计分。
- 普通攻击必须真实命中木桩才算成功；miss 分支不算。
- parry 必须真实吸收木桩攻击；endattack 以真实收招事件为准。
- `R` 重试当前项，`Esc` 退出回主菜单。
- 进入前有起点选择：上下选择任意一项，Enter 从该项开始；进度不保存。

## 目录

`godot/data/move_training_catalog.json` 共 25 项（第 14/17 轮移除了无原生 link 的 parry_low 与 heavy），按逻辑招式分组：

- BASIC 4
- COMBO 8
- SPECIAL 4
- DEFENSE 3
- GRAB 4
- GROUND 3（含 faceupattack）
- BASIC/HEAVY 1

`special_kick_low`、`special_punch_low`、`special_punch_high` 只列出命中动作，
不把 `*_miss` 当成独立招式。`grab1/grab2` 也不列 `grab*_miss` 分支。

## 输入队列

每个攻击键现在都会落地成一次实际攻击，不再有“第二下 J 被吞掉”的空输入：

- 当前攻击进行中时，后续按键进入队列
- 连段目标排在已经排队的普通攻击之后
- 目标招仍然是连段的最后一击
- 目标命中后才推进训练项
- `D` 没有独立基础动作，PC 原型 fallback 为 `kick`，避免单独按 D 无反馈

例如 `A/A/A` 现在会依次产生三段实际攻击，最后一段才是 `HIGH PUNCH`；不是
“第一段 + 隐藏目标”两段。

## 判定事件

- `combat_hit`：普通攻击、连段、special 命中、grab、地面攻击、parry counter
- `parry_succeeded`：parry high/low 吸收
- `attack_started`：endattack1/2 收招事件

训练页监听真实 fighter 信号，不按原始按键直接判定；按错键不会推进。

## 测试

- `tests/test_move_training_catalog.py`：26 项、唯一 ID、schema、miss 分支排除。
- `godot/tests/validate_move_training.gd`：
  - 菜单进入并隐藏 HUD
  - 起点选择
  - 错误招式不推进
  - 正确命中后锁定并推进
  - 跳到自选起点
  - 队列版 HIGH PUNCH 实际命中后推进
- `godot/tests/validate_attack_queue.gd`：`A/A/A` 与 `B/D/D` 每一下都产生攻击，目标最后。
- `godot/tests/validate_all_combo_queue.gd`：24 条已恢复站姿连段逐条验证没有吞键。

PC 输入提示、木桩摆放和训练页布局都是原型选择；原版训练 UI、键位和进度规则未恢复。
