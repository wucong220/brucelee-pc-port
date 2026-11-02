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

`godot/data/move_training_catalog.json` 共 26 项，按逻辑招式分组：

- BASIC 4
- COMBO 8
- SPECIAL 4
- DEFENSE 3
- GRAB 4
- GROUND 2
- BASIC/HEAVY 1

`special_kick_low`、`special_punch_low`、`special_punch_high` 只列出命中动作，
不把 `*_miss` 当成独立招式。`grab1/grab2` 也不列 `grab*_miss` 分支。

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

PC 输入提示、木桩摆放和训练页布局都是原型选择；原版训练 UI、键位和进度规则未恢复。
