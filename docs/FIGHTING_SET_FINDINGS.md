# 李小龙候选战斗配置证据

本记录不包含原始资源。完整原包内的 `adreno_200/set/brucelee.set` 位于
PAKH 索引 1235，PAKD 偏移 `0x140ADF6`，压缩长度 45,581 字节，解码长度
322,258 字节；解码 SHA-256 为
`860b6dac1ae5043456fbf72b1cd93a5a1c76f036b3b995df5e57ce68b4d3762c`。
只读内存加载后，现有 `tools.kdf_data.parse_context` 可以解析其 CTX3 外层；
DATA 起始位置为 `0x4B3A`。文件引用第 22、34 项分别指向
`animation/m01_pnch_low_01.anm` 和 `animation/m01_kick_low_01.anm`，与候选
角色已经使用的两段动作名称相同。

DATA 头为 `(37870, 0, 0, 0)`，唯一 offset word 为 0，记录从 DATA+24
开始按 8 字节排列，记录末端加 16 字节尾部恰为文件末端。`parse_container`
现支持这一无数据段的受限布局；尾部标识等于 PAKH 的资源 ID。原生
`CResLock::DictKey`（`0x425DB8`）、`DictVal`（`0x425D2C`）和数组索引
（`0x1680CC`）的正常路径使用记录自身的相对索引，分别定位字典键、值和
数组元素。

沿根字典 `animations` 数组逐级解析，两个配置的链路如下：

| 数组项 | 动作名称 | 动画引用 | `attack` 的首个 `impacts` 项 | `damage_time` 原始值 | `damage_amount` 原始值 |
|---|---|---|---|---|---|
| 12 | `lowpunch1` | 22，`m01_pnch_low_01.anm` | 字典记录 1594 | 5、8（记录 1609、1610） | 5（记录 1598） |
| 18 | `lowkick1` | 34，`m01_kick_low_01.anm` | 字典记录 2666 | 7、10（记录 2681、2682） | 5（记录 2670） |

同一 impact 的其他结构化字段：

| 招式 | `attack_radius` | `body_part` | `height` | `strength` | `direction` |
|---|---:|---|---|---|---|
| `lowpunch1` | 70.0 | `larm` | `medium` | `normal` | `frontal` |
| `lowkick1` | 70.0 | `lleg` | `low` | `normal` | `frontal` |

`attack_radius` 的标签为 `0x20000000`，其中 32 位值为单精度浮点；
其余四项为字符串引用。`body_part` 原始枚举值、高度、强度和方向已经读取，
但 `body_part` 的运行时语义以及这些字段到碰撞体、距离和推力的换算尚未闭合，
因此候选 Godot 仍保留占位 range/push。

`TAttackImpact::createcopy`（`0x1A0618`）进一步确认二进制字段布局：
`+0x10` 通过单精度 VFP 指令复制 `attack_radius`，`+0x14` 复制 `body_part`，
`+0x18` 复制 `height`，`+0x1C` 复制 `strength`，`+0x20` 复制 `direction`。
`CFighter::CheckConditions` 会在 `0x1A3DBC–0x1A4014` 等处比较
`+0x18/+0x1C/+0x20` 与 `oppattackheight/strength/direction` 条件键，并在
`0x1A4304–0x1A4324` 以 VFP 读取 `+0x10` 的攻击半径。`+0x14` 的具体命中
部位消费路径仍需继续追踪；这些值也不能直接等同于 Godot 的 range/push。

当前证据等级：`+0x10/+0x18/+0x1C/+0x20` 为 `STATIC_SUPPORTED`；
`+0x14` 的存储布局为 `STATIC_SUPPORTED`，但运行时语义为
`SEMANTICS_UNVERIFIED`。尚未找到它直接选择碰撞骨骼、受击区域或反馈动画的
完整消费链，不能只凭 `larm/lleg` 名称推断命中效果。

`CAnimationDescr::ParseFromKDF` 的静态路径将 `damage_time` 两项及
`damage_amount` 写入 `TAttackImpact` 的 `+4/+8/+0xC`。`CFighter::BasicUpdate`
在 `0x1A8478–0x1A84A0` 比较 `fighter+0x34` 与前两项，值位于包含两个端点的
区间时进入选中 impact 的路径。`SetAnimationFrame` 在 `0x1A34E4` 将其
无符号整数参数写入同一字段。这支持这些时间值与该帧参数属于同一数值域。

