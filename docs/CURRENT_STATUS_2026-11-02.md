# 2026-11-02 当前移植状态（续接用）

- 当前分支：`codex/menu-sfx`
- 当前主线：以 `git log -1` 为准；本文件记录时合并到 PR #231 后的 main。
- 当前测试口径：Python 3.12 `unittest discover -s tests` 为 283 项、通过 282、跳过 1。
- Godot 4.7.2 headless 核心套件：smoke、round flow、Brick AI attacks、Brick attack set、Brick movement、Brick block、Brick light reactions、Brick high KO、parry、dual fighter candidates。
- 仓库外候选：
  - Bruce 59 段：`D:\BruceLeeWork\idle3-candidate-20261101\bruce_candidate_59_move.glb`
  - Brick 31 段 combat：`D:\BruceLeeWork\brick_candidate_combat_31_20261102.glb`，
    SHA-256 `e491fbdb822a9b25b7337f930b8041349c85bd4e6a831f7a66b606aa288b4b53`
- Brick 已接入：12 条高低拳脚、方向移动/step、高/低/中格挡、轻/硬受击、
  高 KO、faceupko、扩展 AI 招式池。
- 对局已接入：三局两胜、2 秒回合重置、HUD 回合比分、R 重开整场、训练不计分。
- 仍未接入：Brick 完整 special/grab/endattack、AI 主动 parry/attacktofloor、
  knockdown、原版选角/关卡/存档、逐帧录像与 GPU 视觉对照。

旧的 `CURRENT_STATUS_2026-10-31.md` 是历史快照，其中工作树 `prototype-menu`、
PR #96 和 243/247 项测试计数均已过时；不要把它当作当前基线。
