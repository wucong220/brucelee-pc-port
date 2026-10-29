# 输入配置与虚拟键：静态证据

本记录只涉及本机原版资源的只读分析，不包含原版载荷。它不证明
Windows 物理按键映射、实际启用的配置或连续输入行为，也没有实现新的招式。

## 数据来源

- `data.zpak` SHA-256：
  `364b30a10991d6fdc48bb3e1655e19538caee75bd6ddf81962524647e4cab05c`。
- `adreno_200/input.config`：资源 ID `4b8305de3ff2e54f17ca04dfae6c3364`，
  PAKD offset `437899`，解码后 SHA-256
  `302ae117d6f41bba38ce7d9e75b052147453a6fa1734acae364567a60c5ec2ef`。
- `libdefault.so` SHA-256：
  `1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70`。
  以下地址为该 ELF 的虚拟地址；静态分析不是运行时观测。

使用 `tools/kdf_fighting_set.py` 的 `read_archive_resource` 只读取得资源，
用 `kdf_data.parse_context`、`parse_container`、`RecordReader` 和
`kdf_combat_reactions._decoded` 读取 CTX3 根字典。根键是 `default`、
`zdk` 和 `toy`。配置数组的下标按零开始：

| 路径 | 配置项 | 资源内的虚拟键及 keyboard 整数 |
|---|---|---|
| `zdk.configs[0]` | `control_profile=1` | `a=70`、`b=69`、`c=18`、`d=17` |
| `default.configs[2]` | `control_profile=0` | `a=5`、`b=8`；另有 `fighter=1` 的 `a=44`、`b=45` |
| `toy.configs[2]` | `control_profile=0` | 同上 |

这些整数是配置字段的值，不能仅凭数字认定为 Windows 键码或键名。
`toy.configs[3]` 的 `control_profile=1` 将 `a/b/c/d` 分别关联到文件名
含 `hp/lp/hk/lk` 的触摸图标；这是图标引用，尚不能单独证明相应动作
或当前设备实际使用该配置。

## 原生调用与边界

1. `CBeatEmUpMatch::KrmInputEventCallback` 在 `0x161c54` 跳至 PLT
   `0x12b200`；该 PLT 的 GOT 槽 `0x6018dc` 的 `.rel.plt` 重定位符号是
   `CInputManager::KrmInputEventCallback`。
2. `CInputManager::KrmInputEventCallback` 的 `0x1b3904–0x1b394c`、
   `0x1b3988–0x1b39d0` 路径比较事件字段和绑定项，并通过 PLT
   `0x12aeb8` 调用 `CBeatEmUpGame::VirtualKeyEvent`。尚需完整追踪配置
   绑定项的构造及事件类型，才能断言某个具体配置在运行时生效。
3. `VirtualKeyEvent` 在 `0x17f630–0x17f644` 比较事件参数与
   `gid_Press`，GOT 槽 `0x604148` 的 `.rel.dyn` 重定位指向该符号。
   进入相等分支后，`0x17f7ac–0x17f7d0` 将事件名和虚拟键名作为两个
   字符串参数调用 `SPrintf`，格式字符串是 `0x5b9514` 的 `%s%s`；
   `0x17f7d4–0x17f7e0` 将结果交给 `CHStrMgr::GetItem`。
   这为 `Press` 与虚拟键 `a/b/c/d` 组合成战斗输入符号提供了静态线索。
   字符串管理器的静态大小写路径和序列检查见下节；该结果与 `.set` 的
   完整传递路径以及输入事件的时间与消费规则仍需核对。
4. `GameClass::OnInputEvent` 在 `0x12ece4` 经 PLT 调用
   `TranslateKeyCode`。后者 `0x130788–0x1307a0` 对输入 `0..13` 查
   `0x5b6294` 的 14 项表，输出依次为
   `12, 13, 14, 15, 17, 18, 69, 70, 11, 19, -1, -1, 20, 11`。
   尚未确认调用方输入值与具体 Android 设备事件的对应关系，因此不能
   从该表推导 Windows 物理键。

## 大小写及序列检查

以下为同一 ELF 的静态控制流，未在原版运行时观测：

- `VirtualKeyEvent` 在 `0x17f7dc` 将 0 作为第三参数交给
  `CHStrMgr::GetItem`（`0x17f7e0`）。`GetItem` 在 `0x140244` 调用
  `ComputeCRC32NSE`，其在 `0x13fab8` 经重定位为
  `ComputeCRC32Lower` 的 PLT 跳转；`GetItemCommon` 的零参数路径
  `0x140108–0x140114` 调用 `SearchNoSensitive`，后者在 `0x13fa58–0x13fa5c`
  调用 `StrCaseCompare`。这是该查找路径对大小写不敏感的静态证据；
  不单独证明 `gid_Press` 的初始化内容或 `.set` 的完整加载路径。
