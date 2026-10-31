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
- `smoke_test.gd` 在隔离的 `smoke_root/godot` 副本 + 仓库外临时目录下实际通过：
  - `EXIT=0`
  - 输出 `PROTOTYPE_VALIDATION={"blocked_kick_target_health":99.4,"blockstun_frames":12,"kick_hitstun_frames":13,"ko_and_restart":true,"punch_hitstun_frames":14,"punch_target_health":95.0}`
  - 隔离布局用于满足 path-guard 的 repository fixture 与 external temp 边界。
- PCK 打包在隔离 `smoke_root/godot` 中实际成功：
  - `Godot_v4.7.2-stable_win64.exe --headless --path <smoke_root>/godot --export-pack "Windows Desktop" <dist>/DragonWarrior_PC_Prototype.pck`
  - 产物：532,748 字节，SHA-256 `c48237afe11b0895c36a5b5ffb9784825603634762e6ae6d37c8ec4e10e0f5cb`
  - 产物位于仓库外，不提交。
  - PCK 启动自检：`Godot_v4.7.2-stable_win64.exe --headless --main-pack <dist>/DragonWarrior_PC_Prototype.pck --quit`，退出码 0；日志中的菜单背景缺失警告不阻断启动。
- 候选音频映射回归：使用仓库外音频根运行 `validate_candidate_audio.gd`，输出 `CANDIDATE_AUDIO_VALIDATION=passed`，退出码 0；仓库内音频根会被 path guard 拒绝。
- Windows EXE 导出（隔离 `smoke_root/godot`，Godot 4.7.2 导出模板已安装到 APPDATA）：
  - 产物：`dist/DragonWarrior_PC_Prototype.exe`，109,127,680 字节，SHA-256 `4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668`
  - 同时生成 `DragonWarrior_PC_Prototype.pck`，533,804 字节
  - 启动自检：`DragonWarrior_PC_Prototype.exe --headless --quit`，退出码 0；日志仅有未布置的候选音频/HUD/菜单背景资源缺失错误，不是启动失败
  - EXE 内置确定性自检（使用 `BRUCELEE_EXPORT_SELF_TEST=1`、candidate47、Brick candidate7 和对应 texture roots）：退出码 0，输出 `EXPORT_SELF_TEST={"candidate_textures_loaded":true,"candidate_visual_height":1.8,"candidate_world_height":1.55666851997375,"candidate_world_min_y":-0.00497347116470337,"internal_path_rejected":true,"opponent_candidate_loaded":true,"opponent_idle_clip":"m03_idle_01","opponent_texture_reason":"","opponent_textures_loaded":true,"punch_hitstun_frames":14,"punch_target_health":95.0,"reaction_clip":"all_impct_light_frnt_mid"}`

## 未冒充为已验证

- 历史 Windows EXE 自检结论仍按旧记录引用；本次新增的是隔离副本导出结果。
- 本次已补齐 Godot 4.7.2 导出模板并完成隔离副本 EXE 导出；EXE 启动日志中的候选音频/HUD/菜单背景错误仅表示这些外部资源未布置到运行目录，未冒充为完整游戏资产验收。
- 在当前 C 盘 worktree 的默认位置直接运行 `smoke_test.gd` 时，`_path_guard_check()` 的 `.path-guard-fixture-*` 创建失败；因此上面的 smoke 通过结果只对应隔离 `smoke_root` 副本，不能宣称任意工作目录都通过。
- 未实测真实手柄设备、长时间运行、真实关卡和原版逐帧对照。

## 结论

P1 的工程加载、所选 14 个核心战斗脚本、隔离布局下的 smoke test 和本地 Python 测试面当前保持可运行；完整发行级 Windows 构建、真实设备、全部 41 个 validate 脚本和默认 worktree 的 smoke 环境仍待分别确认，不能把本记录当作完整 P1 验收。
