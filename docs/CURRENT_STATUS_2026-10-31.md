# 2026-10-31 当前移植状态（续接用）

- 工作树：`C:\Users\Lenovo\.codex\worktrees\prototype-menu\李小龙`
- 分支：`codex/combat-next`
- PR #96 的当前 HEAD：见 PR 页面（本文件不静态记录会变化的提交号）
- 记录本文件时的代码基线：`bb7eea6`（PR #95 的 HEAD；远端 main 已包含 #93/#94/#95 合并，PR #95 merge commit 为 `36cd24a`）

## 测试口径

- 本地工作树 `bb7eea6` + candidate48：13 个 Godot 套件 exit 0，Python 243 passed / 1 skipped（默认 TEMP）。
- PR #96 的 GitHub Actions 实际结果（在 92fcfb8 上执行，Run #318）：Python workflow SUCCESS，**247 total / 246 passed / 1 skipped**；GitHub Actions 未执行 Godot 测试。
- 本地 Godot 套件：`validate_standing_combos`、`validate_directional_combos`、`validate_directional_input`、`validate_special_moves`、`validate_level2_moves`、`validate_special_kick_low`、`validate_special_punch_low`、`validate_special_punch_high`、`validate_parry`、`validate_grabs`、`validate_endattacks`、`validate_reaction_push`、`validate_stun`。
- 执行方式：`Godot_v4.7.2-stable_win64.exe --headless --path godot --script res://tests/<suite>.gd -- <candidate.glb>`；`validate_reaction_push` 不需要候选参数。
- stun/endmove 的 48 段候选：`D:\BruceLeeWork\bruce_candidate_48_hair.glb`，4,087,860 字节，SHA-256 `d59e91193bdc30af1b3240d78cb32bb1113a405f28557fa749ae68175cbe2b7b`。

## 已完成的招式/战斗项

- 基础 4 招、方向 4 招、第 2 段 4 招
- `specialkickhigh/low`、`specialpunchlow/high`
- `parryhigh → parryattack`
- `parrylow` 作为 `parryhigh` 的低段 PC 扩展
- `grab1miss/grab2miss → grab1/grab2`（`m02_grab_01` 从 Ken 骨架实验性重定向）
- `endattack1/2` 作为 endmove/收招动作，零伤害
- `stun → stun2 → stunfall → ko` 候选状态（48 段候选，`all_stunned`）
- `endattack1/2` 可从 prototype stun/stun2 进入
- 三个 light frontal reaction 的 source depth → prototype forward push

## 明确边界

- `parrylow` 原版没有 link，当前是用户指定的 PC 原型扩展
- `endattack1/2` 原始 impact 伤害为 0，只播 endmove 动画
- 跨骨架 `m02_grab_01` 是实验性映射，不声称骨骼语义完全等价
- reaction push 的轴向/符号与 `oppposestun` 精确时序仍是 prototype，非原版逐帧还原
- `all_stunned` 的 55–61 帧精确转换窗口尚未恢复；当前按 61/61/79 帧推进
- `stun` 状态目前不接受后续 hit 的 `impactsfromstun` 反应，保持 fail-closed
- `ko` 是终止状态但没有对应候选动画映射；`validate_stun.gd` 验证的是进入 `ko` 状态，不是 `ko` 动画播放
- `endattack1/2` 不只从 `stun/stun2` 进入；普通 `hitstun` 命中后也可进入，当前实现两者都允许

## 下一个可验证项

1. `impactsfromstun` 的 light/medium 反应（已有候选 clip 的部分）
2. 动作切换/取消窗口与 link 优先级
3. reaction root-motion 其余可解码项和真实击退方向验证
