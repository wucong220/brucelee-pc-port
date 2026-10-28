# KDF 字符串表取证（2026-10-28）

本记录仅描述本机三个已解码样本中观察到的字符串表，不包含原版资源数据。它不证明模型、骨骼、动画或后续数据区的格式已经解析。

## 已观察的布局

三个样本均以 `1FDKENONCTX3` 开头；偏移 `0x18` 的小端 32 位数均为 17。从 `0x1c` 开始，可连续读取 17 条：

1. 4 字节小端标识；
2. 4 字节小端字符串字节长度；
3. 相应数量的字符串字节，之后为一个零字节。

三个表共 51 条，每条的标识均符合 `(zlib.crc32(字符串字节) + 字节长度) & 0xffffffff`。例如 `linear` 的 CRC32 为 `0x0ddeb8b3`，长度为 6，观察到的标识为 `0x0ddeb8b9`；`texture2d` 的 CRC32 为 `0x85ce0660`，长度为 9，标识为 `0x85ce0669`。这只是这 51 条记录的观察结果，不应假定适用于所有资源或 PAKH 路径标识。

另一个 ChatGPT 会话随后报告对原包的只读扫描：2144 条物理资源中，1942 条以 `1FDKENONCTX3` 开头，其字符串表共 63377 条记录，全部符合上述公式；另外 202 条以 `RIFF` 开头。该会话还报告，用此公式计算 2265 条 PAKH 目录完整路径时，结果与对应资源 key 直接匹配数为 0。**这些全包统计来自对方会话报告，当前 Windows 工作区没有原包，尚未独立复现。**本工具即使遇到规则不匹配也会报告反例，不把规则硬编码为所有版本的格式要求。

字符串表中出现 `texture2d` 和 `datasourcepath/...`；后者是文件内部字符串，不能直接当成 PAK 目录中的文件名。对方会话报告，本包 356 条 `datasourcepath` 去掉前缀和扩展名并忽略大小写后，与对应 `.tex` 路径主体匹配。三个本机样本的纹理 `DATA` 基础层已进一步验证并可由 `tools/tex_convert.py` 转为 PNG；边界与限制见 `docs/TEX_FORMAT_FINDINGS.md`。角色骨骼和三条动作的字符串表交叉证据见 `docs/SKL_ANM_FORMAT_FINDINGS.md`。

| 物理流序号 | 本机样本 SHA-256 | 解码字节数 | 表项 / 规则匹配 |
|---:|---|---:|---:|
| 0 | `b35d235f30e3634488f912bb53a527d97c23d96fb81a9aeda843621f07ebf285` | 33346 | 17 / 17 |
| 2 | `5cbcff49073662207aff2c67df6c181d1b9adc8e4be4f91a7011736570d98612` | 131638 | 17 / 17 |
| 3 | `e4cfbd02ce05608a785e20ad0f18664f5709571cf312734b087f9b58fd9fb489` | 1100 | 17 / 17 |

## 工具与测试

`tools/kdf_strings.py` 只读现有解码文件，默认输出各文件长度、SHA-256、字符串数量、规则命中数和表终点；不会导出二进制。对目录只扫描直接包含的 `.bin`，其他格式记为 `unsupported`；损坏的受支持格式记为 `invalid` 并返回非零退出码。`--strings` 可额外显示字符串及其在解码文件中的偏移，输出可能包含原游戏文本，应保存在本地非同步目录，不要提交到 GitHub。

2026-10-28，Windows Python 3.12.10 的 MXC 沙箱仅给予工具对上述本机样本的读取权限，禁用网络；读取三个文件均成功，退出码 **0**。命令形式如下（路径须指向用户本机实际样本）：

```powershell
python -X utf8 -I -B tools/kdf_strings.py "$env:LOCALAPPDATA\BruceLee-PC-Port\decoded_frames\frame_0000_0000000000.bin" "$env:LOCALAPPDATA\BruceLee-PC-Port\decoded_frames\frame_0002_0000063745.bin" "$env:LOCALAPPDATA\BruceLee-PC-Port\decoded_frames\frame_0003_0000124002.bin"
```

加入通用 CTX3 DATA 头及动画 header 解析后，在隔离工作区用合成夹具、纹理转换器和完整 Python 测试执行下列命令：**41 项通过，退出码 0**。`.t` 是沙箱工作区内预建临时目录。

```powershell
python -X utf8 -I -B -c "import pathlib,tempfile,unittest;tempfile.tempdir=str(pathlib.Path.cwd()/'.t');unittest.main(module=None,argv=['unittest','discover','-s','tests','-p','test*.py','-v'])"
```

下一步应在可访问原包的环境中对更多样本做只读统计，寻找反例和资源类型差异；再结合已定位的对象、骨骼及动作文件研究结构。不要从这三个纹理样本推断动画编码或宣布转换成功。
