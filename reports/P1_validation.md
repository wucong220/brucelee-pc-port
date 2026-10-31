# P1 原生运行框架验收记录（2026-10-31）

## 已实际执行

- Godot 4.7.2 editor 加载检查：
  - `Godot_v4.7.2-stable_win64.exe --headless --path godot --editor --quit`
  - 退出码：0
  - 备注：日志中仅有编辑器 settings 保存路径警告，无 GDScript 解析错误。
- 14 个仓库内 Godot 验证脚本：全部退出码 0。
  - `validate_standing_combos.gd`
  - `validate_directional_combos.gd`
  - `validate_directional_input.gd`
  - `validate_special_moves.gd`
  - `validate_level2_moves.gd`
  - `validate_special_kick_low.gd`
  - `validate_special_punch_low.gd`
  - `validate_special_punch_high.gd`
  - `validate_parry.gd`
  - `validate_grabs.gd`
  - `validate_endattacks.gd`
  - `validate_reaction_push.gd`
  - `validate_stun.gd`
  - `validate_stun_heavy.gd`
- Python 单元测试（默认临时目录）：
  - `py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q`
  - 结果：`243 passed / 1 skipped`

## 未冒充为已验证

- 未新增 Windows EXE 导出验收；已有历史 Windows EXE 自检结论仍按旧记录引用，本次未重新导出。
- `smoke_test.gd` 在当前沙箱中无法创建其外部临时目录（`DirAccess.make_dir_absolute(OS.get_temp_dir())` 返回 32），因此不能在本轮声称 smoke test 已通过。
- 未实测真实手柄设备、长时间运行、真实关卡和原版逐帧对照。

## 结论

P1 的工程加载、核心战斗脚本和仓库测试面当前保持可运行；完整发行级 Windows 构建、真实设备与 smoke 环境仍待独立执行，不能把本记录当作完整 P1 验收。
