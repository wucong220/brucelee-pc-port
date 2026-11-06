# 当前状态：2026-11-06

> 本文件记录 Current246 的真实状态。根目录 [`README_zh.md`](../README_zh.md) 与 [`PHASES.md`](PHASES.md) 中早期章节保留 P0–P2/候选阶段历史，不再作为当前实现的唯一依据。

## 基线

- 分支：`codex/training-hints`
- 当前运行时代码 / HEAD：`34a0907cd0ca1634d8caa1f4b42334b9a4bece9a`
- 远端：本地 / 远端 `0 / 0`
- 当前包：[DragonWarrior-Current246-20261103](<D:/BruceLeeWork/DragonWarrior-Current246-20261103>)
- 入口：[BruceLee_Start.exe](<D:/BruceLeeWork/DragonWarrior-Current246-20261103/BruceLee_Start.exe>)
- 构建：Godot 4.7.2 stable，Windows x86_64 EXE + PCK，GL Compatibility
- 测试约束：仅 `--headless`，不弹窗、不截图；原始 APK/ZPAK/SO/音频/模型仅本机私有，不进 Git

## 已集成

| 系统 | 当前结论 |
|---|---|
| Native AI `AIUpdate` link-order | 原生 link 顺序、TimeWindowCheck、action-set/key gate、CheckConditions；无 eligible no-action |
| Native input queue | 500ms、严格过期、整批消费、first matching wins |
| `CheckConditions` | 21 token 审计，19 修正，未知 token fail-closed |
| `candobasicattacks` | 84 成员 / 21 链接；12 玩家链，9 owner-refused |
| 对手后缀动作 | 101 行恢复；82 attack kind、18 victim 选择器、25 证明相机 |
| 抓取/终结技 | 两段 miss→grab，per-set victim 帧数/exit，20 伤害不截断 |
| 真实按键终结技 | opponent-suffix phase 从 frame 转 second；raw keyboard / raw combo / base API 都到 93/130 帧 victim hold |
| Bruce 四套 skin | 全部 97 clips，5 条 `*_forbigguy` |
| Ken | 78-clip victim model pin |
| ShenLo 抓玩家 | forset04 victim 映射，103/45 帧，20/5 原生伤害 |
| Wavelet / fractional ANM | 已集成运行时 |
| 相机 | authored / analytic / state6 / push=0；45 项 camera map 审计 0 问题 |
| 语言 | 8 项 dock；native `settings.dat` 1FDKENONCTX3，OPTION.language 0..7，安全原位写 |
| Native progress | Unlocker、CharacterList、SceneryList、art flags 已接线；Stats 仅 TVal 子集 |
| UI | Profile 四个目的页、stats1/2/3 正文、About 1.15.26、Credits 逐字文本 + 33ms/+2/+1 滚屏、locked-card cursor |
| 自包含包 | 15 个 roster 模型、15 pins、package-only launch、非零启动器 |
| 本地音频/文本 | 51 条 hash-pinned 音频；39 成就 key × 10 语言 |
| Native progress 默认启用 | 正常启动默认使用 `settings.dat`；旧 JSON 一次性迁移；`BRUCELEE_PROGRESS=0` / `BRUCELEE_NATIVE_PROGRESS=0` 可关闭 |
| Art / fighters gallery | art 18 项按 artpictures.list 顺序；fighters 10 uniques、2 列 row-major、selectedcell 与 profile 跳转已恢复 |
| Player tutorial style | 教程 `use_custom_style=false` 使用 Bruce 默认 8 个精确 unique IDs；关闭/切 Free Training 恢复保存 clip |
| Brick parry | 吸收后设置 `_parry_absorbed`，high parry 可进入 `parry_attack_brick` 并造成 10 伤害 |

核心文件：

- [fighter.gd](../godot/scripts/fighter.gd)
- [native_ai.gd](../godot/scripts/native_ai.gd)
- [native_conditions.gd](../godot/scripts/native_conditions.gd)
- [native_settings_store.gd](../godot/scripts/native_settings_store.gd)
- [native_progress_store.gd](../godot/scripts/native_progress_store.gd)
- [main.gd](../godot/scripts/main.gd)
- [credits_roll.gd](../godot/scripts/credits_roll.gd)
- [credits_roll_view.gd](../godot/scripts/credits_roll_view.gd)
- [recovered_pages.gd](../godot/scripts/recovered_pages.gd)
- [profile_bodies.gd](../godot/scripts/profile_bodies.gd)
- [dock_cursor.gd](../godot/scripts/dock_cursor.gd)

## 关键验证

| 验证 | 结果 |
|---|---|
| `validate_wavelet_anm` | PASS 1613 |
| candobasicattacks data | 84 / 21 / 12 / 9 |
| native conditions | 88 / 0 |
| native AI | PASS，block 45/59 |
| canblock | 891 / 0 |
| reaction gate | 123 / 0 |
| air hit | 78 / 0 |
| victim hold timings | 196.8s / 0 |
| opponent suffix | Ken 38 / Brick 38 / SinFu 35 |
| raw finisher | 4 skin × 53 / 0 |
| Credits/About | 49 / 0 |
| Credits UI | normal 18 / failclosed 4 |
| native settings | 20 / 5 / 4 |
| native providers | store 35 / save 18 / restart 12 |
| native settings safe write | 52 / 0 |
| Profile bodies | normal 52 / failclosed 9 |
| Roster menu | 1267 / 0；variant 27 / 0 |
| Parry endattack | 25 expected passes / 0 unexpected |
| Native progress default | default_save 11 / restart 8 / migration 10+6 / language_seed 7 / opt_out 7，全 0 |
| Gallery bindings | normal 35 / tamper_order 8 / tamper_demoted 8，全 0 |
| Current246 package selftest | 15/15 SHA pins；launch exit 0 |
| Current245 mode-flow | Arcade/Survival/TimeAttack/Training 源码与 PCK 全部 exit 0，SCRIPT ERROR 0 |
| Current246 tutorial style | special high/low PASS；grab 教程 Bruce 默认 20；退出恢复 saved style |

## 明确边界 / 待继续

- Free Training 的 native active unique IDs 尚未接线；当前保存风格只影响 clip 映射，不能称为完整风格选择。
- Native Stats/story/mode 写入仍需真实 Android `settings.dat`；当前没有样本，保持 NOT READY。
- Stats 只接 TReal 子集。
- Art/fighters 的 list 顺序、2 列布局、selectedcell/profile 跳转已证明；per-index unlock state、运行时原始像素仍未恢复，保持 fail-closed。
- Credits 文本颜色控制码只剥离；未臆造调色板颜色。
- Package `candidate_textures_loaded=false` 已证明是测试指标：玩家 GLB 内嵌纹理；不是缺资源。
- `sceneries.list` 的 counted typed-float array 仍 fail-closed；不在 settings 内。
- 无 GPU/像素级、真实手柄设备矩阵、逐帧原版录像验收。
- 原始资源不提交、不公开。

## 当前状态

主玩法链已在 Current246 收口；教程 special/grab 已按 native `use_custom_style=false` 规则隔离。剩余未证明项保持 fail-closed，不以占位/猜测补全。

后续继续遵守：只用原版/反编译证据，缺证据 fail-closed，不发明动作、相机、概率；全部 `--headless`。
