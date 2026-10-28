# Bruce Lee: Dragon Warrior → Windows 原生 PC 移植工程

> **阶段：P0 取证 + P1 可玩的独立战斗原型（源码）**<br>
> **当前不是原版游戏的完整移植**。原型使用程序生成的占位人物、擂台和自写战斗规则，不包含原始游戏资产，不包含从 ARM 二进制提取的源码。它能作为逐步接入原版资源和逆向玩法的 PC 工程基础。

> 本机初始化时，压缩包内的四个已解码二进制样本另存到 `%LOCALAPPDATA%\BruceLee-PC-Port\decoded_frames`，不放在同步目录或 Git 仓库中；原始 ZIP 保持不变。`.gitignore` 只控制 Git 跟踪，不控制文件同步软件。

> `evidence/candidate_symbols.csv` 是从原版二进制中筛选出的函数符号文本清单，`evidence/source_inventory.json` 记录原文件名、哈希和容器元数据；两者不含原始二进制内容。`docs/INIT_GITHUB_AND_CODEX.md` 保留了初始化包最初建议私有仓库的方案，仓库实际可见性由所有者选择。

## 已完成工作（基于实际上传文件）

1. APK 中 `lib/armeabi/libdefault.so` 为 **ARM ELF32**，保留 `.symtab` 和大量 C++ 符号。提取并生成 **454 条候选函数符号清单** `evidence/candidate_symbols.csv`（类别：资源、战斗、动画、输入）。
2. 外部 `data.zpak` 是 ZIP；包含 `Core.pakh`、`Core.pakd000` 和 `metadata.xml`。`Core.pakh` 起始签名为 `8KAP`，偏移 `0x14` 是 2144，但其语义未验证。
3. `Core.pakd000` 开头 4 个封装数据流能严格完成 zlib 解码；其中一个音频数据是可识别的 **RIFF/WAVE PCM mono 32 kHz 16-bit**。第 5 个封装数据流的 zlib 结束标记不完整，工具谨慎停止、不推断资源边界。
4. 创建 Godot 4.7.x 兼容的 3D PC 战斗场景原型：人物对战、双向移动/侧移、3 种攻击、格挡、受击状态、血量、回合重开、简易对手 AI。
5. 提供 PowerShell `build_windows.ps1`，在本机安装 Godot 及 Windows 导出模板后生成原生 Windows EXE，非安卓模拟器。
6. 运行 `python -m unittest discover -s tests -v`：3 个工具测试通过。**Godot 场景仍需在装有 Godot 的机器上打开、编译并运行验证**。

## 立即运行 Windows PC 原型

### 准备

- Windows 10/11 x64
- Godot **4.7.2 stable** 标准版，无须 .NET
- 可选：对应版本的 Godot Windows Export Templates

从 https://godotengine.org/download/windows/ 获取 Godot。打开此工程的 `godot/project.godot`，启动主场景即可尝试运行。若编辑器提示导入或脚本错误，请记录 Godot 版本及具体日志，不要默认认为原型已通过实机测试。

### 控制

| 按键 | 功能 |
|---|---|
| A / D | 左右移动 |
| W / S | 侧向移动 |
| J | 快拳 |
| K | 踢击 |
| L | 重击 |
| Shift（按住） | 格挡 |
| R | 重新开始对战 |

### 导出 EXE

首先在 Godot 编辑器 `Editor → Manage Export Templates` 安装与 Godot 版本对应的 Windows 导出模板，然后执行：

```powershell
.\build_windows.ps1 -GodotExe 'C:\Tools\Godot_v4.7.2-stable_win64.exe'
```

预期输出 `dist/DragonWarrior_PC_Prototype.exe` 和同目录 `.pck` 文件（除非改用 embed_pck）。Windows EXE 必须与生成的 `.pck` 一起分发；只有独立 EXE 时可能无法运行。**此 EXE 是占位对战原型，不是原版游戏。**

也可以在 Godot 编辑器的 `Project → Export → Windows Desktop` 直接导出。

## 本地取证与提取