`CFighter::BasicUpdate`（`0x1A8330`）和 `SimpleAnimUpdate`（`0x1A0110`）
使用同一动画帧公式：当前时间减去 fighter `+0x20` 的起始时间，转换为浮点后
乘以 PC 相对字面量 `0.03f`（`0x1A8568`），再乘以 fighter `+0x140` 的倍率，
通过 `VCVT.U32.F32` 转为整数并写入 fighter `+0x34`，同时以 `+0x30` 为上限。
整数转换的精确舍入语义仍待 FPSCR/指令形式复核。两项 `damage_time`
因此与自动动画进度共享帧数值域。上游 `CGuiSystem::Update` 在
`0x4693F8`/`0x46940C` 调用 PLT `0x1254D0`，其 GOT 符号为
`krm::krt::time::GetCurrentMili()`；该返回值原样传给
`CStateManager::PreUpdate/PostUpdate(uint)`。`PostUpdate` 在
`0x484FDC–0x484FF0` 将同一 `r1` 通过模块 vtable `+0x10` 传给
`CBeatEmUpMatch::Update`。因此时钟单位可限定为毫秒；在 `+0x140` 速度倍率为
1 时，`0.03f` 对应名义 30 个动画帧单位/秒。这只是动画采样速率，不能证明
渲染 FPS。

`CFighter::AttackDamage`（`0x1A0358`）在 impact 非空时，把 `+0xC` 的
`damage_amount` 从无符号整数转换为单精度浮点，再乘以 fighter `+0x154`
的浮点倍率，最后通过 `VCVT.U32.F32` 转为无符号整数。`CBeatEmUpGame::LoadFighter` 在
`0x17DB30–0x17DB38` 把战斗配置 `+0x78` 的单精度值复制到 fighter
`+0x154`；`DamageReceiveCheck` 在 `0x1A5600–0x1A5610` 调用
`AttackDamage`，取负后交给 `ModifyHealth(int)`。扣血公式的静态结构为：

```text
damage = convert_uint32(float(damage_amount_raw) * fighter_damage_multiplier)
```

ELF 的 `.rodata` 还包含 `damage_multiplier` 字符串，但该字符串与
`config+0x78` 的名称映射尚未闭合。不过 `TFighterConfig::SetDefault` 和
`IBeatEmUpGameMode::SetFighterConfigFromCharacterList` 两条配置构造路径都在
`config+0x78` 写入单精度 `1.0f`；`TFighterConfig::operator=` 只复制该值，
`LoadFighter` 再复制到 fighter `+0x154`。因此这两招的基础伤害 5 与倍率 1.0
结果为精确的 5，整数转换的舍入边界不会改变该结果。
辅助 ARM 解码器误把 `0x1A8424` 的原始字 `0xE0233792` 显示为乘法；实际是
带累加的地址计算，分析应以原始编码为准。

两段 ANM 的实际头也直接给出采样率与时长：

| ANM | SHA-256 | version | pose | firstframe | framerate | duration |
|---|---|---|---|---:|---:|---:|
| `m01_pnch_low_01.anm` | `47a40807899674244285eae06de8341660e36b6a987e88e50705edde015bb439` | 7 | 1 | 0 | 30 | 69 |
| `m01_kick_low_01.anm` | `fe202a35ce7c7c149a7dafe42496f06dc4b95b63c8fceacdff4d6d2ec98b2f03` | 7 | 1 | 0 | 30 | 86 |

候选 Godot 状态机现已使用这两招恢复出的默认速度阶段：低拳命中帧 5–8，
启动 5 帧、命中 4 帧、恢复 60 帧；低踢命中帧 7–10，启动 7 帧、命中 4 帧、
恢复 75 帧；两招伤害均为 5。`sourceFrameRate=30` 与原生 `0.03f` 换算一致。
格挡减伤 12%、攻击距离、推力及第三招 `heavy` 仍未恢复，继续使用占位规则。
候选 `ATTACKS` 同时固定了 `source_impact` 元数据（半径、部位、高度、强度、
方向），smoke 会阻止这些已恢复字段被无提示修改。
Godot 回归测试已覆盖低拳第 4/5/8/9 帧和低踢第 6/7/10/11 帧；窗口外不命中，
窗口内进入范围只结算一次。该测试验证候选接线，不证明原版逐帧视觉一致。

`TFighterConfig::SetDefault`（`0x15BA04`）在 `0x15BF70` 从字面量
`0x15C144` 读取 `0x3F800000`，即单精度 `1.0f`，并在 `0x15BF80` 写入
config `+0x78`。`LoadFighter` 随后把该值写入 fighter `+0x154`；
`TFighterConfig::operator=` 在 `0x1E1B34–0x1E1B3C` 复制该字段。因此默认
fighter 伤害倍率可限定为 `1.0f`。

`IBeatEmUpGameMode::SetFighterConfigFromCharacterList`（`0x1FF418`）的另一条
配置构造路径在 `0x1FFA9C` 读取字面量 `0x1FFE6C` 的 `1.0f`，并在
`0x1FFAA4–0x1FFAAC` 写入 config `+0x80/+0x78/+0x7C`。已恢复的
`TFighterConfig` 构造、填充和复制路径均使用该 1.0 值；尚无证据表明后续运行
会把它改成其他倍率。

