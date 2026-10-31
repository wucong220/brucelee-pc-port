# 2026-10-31 当前移植状态（续接用）

- 工作树：`C:\Users\Lenovo\.codex\worktrees\prototype-menu\李小龙`
- 分支：`codex/combat-next`
- 当前本地 HEAD：`bb7eea6`（PR #95 的提交；远端 main 已包含 #93/#94/#95 合并）
- 测试：13 个 Godot 套件 exit 0；Python 243 passed / 1 skipped（默认 TEMP 下）

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

## 下一个可验证项

1. `impactsfromstun` 的 light/medium 反应（已有候选 clip 的部分）
2. 动作切换/取消窗口与 link 优先级
3. reaction root-motion 其余可解码项和真实击退方向验证
