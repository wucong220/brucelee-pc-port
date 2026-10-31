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

加载仓库外 30 段候选时，另有四条带方向修饰键的已恢复链接：

| 输入（原型） | 目标 |
|---|---|
| 上 + J，然后 朝向对手 + J 两次 | `highpunch3` |
| 下 + J，然后 背向对手 + K，再 背向对手 + J | `lowpunch3` |
| 下 + K，然后 背向对手 + U 两次 | `lowkick3` |
| 上 + K，然后 朝向对手 + L 两次 | `highkick3` |

方向修饰键是 PC 原型映射：`W/S` 产生上/下，`A/D` 相对角色朝向换算成
朝向/背向对手的 `in/out`。每一步必须与按键集合完全一致，因此普通 `AAA`
不会吞掉带方向的输入。四条新攻击的源窗口分别为 `[21,85]`、`[33,81]`、
`[26,56]`、`[30,51]`；`highpunch3` 和 `highkick3` 的 `hard/high/fromright`
impact 使用已恢复的 `impacthardrighthigh -> all_impct_hard_rht_high`，
第 26 帧回到 `faceupidle`。这些仍是候选运行时行为，不是 Android 物理键位、
原版输入时钟或逐帧视觉验收。

必杀技（原型怒气）：本地 31 段候选加载后，`背向+B → 朝向+C → 朝向+C`
触发 `specialkickhigh`（`m01_kck_front_step`，57 帧、伤害 12、攻击半径 115、
`lleg/high/hard/frontal`、命中帧 `[11,15]`、第 53–57 帧回 `idle3`）。
没有 `背向+B` 这一步的同一按键模式不会选中必杀（原型用背向起手代表原版
`stepback`）。原型怒气槽 0–100：每次未格挡命中 +10，`ragethird` 门槛 33，发动扣 33；
原生怒气刻度与获取规则未恢复。`hard/high/frontal` 的专用受击动画
`all_impct_hard_frnt_high` 已放进仓库外 50 段候选；加载该候选时可播放，
缺 clip 时仍保持 fail-closed（伤害生效、不伪造受击动作）。

必杀技下段踢（原型）：`背向?不，左侧+B → 朝向+C → 朝向+C`（PC 原型用
`left` 代表原版 `stepleft`，`in` 代表 `pressright`）在怒气 `rage2thirds`（≥66）
时进入 `special_kick_low_miss`（`m01_sp_kick_low_fail`，50 帧）。若第 14–16 帧内
对手在 0.62 世界单位的原型抓取距离内、站立且未格挡，则切到
`special_kick_low_hit`（`m01_sp_kick_low`，39 帧，伤害 15、攻击半径 45、
`larm/high/hard/frontal`）；否则保持 miss 并回 idle。`hard/high/frontal`
专用受击动画在 50 段候选加载时可播放，缺 clip 时仍 fail-closed。

抓取后的 `endmove` / 收招（候选）：普通攻击命中或抓取成功、对手处于受控/硬直
且在 0.62 距离内时，`上+朝向+B → A → A` 触发 `endattack1`
（`m01_end_attack_01`，377 帧），`上+朝向+A → C → C` 触发 `endattack2`
（`m01_end_attack_02`，235 帧）。两招在原版属于 `attack + endmove`，不是独立伤害技；
`brucelee.set` 的 impact 伤害为 **0**，因此只播放收招动画，不添加伤害。
原版要求 `oppposestun + grabdistance`；原型用“命中/抓取后的受控状态 + 距离”近似，
不声称是完整眩晕状态。

眩晕原型（候选）：普通 high/low 攻击使对手 healthzero 时，先播放对应
`all_impct_light_frnt_high/low` 的 14 帧 `impactstun`，再进入
`stun → stun2 → stunfall → faceupko`；`stun`/`stun2` 期间可被 endmove 使用。
`hard` 在 `stun/stun2` 且命中未格挡时才会走 `all_impct_hard_frnt_high → stunimpact → faceupko`；
普通 hard frontal 命中不使用这条眩晕链。
这些状态、帧数和 `oppposestun` 等时序仍是 prototype，不是原版逐帧还原。

