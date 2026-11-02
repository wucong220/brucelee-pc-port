# 2026-11-02 当前移植状态（续接用）

- 当前分支：`codex/menu-sfx`
- 当前主线：以 `git log -1` 为准；本文件记录时合并到 PR #233 后的 main。
- 当前测试口径：Python 3.12 `unittest discover -s tests` 为 283 项、通过 282、跳过 1。
- Windows 发行：用可写 `-BuildRoot`/`-GodotTempRoot` 构建后，
  `validate_windows_exe.ps1 -SkipBuild` 返回 `WINDOWS_EXE_VALIDATION=PASS`；
  PCK 内 `project.binary` 为 710 字节，EXE 自检确认 Bruce/Brick 候选、纹理、
  punch 伤害与 `all_impct_light_frnt_mid` reaction。
- Godot 4.7.2 headless 核心套件：smoke、round flow、Brick AI attacks、Brick attack set、Brick movement、Brick block、Brick light reactions、Brick high KO、parry、dual fighter candidates。
- 仓库外候选：
  - Bruce 59 段：`D:\BruceLeeWork\idle3-candidate-20261101\bruce_candidate_59_move.glb`
  - Brick 31 段 combat：`D:\BruceLeeWork\brick_candidate_combat_31_20261102.glb`，
    SHA-256 `e491fbdb822a9b25b7337f930b8041349c85bd4e6a831f7a66b606aa288b4b53`
- Brick 已接入：12 条高低拳脚、4 条 special（`m03_sp_kck_high/low`、
  `m03_sp_pnch_high/low`，PC 原型 rage 门控）、parry high/low 与
  `parry_high -> parry_attack` 链、方向移动/step、高/低/中格挡、
  轻/硬受击、高 KO、faceupko、扩展 AI 招式池。
- 对局已接入：三局两胜、2 秒回合重置、HUD 回合比分、R 重开整场、训练不计分。
- 仍未接入：Brick grab/endattack、AI attacktofloor、knockdown、
  原版选角/关卡/存档、逐帧录像与 GPU 视觉对照。

构建注意：Godot 会把 `tmpproject.binary` 写到 `TEMP`；若该目录不可写，
PCK 的 `project.binary` 会变成 0 字节，release EXE 启动挂起。显式传入可写目录：

```powershell
.\build_windows.ps1 `
  -BuildRoot 'D:\Build\BruceLee' `
  -GodotTempRoot 'D:\Build\BruceLeeTemp'
```

默认输出到仓库 `dist`，`validate_windows_exe.ps1 -SkipBuild` 固定读取该目录。
若使用 `-OutputDir` 输出到别处，验证前必须把生成的 EXE/PCK 复制到仓库
`dist`。

旧的 `CURRENT_STATUS_2026-10-31.md` 是历史快照，其中工作树 `prototype-menu`、
PR #96 和 243/247 项测试计数均已过时；不要把它当作当前基线。
