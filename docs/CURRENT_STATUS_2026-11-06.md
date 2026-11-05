# 当前状态：2026-11-06

> 本文件记录 Current226 的真实状态。根目录 [`README_zh.md`](../README_zh.md) 与 [`PHASES.md`](PHASES.md) 中大量早期章节保留的是 P0–P2/候选阶段的历史记录，不再作为当前已实现状态的唯一依据。

## 基线

- 分支：`codex/training-hints`
- HEAD：`ecd3585088f47b608834a5efbbfc3`
- 远端对比：本地 / 远端 `0 / 0`
- 当前包：[DragonWarrior-Current226-20261103](<D:/BruceLeeWork/DragonWarrior-Current226-20261103>)
- 启动入口：[BruceLee_Start.exe](<D:/BruceLeeWork/DragonWarrior-Current226-20261103/BruceLee_Start.exe>)
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
| 本地音频 / 文本 | 51 条 hash-pinned 本地音频；39 个成就 key × 10 语言；menu/training/round SFX 已接线 |

核心文件：

- [fighter.gd](../godot/scripts/fighter.gd)
- [native_ai.gd](../godot/scripts/native_ai.gd)
- [native_action_selector.gd](../godot/scripts/native_action_selector.gd)
- [native_conditions.gd](../godot/scripts/native_conditions.gd)
- [main.gd](../godot/scripts/main.gd)
- [wavelet_anm_codec.gd](../godot/scripts/wavelet_anm_codec.gd)
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
| Current226 包 headless | skin01 / skin04 exit 0 |

## 明确保持 fail-closed / 待继续

- `candidate_package_models.json` 仍可能是旧 manifest；需按 Current226 的 11 个模型哈希校正
- 包仍有外部绝对路径候选；自包含启动路径尚未完全清理
- 15 个解锁/选角行与 11 个随包 GLB 尚未逐行闭环；ShenLo 模型仍未随包
- Profile 子行、Settings VIDEO/CONTROLS、About 版本/免责声明、credits roll、Training VIDEO/CONTROLS、语言列表、locked-card cursor 等 UI 仍有缺口
- 真实按键下对 Brick 的 `grab1 brick / endattack brick` 变体路径与 base API 的 93/130 victim hold 路径不同；需证明是原生行为或修运行时
- SinFu / LoMing 少数族内 clip 无同骨架精确源，继续 fail-closed，不跨骨架借动画
- `validate_action_cameras.gd` 的 victim dummy 相机失败为既有测试夹具问题，不是 Current226 新增功能回归
- 逐帧原版录像、GPU 像素级、真实手柄设备矩阵仍未验收

## 继续移植的当前主线

1. 自包含包与外部绝对路径清理
2. 角色名册与缺失候选
3. 原版菜单 / 设置 UI 缺口
4. 真实按键下大骨架终结技 / 变体路径

后续所有改动应继续遵守：只用原版/反编译证据，缺证据 fail-closed，不发明动作、相机、概率；全部 `--headless`；原始资源不提交、不公开。
