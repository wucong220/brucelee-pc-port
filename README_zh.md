# Bruce Lee: Dragon Warrior → Windows 原生 PC 移植工程

> **阶段：P0 取证 + P1 可玩的独立战斗原型 + P2 PAK 解析完成 + P3 资源格式恢复进行中**<br>
> **当前不是原版游戏的完整移植**。原型使用程序生成的占位人物、擂台和自写战斗规则，不包含原始游戏资产，不包含从 ARM 二进制提取的源码。它能作为逐步接入原版资源和逆向玩法的 PC 工程基础。

真实候选模型、纹理、动画和战斗状态的本地集成方式、测试命令与边界见
[`docs/CANDIDATE_INTEGRATION.md`](docs/CANDIDATE_INTEGRATION.md)。

> 本机初始化时，压缩包内的四个已解码二进制样本另存到 `%LOCALAPPDATA%\BruceLee-PC-Port\decoded_frames`，不放在同步目录或 Git 仓库中；原始 ZIP 保持不变。`.gitignore` 只控制 Git 跟踪，不控制文件同步软件。

> `evidence/candidate_symbols.csv` 是从原版二进制中筛选出的函数符号文本清单，`evidence/source_inventory.json` 记录原文件名、哈希和容器元数据；两者不含原始二进制内容。`docs/INIT_GITHUB_AND_CODEX.md` 保留了初始化包最初建议私有仓库的方案，仓库实际可见性由所有者选择。

## 已完成工作（基于实际上传文件）

1. APK 中 `lib/armeabi/libdefault.so` 为 **ARM ELF32**，保留 `.symtab` 和大量 C++ 符号。提取并生成 **454 条候选函数符号清单** `evidence/candidate_symbols.csv`（类别：资源、战斗、动画、输入）。
2. 外部 `data.zpak` 是 ZIP；包含 `Core.pakh`、`Core.pakd000` 和 `metadata.xml`。实际解析器已在完整原包中验证 2144 条索引、417 个目录节点和 2265 条文件路径，尾部 CRC 为 `0xeee1e38a`。
3. `Core.pakd000` 的 2144 个跨块连续 zlib 流已全部读取，共解码 325,791,952 字节；物理偏移、存储长度、解码长度和目录标识全部一致。早期“第 5 个流截断”的判断已纠正。详情见 `docs/PAK_DECODE_FINDINGS.md`。
4. 创建 Godot 4.7.x 兼容的 3D PC 战斗场景原型：人物对战、双向移动/侧移、3 种攻击、格挡、受击状态、血量、回合重开、简易对手 AI。
5. 提供 PowerShell `build_windows.ps1` 和 `validate_windows_exe.ps1`；已使用
   Godot 4.7.2 Windows Export Templates 生成并在仓库外验证原生 Windows
   EXE/PCK，非安卓模拟器。
