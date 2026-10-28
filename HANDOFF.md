# 项目交接

更新时间：2026-10-28

## 目标

用 Godot 4.7.x 和 GDScript 干净重建可直接运行于 Windows 的 PC 战斗游戏，逐步还原原版资源、动画和玩法；不依赖安卓模拟器。原版 APK、ZPAK、二进制及媒体资源只保存在本机，不进入 Git。

跨会话约定：全局 `AGENTS.md` 要求按任务需要先读本文件，并在重要阶段完成后同步更新。

## Git 与 PR 状态

- `main`：`32c14f0 Document public repository scope`；工作树干净。
- PR #3 `feat/pak-stream-decode`：head `da3bb83`，OPEN、CLEAN，尚未合并。
- PR #4 `codex/kdf-string-evidence`：head `6dc32e4`，OPEN、CLEAN，尚未合并。
- PR #2 `feat/local-codex-issue-dispatch`：Draft，自动接单器属于外围工作，当前不优先。

详细格式证据见 `docs/PAK_DECODE_FINDINGS.md`、`docs/KDF_STRING_FINDINGS.md`；路线与验收标准仍以 `docs/PHASES.md` 为准。

## 已完成且可验证

- `main` 基线：Godot 占位战斗原型、输入/AI/血量/状态机、资源取证工具和本地资源保护规则已提交。
- `main` 基线测试：3 项通过，退出码 0。
- PR #3：已实现跨块 zlib 流扫描、PAKD 物理偏移与两种长度匹配、目录候选扫描、哈希/大小/输出目录保护及测试；20 项通过，退出码 0。
- PR #4：已实现只读 KDF 字符串表检查；3 个本机解码样本共 51 条记录，51 条符合当前观察到的 CRC32 加长度规则；8 项通过，退出码 0。
- 历史符号清单和原文件清单已保存在 `evidence/`，不包含原始二进制内容。

## 关键决策

- 运行时采用 Godot 4.7.x 标准版和 GDScript；原 Android ARM 代码不直接加载。
- PAK 资源以物理偏移、存储长度和解码长度共同定位；不能仅凭 key 或长度猜测映射。
- `adreno_200/` 路径扫描目前只是候选扫描，不等于已完整解析 PAKH 目录树。
- CTX3 的 CRC32 加长度规则用于校验和报告，不当作所有版本或所有对象的既定格式约束。
- 原版资源与解码结果只写入仓库外、非同步的本机目录。

## 未完成

- 审查并按依赖顺序合并 PR #3、PR #4。
- 在能访问完整原包的机器上复跑扫描，验证 2144 条流、目录候选覆盖和哈希结果。
- 完整解析 PAKH 目录树、16 字节资源标识的生成规则及多路径引用语义。
- 解析 CTX3 `DATA` 载荷、纹理、`.obj`、`.Skl`、`.anm`，完成至少一套 Bruce Lee 模型及 idle/punch/kick 动画转换。
- 在 Godot 中实际运行原型并导出 Windows EXE。
- 复核战斗输入、命中帧、伤害、硬直、AI、镜头、UI、音频和关卡。

## 已知缺陷与边界

- `main` 上的 README 和 `docs/PHASES.md` 仍描述早期的“第四条后可解码、第五条截断”状态；PR #3 尚未合并。
- 完整原包的 2144 流、2265 条目录候选及 63377 条 CTX3 字符串统计来自另一会话的全包只读报告；当前工作树不能独立复现。
- `262144` 已观察到是本包实际分块容量；原版运行时是否强制把它作为安全上限仍未知。
- `HANDOFF.md` 记录的是上述 head 和测试状态；后续合并或新增提交后应同步更新。

## 本次验证

2026-10-28 在三个干净工作树执行：

```powershell
py -3.12 -X utf8 -m unittest discover -s tests -v
```

| 工作树 | 提交 | 结果 |
|---|---|---|
| `main` | `32c14f0` | 3 项通过，退出码 0 |
| PR #3 | `da3bb83` | 20 项通过，退出码 0 |
| PR #4 | `6dc32e4` | 8 项通过，退出码 0 |

Godot 实机运行、原版模型/动画导入和 Windows EXE 导出尚未验证。

## 下一步

1. 审查 PR #3 与 PR #4，优先合并 PAK 扫描基础，再合并 KDF 字符串工具。
2. 在完整原包环境复跑 PR #3 报告，并保存命令、退出码、哈希和覆盖率。
3. 从 CTX3 纹理 `DATA` 段建立最小转换器，再转向骨骼和动画结构。
4. 导入一套真实角色与 idle/punch/kick 动画后，再做 Godot 实机验证。
