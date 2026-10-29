# 李小龙候选战斗配置证据

## 分析基线

本记录对应的原生静态分析对象是完整原包内
`lib/armeabi/libdefault.so`：ELF32、小端、`ET_DYN`、`EM_ARM`（machine 40），
SHA-256 为
`1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70`。
该 ELF 没有可解析的 `SHT_NOTE`/`.note.gnu.build-id`，因此 Build ID 不可用；
样本身份以完整 SHA-256 为准。

下文函数地址是 ELF 符号值/虚拟地址，不是进程加载后的绝对地址。`ET_DYN`
加载时还可能存在 load bias；本文件内的 `.text`、`.rodata` 和 `.plt` 段恰有
相同的虚拟地址与文件偏移，而 `.data` 的虚拟地址比文件偏移高 `0x1000`。
因此按某一段读取原始指令或数据时使用
`file_offset = sh_offset + (va - sh_addr)`，不能把任意地址直接当成文件偏移。
文中的资源偏移（例如 `0x4B3A`、`0x140ADF6`）属于资源文件或归档流，不是
ELF 地址。

CTX3 解析器对字符串总数使用同一个 `100,000` 项上限；
`parse_context` 与 `parse_container` 不再采用不同的字符串上限。

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

对全部 `.text` 中直接读取 fighter `+0x164` current-impact 指针的指令做函数
归属和局部数据流检查后，当前已分析路径如下：

| 函数/位置 | current impact 的直接字段访问 | 证据 |
|---|---|---|
| `CFighter::IsAttacking` `0x1A02C4` | 仅检查指针是否为空 | `+0x14` 未读取 |
| `CFighter::AttackDamage` `0x1A0358` | `+0xC` 伤害值 | `+0x14` 未读取 |
| `CFighter::CheckConditions` `0x1A3DB0–0x1A4388` | `+0`、`+0x10`、`+0x18`、`+0x1C`、`+0x20` | `+0x14` 未读取 |
| `CFighter::DamageReceiveCheck` `0x1A55A0–0x1A562C` | `+0` 字节 | `+0x14` 未读取 |
| `CBeatEmUpGame::DrawDebugInfo` `0x17B85C`、`0x17B984` | `+0x10` 半径用于调试显示 | `+0x14` 未读取 |

`TAttackImpact::createcopy` `0x1A0618` 会复制 `+0x14` 的引用，
`TAttackImpact` 销毁路径 `0x1A3870/0x1A38AC` 会处理该引用；这是复制和
生命周期管理，尚不能构成碰撞或受击语义证据。fighter copy-constructor 在
`0x17EF10–0x17EF48` 只复制 current-impact 指针本身。

因此当前负证据等级为 `SCAN_SUPPORTED`：在上述直接使用点和函数内数据流中
没有找到 `body_part+0x14` 到碰撞、扣血、受击部位或表现决策的消费者。
它仍不是全程序不可消费的证明；未覆盖的形态包括跨基本块指针算术、保存到
栈后作为 `r0–r3` 传给未知函数、对象复制后的别名以及通过间接调用返回的
指针。由于这些路径尚未闭合，运行时语义继续保持 `SEMANTICS_UNVERIFIED`。

`CFighter::CheckConditions` 在 `0x1A42E4–0x1A4324` 对关联 fighter 的
`IsAttacking()` 前置条件完成后，执行以下单精度公式：

```text
attacker  = [defender_or_other + 0x7C]
impact    = [attacker + 0x164]
D         = float[other + 0x80]

reach = float[impact + 0x10] * float[attacker + 0x15C]
      + GetRadius(other)

if D <= reach:
    enter 0x1A4384
```

`0x1A42FC–0x1A430C` 读取 `attacker+0x15C` 和 impact `+0x10` 后做乘法，
`0x1A4310` 调用 `CFighter::GetRadius`，`0x1A4318` 将两项相加，
`0x1A431C–0x1A4324` 与 `other+0x80` 比较。结合前文，
`other+0x80` 是 `CollisionChecker` 写入双方的三维距离缓存，因此该式已经
证明 `attack_radius` 进入一条距离范围门控。

进入 `0x1A4384` 后还有第二道门控：

```text
impact_byte = byte[attacker.current_impact + 0]
state_byte  = byte[attacker + 0x16C]

if impact_byte < state_byte:
    branch to 0x1A4328
else:
    continue at 0x1A439C
```

