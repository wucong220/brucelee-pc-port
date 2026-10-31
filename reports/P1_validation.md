# P1 原生运行框架验收记录（2026-10-31）

## 代码版本与执行环境

- 本地 Windows 工作树基线：`aa0ea49`（PR #118 的代码基线）
- Godot：4.7.2 stable Windows x64，headless
- Python：Windows `py -3.12`
- 下方本地 Godot/Python 结果只对应上述本地基线；GitHub Actions 是独立环境，不能当作同一记录的本地复跑。

## 已实际执行

- Godot 4.7.2 editor 加载检查：
  - `Godot_v4.7.2-stable_win64.exe --headless --path godot --editor --quit`
  - 退出码：0
  - 备注：日志中仅有编辑器 settings 保存路径警告，无 GDScript 解析错误。
- 本轮选定的 14 个核心战斗 Godot 验证脚本（`godot/tests` 共有 41 个 `validate_*.gd`，这里不是全部脚本的全集）：全部退出码 0。
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
- Python 单元测试（本地默认临时目录）：
  - `py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q`
  - 结果：`243 passed / 1 skipped`
- GitHub Actions（独立环境，Run #380，commit `f2090c9`）：Python workflow SUCCESS，247 tests / 246 passed / 1 skipped；该 workflow 没有执行 Godot 验证脚本。

## 未冒充为已验证

- 未新增 Windows EXE 导出验收；已有历史 Windows EXE 自检结论仍按旧记录引用，本次未重新导出。
- `smoke_test.gd` 本轮未通过验证：`_path_guard_check()` 在 `DirAccess.make_dir_absolute(repository_fixture)` 处失败；源码使用带 token 的 `.path-guard-fixture-*` 目录（不是 `OS.get_temp_dir()` 本身）。当前只能确认该 repository fixture 创建失败，具体环境原因尚未确认，不能据此断言沙箱权限或其他机制。
- 未实测真实手柄设备、长时间运行、真实关卡和原版逐帧对照。

## 结论

P1 的工程加载、所选 14 个核心战斗脚本和本地 Python 测试面当前保持可运行；完整发行级 Windows 构建、真实设备、全部 41 个 validate 脚本和 smoke 环境仍待独立执行，不能把本记录当作完整 P1 验收。
