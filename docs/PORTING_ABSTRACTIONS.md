# 移植层抽象与保留项（PORTING_ABSTRACTIONS）

来源：2026-11-02 让 ChatGPT 复核动作层 B 类保留项后的结论。原则：允许移植层必要的抽象，但必须标注，不冒充原生机制；特殊招式硬编码补丁和无证据推断不接受；本文件的收尾不能替代通用 Link 执行器修复。

| 项目 | 判断 | 优先级 | 处理 |
|---|---|---|---|
| `startup/active/recovery` 状态 | 可接受并标注 | P2 | 保留 Godot 状态机；所有边界由 `animation_frame_count`、`damage_time`、link 窗口计算，不手填；命中用精确 `damage_time`；大 delta 逐阶段/逐窗口处理。`validate_time_step_invariance` 覆盖 `F(0.4)=F(0.1×4)`。文档明确这是 Godot 调度状态，不是原生状态枚举。 |
| Root Motion raw 轴 | 轴语义已核对 | 已解决（轴） | 源 movement tracks 验证：`movefwd/stepfwd = -Y`、`moveback/stepback = +Y`、`steplft = +X`、`steprht = -X`。`_root_motion_delta_to_pc_world()` 统一用源轴；单 clip 动画映射仍标 `EMPIRICAL`/`UNVERIFIED`，不宣称每个攻击的完整原生轨迹 |
| 世界缩放 `1.8/173.4159` | 可接受并标注 | P2 | `1.8` 是 `PC_TARGET_CHARACTER_HEIGHT`（PC/候选模型约定），`173.4159` 是 Skl source height；只保留 `source_units_to_world` 单一转换入口；原始半径/距离/root 始终 source units。 |
| `_attack_hit_landed/_attack_connected/_multi_impact_applied` | 可接受并标注 | P2 | 三者分别表示命中落地/已接触/多段 impact 去重；每次新攻击开始清空，不能污染下一攻击；补生命周期与去重测试。`validate_hit_bookkeeping_lifecycle` 覆盖清空。 |

## 当前证据状态
- `validate_time_step_invariance.gd`：PASS（同一总时间不同步长，命中/状态/位置一致）
- `validate_hit_bookkeeping_lifecycle.gd`：PASS（新攻击清空簿记）
- Root Motion 映射状态：`m01_pnch_low_01`、`m03_pnch_low_01`、`m03_kck_low_01` 标为 `EMPIRICAL`，其余动作 `UNVERIFIED`
- `WINDOWS_EXE_VALIDATION=PASS`（最新本地包）

## 不可接受的做法
- 为某个特殊招式手写额外分支来掩盖通用 Link 执行器缺失；
- 用全局 `-Y` 或首个非零 Y 符号推导所有 Root Motion；
- 把移植层状态、坐标校准、命中簿记描述成原生机制；
- 用本文件中的“可接受”替代空序列事件消费、输入事件/按住状态、`entry_frame/linking_frame` 等独立执行器问题。