`DamageReceiveCheck` 在 `0x1A5614–0x1A562C` 会把
`impact_byte + 1` 写回 attacker `+0x16C`，但该字节究竟是命中去重、
连击序号还是其他状态仍不能仅凭局部指令命名。

继续追踪 `fighter+0x16C` 的全部 CFighter 字节访问后，可以确定其更新时序：

- `CFighter::SetAnimation` 在 `0x1A6F2C–0x1A6F30` 先令 `r3=0`，再执行
  `STRB r3,[this,#0x16C]`。因此每次设置动画都会把该字节清零。
- `CFighter::DamageReceiveCheck` 在命中结算后把 `impact+0 + 1` 写回同一
  字节。
- `CFighter::CheckConditions` 在 `0x1A438C` 读取该字节，并与当前
  `impact+0` 比较。
- fighter copy-constructor `0x17EF38/0x17EF6C` 只复制该字节；未发现其他
  CFighter 函数直接写入它。

因此该字段当前最佳解释是“本次动画已处理的 impact 高水位”：

```text
SetAnimation:                 marker = 0
impact id x accepted:         marker = x + 1
later check of id y:          y < marker 表示 y 已处理
```

这支持第二道字节门控用于阻止同一动画中较早 impact 的重复结算，并允许后续
impact 按序号推进。证据等级：

- `STATIC_VERIFIED`：SetAnimation 清零、DamageReceiveCheck 写
  `impact+0+1`、CheckConditions 比较，以及 copy-constructor 仅复制。
- `STATIC_SUPPORTED`：`impact+0` 是配置内 impact 的顺序标识，
  `fighter+0x16C` 是本次动画的 processed-impact 高水位。
- `UNVERIFIED`：字段的正式源码名称、全部多 impact 动画是否严格按该顺序
  结算，以及 `0x1A4328/0x1A439C` 两个分支的全部后续行为。

证据等级：

- `STATIC_VERIFIED`：`IsAttacking` 前置分支；reach 公式的两个乘数、加法
  与 `other+0x80` 比较；`impact+0` 和 attacker `+0x16C` 的字节比较。
- `STATIC_SUPPORTED`：`r5+0x7C` 的关联 fighter 是当前攻击者，
  `GetRadius(r5)` 提供另一方的碰撞半径；该组合控制攻击距离门控。
- `UNVERIFIED`：比较通过后最终是否命中、`attack_radius` 的物理单位、
  第二道字节门控的正式业务名称，以及如何映射到 Godot 的世界尺度和
  `range`。候选原型继续保留占位 range，不能直接把原始 70.0 当成 Godot
  米制距离。

`CBeatEmUpGame::CollisionChecker`（`0x179328`，大小 `0x4F4`）进一步闭合了
`CheckConditions` 所读 fighter `+0x80` 的写入来源。函数前半段分别对两个内嵌
场景对象调用 `gfxScnObj::GetFrame` 和 `gfxScnFrame::GetPos`，把两组三维位置
写到 `sp+0x34..0x3C` 与 `sp+0x28..0x30`。`0x179448–0x17947C` 的 VFP
路径读取这两个向量的三个分量并累加平方，`0x179484` 调用
`zlibm_sqrt`，`0x17948C` 将结果转换到 `s17`。因此可还原为：

```text
D = sqrt(
    (p0.x - p1.x)^2
  + (p0.y - p1.y)^2
  + (p0.z - p1.z)^2
)
```

`0x17969C`、`0x1796A0` 随后把同一个 `s17` 写入 `r11+0x80` 和
`r10+0x80`。`r11`、`r10` 分别由 `0x1793F8`、`0x179418` 设置为 game
`+0x24`、`+0x1DC`，并在 `0x179718`、`0x179724` 作为 `CFighter::GetRadius`
的 `this`；在这两个地址范围内的 `s17` 未观察到重新赋值。据此，
`fighter+0x80` 的当前最佳解释是“该次碰撞检查开始时取得的两点三维欧氏距离
的同一个缓存值”，而不是攻击半径，也不是单独的命中布尔值。

`0x17972C–0x179738` 还把 `GetRadius(r11) + GetRadius(r10)` 与 `D` 比较：
半径和小于等于距离时跳到 `0x1794B4`，否则进入 `0x17973C` 以后的位置修正
路径。位于 `0x1794C0` 的 `500.0f` 和 `0x1795B4/0x1795CC` 附近的 `400.0f`
参与位置及边界门控；它们的具体世界坐标含义仍未闭合。

