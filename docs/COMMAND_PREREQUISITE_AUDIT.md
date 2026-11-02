# 招式指令前置审计（2026-11-03）

来源：`move_training_catalog.json`、`native_links.json`、`fighting_set_low_attacks.json`。

## 直接 step 前置组
| 课程 | 前置 | 指令 | 处理 |
|---|---|---|---|
| SPECIAL HIGH KICK | `stepback` | HOLD A → D → L | 直接触发 `special_kick_high` |
| SPECIAL LOW KICK | `stepleft` | HOLD S → D → U | 直接触发 `special_kick_low_hit`，不走 miss |
| GRAB 1 | `stepright` | HOLD W → J | 直接触发 `grab1` |
| GRAB 2 | `stepleft` | HOLD S → L | 直接触发 `grab2` |

原因：这些动作原生的 miss/中间 link 有短暂窗口；PC 的极坐标移动和镜头会在窗口内改变距离/朝向，导致 miss 或回退。

## 非 step 前置组
| 课程 | 前置 | 处理 |
|---|---|---|
| HIGH PUNCH / LOW PUNCH / HIGH KICK / LOW KICK 系列 | `source_*` 攻击前置 | 保持原生 source link；`validate_training_full` 通过 |
| SPECIAL PUNCH LOW/HIGH | `source_high_punch2` | 保持原生序列 S,D,J / A,D,J |
| ENDATTACK 1/2 | `endattack` | 保持原生 HOLD D+J / HOLD D+L |
| ATTACK TO FLOOR | `target_down` | 保持原生 L |
| PARRY HIGH/ATTACK | `parry_*` | 保持原生 S,D |
| FACEDOWN/FACEUP ATTACK | `player_down/player_face_up` | 保持原生 J |

## 验证
- `test_training_catalog_inputs`：25 条目录输入与 `keysequence[1]` 一致
- `validate_step_prerequisite_triggers`：4 个 step 前置直接触发 PASS
- `validate_training_full`：25/25 PASS