把用户自己的 APK 和 `data.zpak` 放在本地，例如 `D:\BruceLee\`，执行：

```powershell
py -3.11 tools\inventory.py --apk 'D:\BruceLee\Bruce Lee Dragon Warrior v1.15.26.apk' --zpak 'D:\BruceLee\data.zpak' --out evidence\inventory_local.json
py -3.11 tools\pak_probe.py 'D:\BruceLee\data.zpak' --limit 20 --csv evidence\frames_local.csv --extract-verified evidence\decoded_frames_local
py -3.11 tools\extract_inputs.py 'D:\BruceLee\data.zpak' --out 'D:\BruceLee\unpacked'
```

这些工具**不执行 APK 代码，也不解密、绕过 DRM 或下载游戏内容**。`pak_probe.py` 目前只提取确认完整的流，不能恢复所有独立资源的文件名和容器映射关系。某个输出为 `RIFF`，只证明这是有效 WAV，不证明对应具体游戏事件。

对已经解出且符合当前单层 `r8g8b8a8` 格式样本的 `.tex` 流，可转换成本地 PNG：

```powershell
py -3.12 tools\tex_convert.py 'C:\private\decoded-texture.bin' --output "$env:LOCALAPPDATA\BruceLee-PC-Port\previews\texture.png"
```

转换器会校验 CTX3 字符串标识、DATA 边界、宽高、像素长度和 MD5 尾部，并强制输出到仓库外且非明显同步目录。当前不支持 mip 链或其他纹理编码；格式证据与限制见 `docs/TEX_FORMAT_FINDINGS.md`。

Godot 原型会尝试从默认位置 `%LOCALAPPDATA%\BruceLee-PC-Port\local-assets\sprites\background.png` 加载本地背景；也可用环境变量 `BRUCELEE_BACKGROUND_PATH` 指定路径。HUD 还会尝试加载同目录结构中转换出的 `gui/images/hud/bl_hud_round_yellow_left.png`。文件不存在时继续使用占位场景和纯程序 HUD。该机制用于本机资源验证，原版图片仍不进入 Git。

如果要在 Linux/WSL2 中筛选原生符号，先从 APK 解压 `lib/armeabi/libdefault.so`，再运行：

```bash
python tools/native_symbols.py libdefault.so --out evidence/candidate_symbols.csv
```

需要 `nm -D -C`（GNU binutils）；地址是 ELF 中的符号值，不是进程加载绝对地址。

## 工程目录

```text
BruceLee_PC_Port_Phase1/
├── README_zh.md
├── build_windows.ps1
├── godot/
│   ├── project.godot
│   ├── export_presets.cfg
│   ├── scenes/main.tscn
│   └── scripts/{main,fighter,hud}.gd
├── tools/{inventory,pak_probe,native_symbols,extract_inputs}.py
├── tests/test_tools.py
├── evidence/
│   ├── source_inventory.json
│   ├── candidate_symbols.csv
│   ├── pak_frames.csv
│   └── decoded_frames/   # 忽略目录；本机样本另存位置见上方说明
└── docs/{PHASES,GHIDRA_PLAN,LEGAL}.md
```

## 需要避免的错误

- APK 里的 `.so` 是 ARM/Android 目标，不能直接重命名为 `.dll` 在 Windows x64 下加载。
- ZPAK 是 ZIP **外壳**，`Core.pakd000` 不是普通 ZIP；不能拿 zlib 流的顺序直接假定模型文件名。
- 符号名称 `CFighter::AttackDamage` 说明有相关功能，不等于具体伤害数值或连招规则已恢复。
- 音频、图片、模型、人物肖像、商标的使用和公开发行可能受到版权、许可与其他权利限制。此研究工程不携带原版完整 APK/ZPAK 文件，不授权公开分发游戏资产。

## 下一步

请参看 `docs/PHASES.md`。首要阻塞项是还原 `CPakDFilesManager` 的帧布局、索引→数据范围映射，以及 `mesh` / `anm` / `skl` 的私有格式。优先使用 **Linux/WSL2 + Ghidra** 静态检查 ARM ELF32，避免将 Windows REA/Ghidra 当前针对 PE 的支持误认为可直接处理 ARM ELF。