低段格挡反击（PC 扩展）：与 `parry_high` 共用同一套“按住防御 + 下+朝向 ×3”
输入，但对手来招高度为 `low` 时触发 `parrylow`（动画 `m01_kick_low_02`，27 帧，
无伤害，消耗 30 怒气）。原版 `brucelee.set` 没有指向 `parrylow` 的 link；这里按用户
要求把它作为 `parryhigh` 的低段对应实现，属于 PC 原型扩展，不声称是原版可触发路径。

抓取（原型两段式）：基础 `A` 后按 `左+A → A → A` 进入 `grab1_miss`，
第 8–9 帧若对手在 0.62 世界单位内、站立且不格挡则链到 `grab1`；
基础 `B` 后按 `左+B → C → C` 进入 `grab2_miss`，条件相同时链到 `grab2`。
两段都消耗 66 怒气。`grab1miss/grab2miss` 的 `m02_grab_01` 属于 Ken 骨架，
已用 `retarget_animation_binding.py` 把 60 个骨骼轨道和 body/hair 对象轨道
重定向到 Bruce 骨架，作为实验性跨骨架候选打包；不能声称与原版骨骼语义等价。
`grab1` 分三段 6/5/9（共 20），`grab2` 分两段 5/15（共 20）。


格挡反击（原型方向输入）：按住防御，在对手 `startup/active` 时用
`下+朝向` 连续三次（0.5 秒内，每次按下沿）触发 `parry_high`
（`m01_parry_high`，62 帧，无伤害），消耗 33 怒气。第 9–10 帧自动切到
`parry_attack`（复用 `m01_pnch_high_03`，85 帧，伤害 10、攻击半径 75、
`larm/high/hard/frontal`，窗口 `[4,8]`）。原版是纯方向 `down+right×3`，
PC 原型增加了“按住防御且对手正在攻击”的前置条件。

必杀技上段拳（原型多点命中）：第 3 段攻击后，`上+A → 上+A → 上+A`
（原版 `pressleft+pressright+A`，PC 用上+A×3 代表双手蓄力）在 `rage2thirds`
时进入 `special_punch_high_miss`（`m01_sp_pnch_high_fail`，122 帧，无伤害）。
第 6–7 帧内对手在 0.62 世界单位、站立不格挡则切到 `special_punch_high_hit`
（`m01_sp_pnch_high`，80 帧），三段伤害窗口 `[3,7]` 4、`[17,22]` 4、`[43,49]` 13，
总计 21；最后一段 `hard/high/frontal` 精确反应为 `impacthardfronthigh`。
发动扣 66 怒气。

必杀技下段拳（原型）：第 3 段攻击后，`下+A → 背向+A → 背向+A`（PC 原型把原版 pressright 折叠为背向）
在 `rage2thirds`（≥66）时进入 `special_punch_low_miss`（`m01_sp_pnch_low_fail`，33 帧，无伤害）。
第 8–9 帧内对手在 0.62 世界单位、站立不格挡则切到 `special_punch_low_hit`
（`m01_sp_pnch_low`，178 帧，伤害 15、攻击半径 45、`larm/high/hard/frontal`）。
`hard/high/frontal` 的精确反应是 `impacthardfronthigh`；受击 clip 可解码但尚未打包，
因此反应动作 fail-closed。发动扣 66 怒气。

普通攻击第 2 段（连段等级 1）：在基础 `A/A/A`、`A/B/B`、`B/C/C`、`B/D/D`
命中后，再用同一按键序列会转到对应第 2 段（`high_punch2`、`low_punch2`、
`high_kick2`、`low_kick2`）。原型用当前攻击种类表示 `combolevel1`；
原版 `keystatus` 的 down pressed/released 尚未复刻。`low_punch2` 的动画
`m01_pnch_low_02` 现在可以安全解码：它的第三个 approximation root 的首节点字为 0
且 root 之后没有放树的余地，表示该近似层为空（channel array 存在但没有节点），
跳过它不会丢弃任何节点数据。因此四段第 2 攻击全部可用。
第 3 段仍从第 2 段按原方向序列衔接。

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
之间抬起格挡会清空未完成的输入历史与已匹配的待执行连段，避免格挡中的按键变成
后续连段的首键。格挡按下事件会立即取消待执行连段，不等下一物理帧，因此快速
按下再松开也有效；攻击输入事件到达时会重新读取当前格挡状态，而不是使用上一
物理帧的快照。

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
