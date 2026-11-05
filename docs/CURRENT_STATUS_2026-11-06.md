# 当前状态：2026-11-06

> 本文件记录 Current229 的真实状态。根目录 [`README_zh.md`](../README_zh.md) 与 [`PHASES.md`](PHASES.md) 中大量早期章节保留的是 P0–P2/候选阶段的历史记录，不再作为当前已实现状态的唯一依据。

## 基线

- 分支：`codex/training-hints`
- HEAD：`2f7293e56802013122a055dccdbe20f83e4eb53a`
- 远端对比：本地 / 远端 `0 / 0`
- 当前包：[DragonWarrior-Current229-20261103](<D:/BruceLeeWork/DragonWarrior-Current229-20261103>)
- 启动入口：[BruceLee_Start.exe](<D:/BruceLeeWork/DragonWarrior-Current229-20261103/BruceLee_Start.exe>)
- 构建：Godot 4.7.2 stable，Windows x86_64 EXE + PCK，GL Compatibility
- 测试约束：仅 `--headless`，不弹窗、不截图；原始 APK/ZPAK/SO/音频/模型仅本机私有，不进 Git

## 已集成的原版逻辑 / 资源

| 系统 | 当前结论 |
|---|---|
| Native AI `AIUpdate` link-order | 按 `_native_links` 顺序扫描；`TimeWindowCheck` + action-set/key gate + `CheckConditions`，first eligible wins；无 eligible link 时 no-action，不默认回退旧 picker |
| Native input queue | 500 ms、严格 `< now` 过期、整批消费、first matching link wins 已按原生证据对齐 |
| `CheckConditions` | 21 个 link token 审计，19 个修正；`impact`、`healthzero`、`grabdistance`、`oppnotblocking`、12 个 `oppattack*`、pose token 等按反编译语义实现 |
| `candobasicattacks` | 84 成员 / 21 链接；12 条玩家链已验证，9 条其他角色链 owner-refused |
| 对手后缀动作 | 101 行恢复；82 个玩家 attack kind、18 个 victim 选择器、25 个证明相机 |
| 相机 | authored / analytic / state6 / zoom push = 0 已恢复；`DAT_0024449c = -200.0`，target 恒 0，所以 push 精确为 0 |
| ANM | wavelet + fractional root interpolation 已集成运行时 |
| 抓取/终结技 | 两段 `grab1miss → grab1 [8,9]`、`grab2miss → grab2 [8,9]`；victim 按 set 的 47/98/132/155、90/78/93/130、28/55、103/45 帧与 exit 状态保持；attacker 的 20 点伤害不截断 |
| 大骨架 `forbigguy` | 4 套 Bruce skin 全部 97 clips；5 条 `*_forbigguy` 精确合入，sha pin 已更新 |
| Ken | `models/ken_all26_78.glb` 已 pin，含 forset02 victim clips |
| ShenLo 抓玩家 | `attack_config_shenlo.json → shenlo`，玩家持 `all_grabbed_01/02_forset04`，103/45 帧、20/5 原生伤害；无 endattackcomp，保持 fail-closed |
| 真实按键大骨架终结技 | 原生 `grab1 brick/endattack brick` 变体保留；opponent-suffix phase 帧数按 `SOURCE_FRAME_RATE` 转秒后，raw keyboard / raw combo / base API 均进入 93/130 帧 victim hold |
| 语言设置 | 8 项 language dock，语言码 `0..7`，ENTER 应用、ESC 返回；PORT 持久化 `user://ui_gaps_language.json`，并用 headless 输入→保存→重启验证 |
| Profile / About | 四个 Profile destination 页面、stats 三个子行、About 背景与 10 语言免责声明已恢复；未恢复的正文/版本号显示 `NOT RECOVERED` |
| VIDEO/CONTROLS | Settings/Training destination 与解码 widget 已记录；用户可达入口和实时值未恢复，保持 fail-closed |
| Locked-card cursor | `CBruceLeeDock::OnKeyPress` 的 skip/clamp/restore 规则已恢复并接线；partial unlock 下 RIGHT 从 0 跳过 1/2 到 3 |
| Victim camera fixture | `validate_action_cameras.gd` 按 Thai/Karate set 选择 authored ANM，保留逐帧 `place_world/FOV/index` 校验；45 项相机表 0 问题 |
| 本地音频 / 文本 | 51 条 hash-pinned 本地音频；39 个成就 key × 10 语言；menu/training/round SFX 已接线 |