- `CFighter::UserControlUpdate` 在 `0x1a8a40–0x1a8a54` 经
  `CLinkDescr::GetKeySequence` 取得当前 link 的序列，并把调用者传入的
  事件向量传给 `InputSequenceCheck`。检查函数 `0x1a0180–0x1a0208`
  从序列和事件向量的末尾向前扫描：事件项 `+8` 的字符串项不匹配时
  跳过该事件；匹配且事件项 `+0x10` 字节为零时才前进一个待匹配项。
  因此检查允许跳过不匹配事件，也跳过对应字节非零的匹配事件。
  字节的写入和队列生命周期见下节；单凭这个函数不能证明最终招式触发。

`tools/native_reaction_links.py` 校验这段序列检查的指令字和 ELF SHA-256。

## 事件标记与批量过期

- `VirtualKeyEvent` 的 `0x17f85c–0x17f868` 在一个新建事件上写入
  `+0x10=0`，并将调用参数写入 `+0x0c`。`TVKeyEvent::createcopy`
  的 `0x177fac–0x177fb8` 复制这两个字段。
- `CFighter::UserControlUpdate` 在通过检查并调用 `FollowLink` 后，
  `0x1a8ac4–0x1a8ad0` 对当前序列及事件向量调用 `ConsumeEvents`。
  该函数 `0x1a0b40–0x1a0b70` 从末尾按字符串匹配并将对应事件
  `+0x10` 写成 1。**它没有检查该字节原值**，所以不能假定它标记的
  一定是 `InputSequenceCheck` 选中的同一批事件。
- 随后 `UserControlUpdate` 在 link 的 `+0xe0` 字节非零时，
  `0x1a8ae0–0x1a8b14` 将整个输入事件向量的该字节写成 1。
  此处先只记录字段和控制流，不将字段名归因于未经核实的资源映射。
- `CBeatEmUpGame::Update` 的 `0x17c1d8–0x17c244` 对第一个队列、
  `0x17c248–0x17c294` 对第二个队列做同样的静态检查：队列非空时，
  读取最后一个事件的 `+0x0c`，加 500；如果 Update 参数以无符号比较
  大于该结果，就把该队列全部事件的 `+0x10` 标记为 1。
  它按最后一条事件批量标记，而不是逐条按年龄删除。时钟来源、单位、
  整数回绕和原版运行时行为尚未闭合；不能把 500 直接写成毫秒。
- 同一 `Update` 的 `0x17d5f8–0x17d614` 通过已解析的 PLT 将
  `this+0x744` 和 `this+0x76c` 分别传给 `UserControlUpdate` 的两个向量
  参数；这两个容器在角色语义上的具体分工仍需核实。其他控制路径和设备
  配置选择也还需核实。

这些写入及 `InputSequenceCheck` 对零值的要求支持该字节与输入消费或
有效性有关；它同时参与匹配和批量失效，因此不能只命名为 `consumed`，
也不能据此证明完整的原版输入行为。

## `gid_Press` 初始化

- `_GLOBAL__I_GIDs.cpp` 在 `0x218e28` 开始初始化输入 GID。其
  `0x218e3c–0x218e44` 从 PC 相对字面量得到同一常量区的基址，经
  `0x218ea0–0x218ea8` 保存首个 GID 字面量表地址。按已核验的字面量计算，
  该表基址为 `0x5bcfc8`。
- `gid_Press` 的初始化路径在 `0x21b120–0x21b150` 以字面量表
  `+0x310` 计算源对象，即 `0x5bd2d8`；随后从 GOT 槽 `0x604148`
  取得 `gid_Press` 对象，保存源和链接字段，并在 `0x21b15c` 调用初始化。
- `0x5bd2d8` 处的 NUL 结尾字符串是 `"Press"`。紧邻的
  `0x5bd2e0` 是 `"Pressed"`，与后一条 GID 初始化对应。
- 这闭合了 `gid_Press` 的初始化内容，但仍未证明哪个
  `input.config` 项或虚拟键在运行时产生该事件；`.set` 字符串到事件、
  时钟单位、活动配置及原始手感仍未闭合。`facedownattack` 仍未实现。

## 本次验证

- `py -3.12 -X utf8 -B tools/native_reaction_links.py <本机 libdefault.so>`：
  退出码 0，核验 96 条原生指令和三条字符串字面量
  （`ReceiveDamage`、`Press`、`Pressed`）。
- `py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q`：
  退出码 0，运行 190 项，其中 1 项跳过。
- `git diff --check`：退出码 0。