6. 三条真实 ANM 的轨道声明指针、轨道组、raw-fixed Q12/Q14 和五条 wavelet 轨道的逐帧候选值已由实际资源与静态原生指令交叉核对。候选值尚未经过原生运行时对照或 Godot 动画播放验证。测试命令和退出码见 `docs/SKL_ANM_FORMAT_FINDINGS.md`。
7. Hair/Body 的 Mesh subset、材质名、`diffuse`、`normal`、`material` 外部纹理引用、`Diffuse.program` 纹理常量以及原生 `CMaterial::Init` → `CManager::GetTexture` 数据流已静态闭合；运行时 draw call 与 GPU 最终像素仍未对照。详情见 `docs/MATERIAL_TEXTURE_BINDING_FINDINGS.md`。
8. Bruce Lee 对象的 `scene/childs` 相对字典已解析为 78 个唯一节点，并与 78 组姿态 section 一一对应。`gid_Type` 的对象、摄像机、灯光、分组、反射体和 primitive 六条创建路径都含有到 `Link` 的直接调用；类型不匹配仍回退到 `AddChild`。详情见 `docs/OBJ_FORMAT_FINDINGS.md`。
9. `CScnObj::Commit` 到 `CRenderTargetBase::Commit`、`CGeometryBatcher::Commit`、`CRenderPrimitive::Draw` 和 `CProgram::Draw` 的静态批处理路径已核对，最终入口是 `glDrawElements/glDrawArrays`；具体对象的 draw-call 次数和 GPU 像素仍未验证。
10. `CScnObj::Commit` 按视觉项和 pass 过滤逐个提交 subset。Body 两个视觉项最多形成 4 个 primitive 入批，Hair 两个独立视觉项各最多 1 个；这些入批上限不等于最终 OpenGL draw-call 次数。
11. `CShaderInstance+0x50` 的 variation pass 位图、`CVisual+0x24` 的实例并集和 `CScnObj::Commit` 的 `1 << pass` 过滤已静态核对；材质/批处理键仍未闭合。
12. `CGeometryBatcher` 已确认按 `(j, TBatchID[0], TBatchID[1])` 三元键合并相邻 primitive；字段业务语义仍需从调用方追踪。
13. `CRenderTargetBase::Commit` 已确认以 `CRenderTargetBase+0xCC` 槽位索引 `CShaderInstance+0xD4` 表并复制 TBatchID 两个字；构造函数初始化 0x80 字节，但 `_Update` 有 32 次 8 字节写入，完整表边界和字段业务语义仍未闭合。
14. `lowpunch1/lowkick1` 的帧数、伤害、半径和 impact 字段已从本地 fighting-set 元数据加载到 Godot 配置。命中距离现在按原生公式
    `attackRadius × attackerRadiusScale + defenderAnimationRadius` 计算，并以候选模型
    `173.416 → 1.8` 的高度比例转换到 Godot 世界；该换算属于 `CANDIDATE`，仍未证明原版场景另有全局缩放或位置修正。`prototype_push` 仍为原型值。
15. `brucelee.set` 的 396 条战斗 links、normal 正面受击映射、格挡映射、反应动作返回窗口及对应 ANM 时长已只读导出到 `reports/reaction_action_inventory.json`。Godot 的 `hitstun/blockstun` 已按 reaction return frame 配置驱动，并保留 `CANDIDATE` 边界；`push` 仍使用原型规则。
16. reaction root-motion 取证已导出 `positions` 逐帧值、轨道存在性和 ANM 哈希到 `reports/reaction_root_motion_inventory.json`，并由 16 条原生变换链指令校验。当前尚未把任何坐标轴映射为 Godot `push`。
17. 玩家 Bruce 和电脑 Brick 已分别加载独立候选 GLB、动作映射与动画节点；Brick 可使用 `m03_*` idle/punch/kick/movefwd。此接入仍是原型：Brick PNG 尚未解码，Brick 原版 fighting set、命中参数、reaction 和 AI 未恢复；候选动画的未验证角色位移轨道已禁用。

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

