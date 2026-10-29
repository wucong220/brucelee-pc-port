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
   哈希字符串大小写规则、该结果与 `.set` 中 `pressa/b/c/d` 的实际匹配，
   以及输入序列的时间与消费规则仍需核对，暂不作为已闭合的运行时映射。
4. `GameClass::OnInputEvent` 在 `0x12ece4` 经 PLT 调用
   `TranslateKeyCode`。后者 `0x130788–0x1307a0` 对输入 `0..13` 查
   `0x5b6294` 的 14 项表，输出依次为
   `12, 13, 14, 15, 17, 18, 69, 70, 11, 19, -1, -1, 20, 11`。
   尚未确认调用方输入值与具体 Android 设备事件的对应关系，因此不能
   从该表推导 Windows 物理键。

后续应核对 `gid_Press` 初始化字符串和 `CHStrMgrNSE` 的大小写语义，
追踪 `VirtualKeyEvent` 的输出到战斗 `keysequence` 比较，并确认实际配置选择。
在这些链路及连续输入规则闭合之前，`facedownattack` 仍未实现。

## 本次验证

- `py -3.12 -X utf8 -B -m unittest discover -s tests -p "test*.py" -q`：
  退出码 0，190 项通过，其中 1 项跳过。
- `git diff --check`：退出码 0。
