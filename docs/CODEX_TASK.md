# 可直接复制给 Codex CLI 的下一轮实施任务

在这份工程目录运行 Codex CLI，给它以下任务（`README_zh.md` 和 `docs/` 已描述了真实完成程度和技术边界）：

---

你正在接手《Bruce Lee: Dragon Warrior》Windows 原生移植的阶段性工程，目标是最终实现 **无需安卓模拟器的 Windows x64 EXE，尽可能还原原版玩法**。

首先阅读 `README_zh.md`、`docs/PHASES.md`、`docs/GHIDRA_PLAN.md` 和 `evidence/pak_frames.csv`，不要把目前的占位 Godot 对战原型当成原版移植。

请完成以下工作，并自行测试：

**A. 完成并验证 P1**

1. 检查 PC 上已有的 Godot 标准版，优先使用兼容版本 4.7.2 stable。如果未安装，则报告缺失依赖，说明官方下载安装来源；在获授权后再安装，不要静默写系统目录。
2. 在 `godot/` 中导入项目，实际运行 Godot 编辑器的 `--headless --editor --quit`，修复所有 GDScript 语法错误与场景导入错误。
3. 运行游戏，检查移动、三种攻击、格挡、血量、AI、胜负、R 重开是否正常。若不能自动化 GUI 验证，至少完成 headless 项目解析和启动日志检查，并明确说明尚未完成哪一项验收。
4. 安装匹配版本的 Windows Export Templates，执行 `build_windows.ps1`，导出 `dist/DragonWarrior_PC_Prototype.exe` 和所需 `.pck` 文件。运行 Windows 构建物，记录启动日志，并确保不依赖 Android 模拟器。
5. 输出 `reports/P1_validation.md`，记录 Godot 版本、Windows 版本、输入检查项、截图/日志、尚未完成项。请勿用未执行的测试伪造已通过结果。

**B. 并行推进 P2 原版资源提取**

1. 在用户指定目录找到合法持有的 APK 和 `data.zpak`；确认 SHA256 与 `evidence/source_inventory.json` 一致，不覆盖用户原文件。
2. 根据 `docs/GHIDRA_PLAN.md`，配置兼容 ARM ELF32 的 Linux/WSL2 Ghidra 分析流程，定位 `CPakDFilesManager::Load`、`GetInputStream` 和 `CPackagerFileSystem::_ReadHeader`，真正确认 `Core.pakh` 的头部布局、索引、`Core.pakd000` 的流边界及压缩约束。
3. 给每个新解析的字段附函数地址、数据偏移、实际文件样本。禁止仅凭猜测给资源文件命名。
4. 实现 `tools/pak_extract.py` 的可验证版本，优先提取 10 个拥有可信名称和文件校验的资源；增加异常输入、越界、损坏数据与多块资源测试。
5. 优先验证 `mesh`、`skl`、`anm` 三类资源，尝试一套 Bruce Lee 原版 idle、punch、kick 动作与骨骼导入 Godot。

**边界**：所有原游戏文件只读；不触碰 DRM、授权/购买逻辑或远程服务；不对外传播游戏资源；不将开发阶段的程序或资源声称为已授权发行。不要将 APK/.zpak 提交到 Git 仓库。向我报告本轮实际验证通过的结果、仓库新增文件和剩余阻塞项。

---
