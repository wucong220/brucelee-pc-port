# 反击与抓取：原生实现审计

目的：在继续补招之前，先确认项目里是否已有实现，避免重复造轮子。结论：**GDScript 层没有现成 parry/grab 实现**；权威实现存在于原始 `libdefault.so` 的符号和 `brucelee.set` 链接数据中。

## 原始二进制中的既有实现（证据：`evidence/candidate_symbols.csv`）

| 地址 | 符号 | 作用 |
|---|---|---|
| `0x001a0380` | `krm::CFighter::IsInCounterTime()` | 反击窗口判定（countertime） |
| `0x001a0a80` | `krm::CFighter::IsAboutToGrab()` | 抓取意图/前置判定 |
| `0x001a1360` | `krm::CFighter::SetFightersPosForGrab(float, bool)` | 抓取双方定位 |
| `0x001a0180` | `krm::CFighter::InputSequenceCheck(...)` | 按键序列检查（原版输入实现） |
| `0x001a020c` | `krm::CFighter::InputStatusCheck(...)` | keystatus 检查 |
| `0x001a170c` | `krm::CFighter::TimeWindowCheck(...)` | 链接时间窗口检查 |
| `0x001a3920` | `krm::CFighter::CheckConditions(...)` | 链接条件求值 |
| `0x001a3204` | `krm::CFighter::IsBlocking()` | 格挡判定 |

这些函数才是 `countertime`、`grabdistance`、`oppposestun` 等条件的原版实现来源。当前原型只能用 `brucelee.set` 的组窗口和条件名近似，不能声称等价。

## 已复用/可复用的现有工程机制

- `ATTACKS` / `BRUCE_ATTACK_METADATA` / `CANDIDATE_CLIPS`：攻击配置的唯一入口。
- `STANDING_COMBO_SEQUENCES`、`from_attack`、`from_attack_in`：输入序列匹配。
- `SPECIAL_CHAIN_MISSES` / `_begin_chained_attack`：两段式 miss→hit。
- `multi_impacts`：一个动作多段伤害（`specialpunchhigh` 已在用）。
- `_register_landed_hit`：命中/格挡/怒气统一结算。
- `REACTION_PROFILES` / `EXACT_REACTIONS`：受击反应表。

新增格挡反击时只应接这些机制，不再另建一套输入/伤害/反应系统。

## 抓取动画的核对结果

- `grab1miss` / `grab2miss` 都使用 `m02_grab_01`，其动画头部引用是
  `skeletons/bl_ken_goodall_01_high.skl`。60 个骨骼路径与 Bruce 完全同名，
  仅 body/hair 两个对象节点不同；`retarget_animation_binding.py` 已做实验性
  跨骨架映射（对象按 hair/body 角色对应），因此现在可作为候选打包。
- `grab1` 使用 `m01_grab_01`、`grab2` 使用 `m01_grab_02`，引用
  `skeletons/bl_brucelee_01_high.skl`，可直接使用。
- 现有 `multi_impacts` 已能承载 `grab1` 的三段（6/5/9）和 `grab2` 的两段（5/15）。

## 结论/约束

1. 反击：没有现成 GDScript，只能按 `IsInCounterTime` / `candocounter` 语义实现；不得把 `computer.state in startup/active` 说成原版等价。按用户指定，额外实现 `parry_low` 作为 `parry_high` 的低段对应（`low` 高度选择、27 帧、30 怒气、零伤害），明确标注为 PC 原型扩展。
2. 抓取：命中动画可用，miss 动画属于 Ken 骨架；若没有正确的 Bruce miss 动画，只能做“命中直接抓取、距离不足 fail-closed”的候选实现，并在文档注明。
3. 终结技 `endattack1/2` 仍缺 `oppposestun` 对应状态。
