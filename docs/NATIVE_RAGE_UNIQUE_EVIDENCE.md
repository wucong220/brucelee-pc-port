# 怒气上限/门槛与 unique 字段的证据（2026-11-02）

## 1. 怒气上限 100 与门槛 33/66

反编译 `CFighter::CheckConditions`（`D:\BruceLeeWork\ghidra-out7\krm__CFighter__CheckConditions.c`，函数 `@001b3db0`）中，对 `fighter+0x14c`（怒气）有三个比较：

- 第 285 行：条件 ID `DAT_001b4084` 且 `*(uint *)(this+0x14c) < 100` → 该条件为假；即怒气 **≥100** 时成立。
- 第 289 行：条件 ID `DAT_001b4088` 且 `*(uint *)(this+0x14c) < 0x42`（66）→ 怒气 **≥66** 时成立。
- 第 293 行：条件 ID `DAT_001b408c` 且 `*(uint *)(this+0x14c) < 0x21`（33）→ 怒气 **≥33** 时成立。

符号表中存在对应的全局条件对象：

```
_ZN3krm11gid_MaxRageE     0x80e5ec
_ZN3krm13gid_RageThirdE   0x80c738
_ZN3krm15gid_Rage2ThirdsE 0x80c7ec
_ZN3krm8gid_rageE         0x80e808
_ZN3krm8CFighter12IncreaseRageEi 0x1a0418
```

结论：`RAGE_MAX = 100`、`ragethird = 33`、`rage2thirds = 66` 是反编译确认的常量，不再只是原型猜测。当前实现用 `RAGE_MAX / 3` 和 `RAGE_MAX * 2 / 3` 的整数下取整得到 33/66。

动作记录里的 `rage` 字段（从 `brucelee.set` 导出）是每招的怒气变化：正值为命中增益（`lowpunch1=5`、`highkick3=10`），负值为特殊技消耗（`specialpunchlowmiss=-66`、`specialkicklowmiss=-66`）。这支持“link 路径按动作 rage 扣费/加怒”的实现。

## 2. unique 字段是角色专属标记，不是独立动画引用

`brucelee.set` 的动作记录里，`unique` 是一个一元素角色标记，动作自己的 `binary` 字段给出真实 ANM：

| 动作 | unique | binary |
|---|---|---|
| grab1 | `grababrucelee` | `animation/m01_grab_01.anm` |
| grab2 | `grabbbrucelee` | `animation/m01_grab_02.anm` |
| specialpunchhighhit | `hpunchbrucelee` | `animation/m01_sp_pnch_high.anm` |
| specialkickhigh | `hkickbrucelee` | `animation/m01_kck_front_step.anm` |
| specialkickhigh brick | `hkickbrick` | `animation/m03_sp_kck_high.anm` |
| grab1miss brick | `grababrick` | `animation/m03_grab_01.anm` |

link 上的 `unique` 同样列出该 link 属于哪个角色变体（如 `grababrucelee`、`grababrick`、`brickdavis`）。因此不存在“unique 名 → 另一个动画文件”的隐藏映射：**unique 只做角色筛选，动画取自目标动作自己的 `binary`**。当前 `_native_link_unique_ok()` 正是按 `brucelee`/`brick` 标签筛选。

证据代码：`tools/kdf_combat_reactions.py` 解析出的 action `unique`/`binary`；原始字符串位于 `brucelee.set` 偏移 1407（`grababrucelee`）等。