`0x179564–0x179610` 已进一步把 `400.0f` 分支与重叠分离区分开：第二次和第三次
`zlibm_sqrt` 分别计算位置向量 B、A 到原点的三维长度。若 `|B| > 400`，
`0x1796C4–0x1796FC` 将 B 的三个分量等比缩放回半径 400；若 `|A| > 400`，
`0x1795DC–0x179610` 对 A 做同一操作。更新后的三个分量写回原栈槽，随后仍由
两个 `gfxScnFrame::SetPos` 回写场景帧。因此 `400.0f` 是单个位置向量到原点的
球形上限，不是 `CollisionChecker` 的双方半径和。

`D > 500` 的第一段已恢复为明确的标量修正。`0x1794C4–0x1794CC` 比较双方
初始距离与 `500.0f`，`0x1794D4` 读取 double `0.5`，
`0x1794E4` 形成 `h = 0.5 * (D - 500)`。四个水平分量随后使用：

```text
A'_x = A_x + h * s20
A'_y = A_y + h * s21
A'_z = A_z

B'_x = B_x + h * s18
B'_y = B_y + h * s19
B'_z = B_z
```

`0x17953C–0x179560` 将六个结果写回原栈槽。`s18–s21` 来自前面的位置差和
归一化路径，但本窗口没有给出各自完整的坐标表达式及符号，因此当前只能确认
精确的乘加形式，不能把四个方向分量命名成固定的 A/B 单位方向。此前把第三
分量解释为取负的推导已撤回；`0x1794DC` 读取 double `0.0`，第三分量实际保持
原值。

重叠路径在 `0x179744`、`0x179754` 再次调用两个
`CFighter::GetRadius`，用重新取得的双方半径构造半径重叠量。函数 literal
pool 从 `0x1797FC` 开始：`0x179800/0x179804` 的 32 位字
`0x00000000/0x3FE00000` 组成小端 double `0.5`；`0x179808/0x17980C`
组成 double `0.0`。`0x179758` 的 `VLDR d7` 读取前者，后半段再把 `d7`
设为后者。令：

```text
delta = radius_r11 + radius_r10 - D
h     = 0.5 * delta
n_xy  = ((A_x - B_x) / D, (A_y - B_y) / D)
```

则当前静态数据流对应的位置修正为：

```text
A'_x = A_x + h * n_x
A'_y = A_y + h * n_y
A'_z = A_z

B'_x = B_x - h * n_x
B'_y = B_y - h * n_y
B'_z = B_z
```

`0x1797D0–0x1797F4` 把结果写回 `[sp+0x28..0x3C]`，`0x179614–0x179688`
随后通过两个 `gfxScnFrame::SetPos` 调用更新场景帧。这个路径把重叠量平均
分给两个位置；第二次 `GetRadius` 调用没有显示为按半径比例加权。

证据等级：

- `STATIC_VERIFIED`：重叠分支重新读取双方半径；`0.5` double 将重叠量平均
  分配；前两个位置分量沿 `(A-B)/D` 反向修正，第三个分量在该窗口保持；
  六个分量写回栈并交给 `SetPos`。
- `STATIC_SUPPORTED`：该路径是两个 fighter 的水平位置分离；`0x179614` 的
  两个 `SetPos` 分别对应前面复制的两个场景对象。
- `UNVERIFIED`：A/B 与 `r10/r11` 的先后对应、第三个分量的物理轴含义、
  `D` 包含该分量但分离只修改前两轴时是否另有场景约束，以及分离后是否再次
  计算并覆盖 `fighter+0x80`。`400.0f` 不在这个重叠分离窗口内，不能把上式
  扩写成完整的场景边界解算。

证据边界：

- `STATIC_VERIFIED`：两组 `GetPos` 输出进入三维分量差、第一次
  `zlibm_sqrt` 的结果进入 `s17`，`s17` 写入两个 fighter 的 `+0x80`；
  `GetRadius` 两者之和与同一 `D` 比较。
- `STATIC_SUPPORTED`：`r10/r11` 是两个内嵌 `CFighter`；半径和与距离的关系
  控制一条位置修正路径。该结论与该函数名及后续 VFP 位置更新一致。
- `UNVERIFIED`：两组坐标是否已经位于最终世界坐标系；`+0x80` 是否等于全部
  位置修正后的最终中心距；`attack_radius/body_part` 如何与该距离组合成最终
  命中、受击部位或推力。不能仅凭这条碰撞缓存链替换 Godot 的占位规则。

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