把用户自己的 APK 和 `data.zpak` 放在本地，例如 `D:\BruceLee\`。导出原始或解码资源前，确认目标目录位于仓库之外且不受同步软件同步；下例中的 `%LOCALAPPDATA%` 也需要先确认没有被重定向或同步。

```powershell
py -3.11 tools\inventory.py --apk 'D:\BruceLee\Bruce Lee Dragon Warrior v1.15.26.apk' --zpak 'D:\BruceLee\data.zpak' --out evidence\inventory_local.json
py -3.11 tools\pak_extract.py 'D:\BruceLee\data.zpak' --expected-zpak-sha256 364b30a10991d6fdc48bb3e1655e19538caee75bd6ddf81962524647e4cab05c --report "$env:LOCALAPPDATA\BruceLee-PC-Port\pak-verification.json"
py -3.11 tools\pak_probe.py 'D:\BruceLee\data.zpak' --limit 20 --csv evidence\frames_local.csv --extract-verified "$env:LOCALAPPDATA\BruceLee-PC-Port\decoded-frames"
```

这些工具**不执行 APK 代码，也不解密、绕过 DRM 或下载游戏内容**。`pak_extract.py` 支持验证跨块流及按需导出，并从 PAKH 的扁平目录节点重建父目录/子目录关系、校验资源标识覆盖和尾部 CRC；已解析路径保存在 `path_candidates` 中。多路径共享及文件记录 `type_word`/`tag` 的业务语义仍未知。`pak_probe.py` 是先前针对独立流的探测工具，不应把它对多块流的停止当作原包截断。某个输出为 `RIFF`，只证明这是有效 WAV，不证明对应具体游戏事件。

只提取特定角色、骨骼或动作资源时，使用已校验的目录路径筛选并输出到仓库外：

```powershell
py -3.12 tools\pak_extract.py 'D:\BruceLee\Bruce Lee Dragon Warrior v1.15.26.zip' --extract-named "$env:LOCALAPPDATA\BruceLee-PC-Port\selected-resources" --select-path 'bl_brucelee' --select-path 'm01_idle'
```

对已经解出且符合当前单层 `r8g8b8a8` 格式样本的 `.tex` 流，可转换成本地 PNG：

```powershell
py -3.12 tools\tex_convert.py 'C:\private\decoded-texture.bin' --output "$env:LOCALAPPDATA\BruceLee-PC-Port\previews\texture.png"
```

转换器会校验 CTX3 字符串标识、DATA 边界、宽高、像素长度和 MD5 尾部，并强制输出到仓库外且非明显同步目录。当前不支持 mip 链或其他纹理编码；格式证据与限制见 `docs/TEX_FORMAT_FINDINGS.md`。

Godot 原型会尝试从默认位置 `%LOCALAPPDATA%\BruceLee-PC-Port\local-assets\sprites\background.png` 加载本地背景；也可用环境变量 `BRUCELEE_BACKGROUND_PATH` 指定路径。HUD 还会尝试加载同目录结构中转换出的 `gui/images/hud/bl_hud_round_yellow_left.png`。文件不存在时继续使用占位场景和纯程序 HUD。该机制用于本机资源验证，原版图片仍不进入 Git。

对符合已观察格式的本机 `.anm`，可显式查看 wavelet 逐帧候选值：

```powershell
python -B -X utf8 tools\kdf_animation.py 'C:\private\m01_pnch_low_01.anm' --decode-wavelet --values
```

输出包含由原版资源导出的数据，仅限本机使用，不能放入仓库或同步目录。
候选数值不代表动画绑定或实机播放已经通过；格式边界、验证结果与局限
见 `docs/SKL_ANM_FORMAT_FINDINGS.md`。

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
├── tools/{inventory,pak_probe,pak_extract,native_symbols,extract_inputs,kdf_strings,kdf_data,kdf_animation,kdf_wavelet,kdf_skeleton,kdf_object,kdf_mesh,mesh_to_obj,character_to_gltf,tex_convert}.py
├── tests/{test_tools,test_pak_extract,test_kdf_strings,test_kdf_data,test_kdf_animation,test_kdf_wavelet,test_kdf_skeleton,test_kdf_object,test_kdf_mesh,test_tex_convert}.py
├── evidence/
│   ├── source_inventory.json
│   ├── candidate_symbols.csv
│   ├── pak_frames.csv
│   └── decoded_frames/   # 忽略目录；本机样本另存位置见上方说明
└── docs/{PHASES,PAK_DECODE_FINDINGS,KDF_STRING_FINDINGS,TEX_FORMAT_FINDINGS,NATIVE_ANIMATION_EVIDENCE,SKL_ANM_FORMAT_FINDINGS,OBJ_FORMAT_FINDINGS,MATERIAL_TEXTURE_BINDING_FINDINGS,MESH_FORMAT_FINDINGS,GHIDRA_PLAN,LEGAL}.md
```

## 需要避免的错误

- APK 里的 `.so` 是 ARM/Android 目标，不能直接重命名为 `.dll` 在 Windows x64 下加载。
- ZPAK 是 ZIP **外壳**，`Core.pakd000` 不是普通 ZIP；不能拿 zlib 流的顺序直接假定模型文件名。
- 符号名称 `CFighter::AttackDamage` 说明有相关功能，不等于具体伤害数值或连招规则已恢复。
- 音频、图片、模型、人物肖像、商标的使用和公开发行可能受到版权、许可与其他权利限制。此研究工程不携带原版完整 APK/ZPAK 文件，不授权公开分发游戏资产。

## 下一步

请参看 `docs/PHASES.md`。PAK 索引、路径和解压范围已恢复；当前首要阻塞项是 `mesh` / `anm` / `skl` 私有载荷格式，以及把真实 Bruce Lee 模型、骨骼和 idle/punch/kick 动画转换为 Godot 可读资源。优先结合真实样本字节、`CAnimRes` / `CAnimationDescr` 函数入口和 **Linux/WSL2 + Ghidra** 做交叉验证。