核心文件：

- [fighter.gd](../godot/scripts/fighter.gd)
- [native_ai.gd](../godot/scripts/native_ai.gd)
- [native_action_selector.gd](../godot/scripts/native_action_selector.gd)
- [native_conditions.gd](../godot/scripts/native_conditions.gd)
- [main.gd](../godot/scripts/main.gd)
- [wavelet_anm_codec.gd](../godot/scripts/wavelet_anm_codec.gd)
- [dock_cursor.gd](../godot/scripts/dock_cursor.gd)
- [recovered_pages.gd](../godot/scripts/recovered_pages.gd)
- [opponent_suffix_variants.json](../godot/data/opponent_suffix_variants.json)
- [candobasicattacks_members.json](../godot/data/candobasicattacks_members.json)
- [action_camera_map.json](../godot/data/camera_anm/action_camera_map.json)

## 最近一次核心验证

| 验证 | 结果 |
|---|---|
| `validate_wavelet_anm.gd` | PASS，1613 checks |
| `validate_candobasicattacks_data.gd` | 84 / 21 / 12 / 9，exit 0 |
| `validate_native_conditions.gd` | 88 checks，0 failed |
| `validate_native_ai.gd` | PASS，`block_branch_hits=45/59` |
| `validate_ai_guard.gd` | PASS |
| `validate_canblock_windows.gd` | 891 checks，0 failed |
| `validate_native_reaction_gate.gd` | 123 checks，0 failed |
| `validate_air_hit.gd` | 78 checks，0 failed |
| `validate_victim_hold_timings.gd` | 196.8 s，0 failures |
| `validate_opponent_suffix_actions.gd` | Ken 38、Brick 38、SinFu 35，0 fail |
| `validate_shenlo_victim.gd` | 4 skin × 92 checks，0 fail |
| `validate_raw_finisher.gd` | 4 skin × 53 checks，0 fail |
| `validate_language_dock.gd` | session 28 / restart 6，0 fail |
| `validate_recovered_pages.gd` | normal 47 / failclosed 9，0 fail |
| `validate_menu_art_menu.gd` | 74 checks，0 fail |
| `validate_menu_art_off.gd` | 13 checks，0 fail |
| `validate_action_cameras.gd` | 0 fail；Thai 90/78/93，Karate 47/98/132 |
| `validate_dock_cursor.gd` | dock 20/20、credits 5/5，0 fail |
| Current229 包 headless | exit 0 |

## 明确保持 fail-closed / 待继续

- `candidate_package_models.json` 仍可能是旧 manifest；需按最终 15 个模型哈希校正
- 包仍依赖部分外部绝对路径；自包含启动路径尚未完全清理
- 15 个解锁/选角行已找到 15/15 精确 GLB，但四个新增模型、texture roots、pins 与 corrected manifest 还未统一进 Current229 包
- self-contained 初版交付存在 `candidate_path_guard` 过宽、部分 packaged GLB 选型只检查存在未重验 SHA、MODE DATA ERROR/损坏模型转换未测；guard hardening 未完成前不能算最终验收
- Credits 绝对滚动时序未恢复：只证明 `+2,+1` 逐 tick 位移模式和 72 的行高；tick cadence、初始 offset、结束条件未知，演出保持 fail-closed
- About 版本号、Profile 子页正文、stats 子页正文、art album、fighter gallery 运行数据、Settings/Training VIDEO/CONTROLS 可达入口与实时值仍为 `NOT RECOVERED`
- Credits 文本可逐字恢复，但滚动演出未恢复，因此没有伪造 12 行预览
- SinFu / LoMing 少数族内 clip 无同骨架精确源，继续 fail-closed，不跨骨架借动画
- `validate_candobasicattacks_links.gd` 仍有已知 stale expectations；测试夹具审计进行中
- native save/unlocks 格式仍在恢复；language dock 当前使用明确标注的 PORT 持久化
- 逐帧原版录像、GPU 像素级、真实手柄设备矩阵仍未验收

## 继续移植的当前主线

1. 自包含包 / guard 硬化 / 15 模型统一合入
2. Stale test 期望校正
3. Native save/unlocks 格式恢复
4. Credits / About 剩余原生证据

后续所有改动应继续遵守：只用原版/反编译证据，缺证据 fail-closed，不发明动作、相机、概率；全部 `--headless`；原始资源不提交、不公开。