`BasicUpdate` 的六个调用包装器 `MPRemoteUpdate`（`0x1A8794`）、
`MPLocalUserControlUpdate`（`0x1A8854`）、`UserControlUpdate`（`0x1A89C0`）、
`AIUpdate`（`0x1A8B2C`）、`DummyUpdate`（`0x1A8CF8`）和
`RecordReplayUpdate`（`0x1A8DB8`）都保留传入的 `r1` 后调用
`BasicUpdate`。上游最终确认来自 `GetCurrentMili()` 的毫秒时间。

`fighter+0x140` 的来源也已闭合：`CBeatEmUpGame::SetSpeed(float)`
（`0x1783F4`）将参数保存到 game `+0x818`，在 `0x17848C–0x1784A0`
取得两个内嵌 fighter 地址 game `+0x24`、game `+0x1dc`，并在
`0x1784E4/0x1784E8` 分别写入两个 fighter 的 `+0x140`。`CBeatEmUpGame::Init`
和 `SetInitialRoundValues` 都传入 `0x3F800000`（`1.0f`）；`SetState` 的
state=6 分支在 `0x178960–0x178970` 传入 `0x3F000000`（`0.5f`）。因此
`+0x140` 是全局战斗速度倍率，默认 1.0；默认速度下 `0.03f` 对应名义
30 个动画帧单位/秒。state 6 的调用点集中在 `PlayerWon`、`PlayerLost`
（例如 `0x19025C`、`0x190AB4`）和 `CBeatEmUpGame::Update` 的结果路径，
支持它是比赛结束阶段的半速状态；枚举正式名称和持续时长仍待确认。

进一步核对调用链：`CBeatEmUpMatch::Update`（`0x162648`）把入口 `r1` 保存为
`r5`，从 match `+0x250` 读取上一时刻，在 `0x162688–0x1626C0` 计算
`max(0, current - previous)` 并累加写入 match `+0x258`。随后 `CBeatEmUpGame::Update` 的入口在
`0x17C1D0–0x17C1FC` 保存该时刻，按 game `+0x7f4` 和 `+0x7fc` 计算调整后的
game `+0x7f8`。`GetStateTime` 只是读取 game `+0x7f8`；`CBeatEmUpGame::Update`
多处将该字段或派生字段传给 fighter 更新包装器。由此可限定：多条控制路径共享
同一个单调累计时间值的派生结果。

`CBeatEmUpGame::SetPaused`（`0x178304`）进一步闭合暂停语义：暂停分支在
`0x17836C–0x17837C` 将 game `+0x7f0` 的当前时刻写入 game `+0x800`；
恢复分支在 `0x17831C–0x17833C` 以旧调整量 `+0x7fc` 加上
`current - pause_start`，写回 `+0x7fc`。`Game::Update` 再从当前时刻扣除
该累计调整量写入 `+0x7f8`，因此可限定 `+0x7f8` 为排除暂停时长的状态时间。
fighter `+0x140` 由 `SetSpeed` 写入，默认 1.0，state 6 分支为 0.5。

本地端到端候选集成验证：使用仓库外 `body_hair_idle_punch_kick_candidate.glb`
和六张真实 Hair/Body 纹理执行 `validate_combat_candidate.gd`。结果为
`candidate_loaded=true`、`candidate_textures_loaded=true`、身高归一化 1.8、
初始 clip `m01_idle_01`、低拳 clip `m01_pnch_low_01`，对手生命值从 100
降到 95。另用 `validate_candidate_animation.gd --expect-hair` 验证 69 根骨骼、
idle/punch/kick 三段动作长度为 3.666/2.300/2.866 秒，头发相对头部的
位置误差低于 `0.00001`。`validate_candidate_textures.gd` 确认 Body 使用
opaque shader、Hair 使用 blend shader，三项纹理参数均已赋值。

这是 `LOCAL_TESTED + CANDIDATE`：真实模型、纹理、动画和战斗状态能在同一
Godot 进程联动，但尚未完成原版逐帧视觉对照、最终 GPU 材质对照或 Windows
发布包验收。

复核方式：`py -3.12 tools/kdf_fighting_set.py --archive <本机原包路径> --action lowpunch1 --action lowkick1`。
该工具只读选中的原包资源，在内存解析并校验索引、长度和尾部资源 ID；也可
接受本机已解码的 CTX3 文件。它只支持本文件所观察到的无数据段、直接向前
相对记录布局，不支持间接项；输出保留原始值。实际原包检查退出码 0；合成
样本覆盖多 impact、浮点与字符串枚举解码、无效类型和引用、归档 ID 不匹配及
重复条目。`--list-actions`
输出动作总数、全部动作及重复名称列表；加上 `--summary` 时只输出动作名称，
以及攻击统计，便于选择待核招式。实际原包共列出 200 个动作，其中 108 个带
`impacts`，共 131 条 impact；分布为 0 条 92 个、1 条 91 个、2 条 11 个、
3 条 6 个。当前未发现重复动作名称。全量测试
`py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q` 通过，
退出码 0；`git diff --check` 退出码 0。下一步确认 state 6 的正式枚举名称，
以及 `attack_radius/body_part/height/strength/direction` 到碰撞和推力的
运行时换算。
