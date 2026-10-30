# Windows PC 原型输入层

`godot/scripts/prototype_controls.gd` 集中注册当前原型使用的 16 个动作。
键盘和手柄通过同一套 `InputMap` 动作进入战斗、暂停菜单和主菜单。这里的
映射是 PC 可玩性实现，不是原版 Android 物理键位或输入时序已经恢复的证据。

## 默认映射

| 动作 | 键盘 | 手柄 |
|---|---|---|
| 移动 | A/D/W/S | 左摇杆或十字键 |
| 虚拟键 a / 快拳 | J | A |
| 虚拟键 b / 踢击 | K | X |
| 虚拟键 c / 重击 | L | Y |
| 虚拟键 d | U | B |
| 格挡 | Shift | LB/RB |
| 重开 | R | Back |
| 训练切换 | F2 | L3/MISC1 |
| 暂停或恢复 | Esc | Start |
| 菜单选择 | 方向键或 W/S | 十字键 |
| 菜单确认 | Enter/J | A |
| 菜单返回 | Esc | B/Start |

动作名使用 `prototype_` 前缀。注册函数只补充不存在或尚无事件的动作，避免
静默替换后续用户重绑定。菜单优先处理菜单动作并设置输入已处理；因此暂停时
手柄 A 只确认菜单，不会穿透成拳，B 也不会穿透成虚拟键 d。

## 验证范围

`godot/tests/validate_controller_input.gd` 验证：

- 16 个动作及左摇杆、十字键和关键手柄按钮均已映射。
- 移动和格挡动作进入 `PortFighter`。
- 手柄 A、Back、Start、B 和 MISC1 经真实 Godot 输入派发路径改变状态。
- 暂停菜单冻结玩法，十字键导航、A 确认和 B 恢复有效。
- 主菜单用十字键和 A 选择 `VS FIGHT`。

命令：

```powershell
& $GodotExe --headless --path godot `
  --script res://tests/validate_controller_input.gd
```

## 尚未验证

- XInput、DualShock/DualSense 和各类兼容手柄的真实设备名、轴方向、按钮编号。
- 热插拔、多手柄同时连接和系统控制器映射变化。
- 玩家自定义重绑定、配置持久化、辅助功能组合键和震动。
- 原版动作缓冲、取消窗口和 Android 物理键位。

## 2026-10-30 验证记录

Windows、Godot 4.7.2 stable，以下命令均退出码 0：

```powershell
& $GodotExe --headless --editor --path godot --quit
& $GodotExe --headless --path godot --script res://tests/smoke_test.gd
& $GodotExe --headless --path godot --script res://tests/validate_controller_input.gd
& $GodotExe --headless --path godot `
  --script res://tests/validate_prototype_menu.gd -- $BruceGlb $BrickGlb
py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q
git diff --check
```

源码 controller 测试输出
`CONTROLLER_INPUT_VALIDATION={"actions":16,...}`，菜单测试输出
`PROTOTYPE_MENU_VALIDATION={...,"pause_froze_gameplay":true,...}`。将源码导出到
临时 PCK 后，同一 controller 与菜单测试也各以退出码 0 通过。Python 为 223 项
通过、1 项跳过。这个记录证明合成手柄事件在源码和打包脚本中的输入派发、状态
变化及菜单暂停路径有效，不代表真实手柄或原版手感已经验收。
