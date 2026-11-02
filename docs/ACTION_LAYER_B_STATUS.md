# 动作层 B 类清理状态（选项 1）

目标：只清动作层自创/近似，保留 PC 菜单、AI、训练/欣赏、镜头外壳。

| 项 | 内容 | 状态 | 证据/处理 |
|---|---|---|---|
| B1 | `prototype_push` | 已删除 | 从两份攻击 JSON 和解析器移除；命中推位移只用反应 root 数据。提交 `8ce9323` |
| B2 | 候选混合常量 | 已删除 | attacktofloor/facedown 混合帧改读 link `blending`（6/10/6）。提交 `2e25df0`、`33ccf2d` |
| B3 | 残余反应/入口 fallback 数字 | 已清理 | `_native_link_start_frame(..., N)`、`_native_entry_frame(..., N)` 的 N 全部改为 0（数据缺失即 fail closed）；`tests/test_native_link_frame_coverage.py` 校验每个调用都有对应 link |
| B4 | `startup/active/recovery` 相位枚举 | 保留（结构） | 帧边界全部由 `animation_frame_count`/`damage_time`/link 窗口数据驱动；但状态标签和 `state_time` 计时骨架仍是移植写法。第 5/6 轮尝试把 attack advance 改成绝对帧时钟，`smoke_test` 的 blockstun 反应出现重复接触/退回 hitstun，已两度回退；需同时重构 contact 触发边界，暂列为结构近似 |
| B5 | `_attack_hit_landed/_attack_connected/_multi_impact_applied` | 保留（簿记） | 语义对应原生 impact 帧/已接触/已应用状态；变量名与布尔结构与原生字段不同，属移植层簿记 |
| B6 | 根位移轴语义 | 已核对（第 39 轮） | 从源 movement tracks 验证：`movefwd/stepfwd = -Y`、`moveback/stepback = +Y`、`steplft = +X`、`steprht = -X`；实现改为统一源轴转换，删除逐 clip 首 Y 符号表。单 clip 动画映射仍标 EMPIRICAL/UNVERIFIED |
| B7 | 世界缩放 `1.8/173.4159` | 保留（候选） | `source_height=173.415954589844` 来自 Skl 数据；`world_height=1.8` 是 PC 坐标约定，不是原版场景缩放 |
| B8 | 反应链其他 fallback（stun/impact 等） | 数据优先 | 均已先查 link/动作数据；数字常量只作为缺数据时的回退，并由 B3 测试覆盖主要调用 |

## 说明
- B1/B2/B3 是实际代码删除，测试已覆盖。
- B4/B5/B7 没有更多原生数据前只能保留并明确标注，不能假装“已还原”。
- B6 已做实验证伪统一映射；需要 native root transform 的轴变换证据才能继续。


## 2026-11-02 追加验证

- `BRUCE_GRAB_ENDATTACK_VALIDATION={"grab_state":"grabbed1","endattack_state":"endattackcomp1"}`：
  在 63 段 Bruce 与 46 段 Brick 受害者候选上，Bruce `grab1 -> grabbed1 -> endattack1 -> endattackcomp1` 已实测通过。
- `validate_brick_grab_victim`、`validate_move_gallery`、`validate_training_full`、`validate_move_training` 均通过。
- B4 相位枚举的两次帧时钟尝试仍分别被 `smoke_test` 的 blockstun 接触和 large-delta 窗口测试拦下，已回退；当前不把失败实现留在仓库。
