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

## 站立基础连段

站立攻击会把 `J/K/L/U` 转成抽象 `a/b/c/d`。原型记录从首键起算最多
0.5 秒内的三条输入，并在当前攻击的来源帧进入相应
`candobasicattacks` 窗口时转换：

- `AAA -> highpunch1`
- `ABB -> lowpunch1`
- `BCC -> highkick1`
- `BDD -> lowkick1`

已实现来源窗口为 lowpunch 第 `[22,69]` 帧、lowkick 第 `[31,86]` 帧、
highpunch 第 `[17,101]` 帧和 highkick 第 `[33,73]` 帧。目标 clip 未加载时
转换保持关闭，普通攻击路径继续工作。0.5 秒期限是 PC 原型选择；
`candobasicattacks` 的 84 个成员、原版输入超时、链接优先级、blending 和
Android 物理键位尚未恢复。源值及限制见
[`reports/basic_attack_combo_evidence.json`](../reports/basic_attack_combo_evidence.json)。

已匹配但尚未执行的连段绑定到当时那次攻击：攻击结束、切到别的动作、受到命中
或格挡、以及 Heavy 攻击都会取消它，因此旧输入不会在后续攻击里突然生效。
Heavy 没有已恢复的来源窗口，不缓存连段输入。同一动作的连段（`ABB -> lowpunch1`、
`BDD -> lowkick1`）即使开启 `BRUCELEE_CANDIDATE_VISUAL_BLENDING=1` 也会从第 0 帧
重播，避免逻辑已重开而画面停在上一段。两条连段同时匹配时，后完成匹配的那条
替换先前的待执行项；这是原型选择，原版 link 优先级尚未恢复。

按住格挡时，攻击请求本来就会被拒绝，因此格挡期间也不接受连段输入；在两次按键
之间抬起格挡会清空未完成的输入历史，避免格挡中的按键变成后续连段的首键。

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
