# 本机 Codex Issue 自动接单器

ChatGPT 可以通过 GitHub 连接创建 Issue，但**只有用户启动本机接单器后，任务才会在这台电脑的 Codex CLI 中执行**。创建 Issue 本身不会远程启动 Codex。

## 安全边界

- 只接收由 wucong220 创建、状态 Open、包含 codex-ready 标签的 Issue；评论、陌生账号的 Issue 不执行。
- 仅在无未提交改动的 main 分支开始任务，要求 origin 指向 wucong220/brucelee-pc-port，创建独立分支 codex/issue-N。
- Codex 使用 `codex exec --sandbox workspace-write`，不会启用 --yolo；提示词禁止静默安装软件、访问凭证或下载原版游戏内容。此提示词不是强制的读取权限控制，Codex 自身的可读范围、网络与已连接工具仍取决于本机配置；不要把敏感数据放入工作区。
- 检查 Git **索引中的实际字节**：只允许指定路径和普通 UTF-8 文本文件，拒绝符号链接、常见二进制特征、控制字符和部分常见凭据格式；检查前后及提交后比对树标识。检测不能保证发现所有秘密、编码后的数据或未授权内容。
- 测试在暂存内容的临时快照中通过 Windows MXC 沙箱执行，单独限制工作区外读取、禁用网络并在测试前做本机边界探针；不继承常见凭据环境变量。`tests` 和 `automation` 均必须发现并通过测试；沙箱不可用、探针失败、测试失败或索引变化时，停止提交、推送和创建 PR，不退回到本机无隔离执行。
- 成功后自动推送任务分支并创建 Draft PR，不自动合并或推送 main。**本仓库是公开的：一旦推送，分支内容立即公开，Draft PR 不会隐藏内容。** 自动检查不能替代发布前的人工授权和内容审查；如果不能接受自动公开，不要运行 `--once` 或 `--watch`。
- 原始 Codex 输出和隔离测试日志仅保存在本机 LOCALAPPDATA 目录；日志本身也需注意保密。
- 为降低误操作，单次启动只执行一条任务；失败不自动重试，保留任务分支和日志。

## Windows 首次启用

在已安装 Git、GitHub CLI、支持 MXC 的 Codex CLI 和 Python 3.12 的 Windows 项目根目录打开 PowerShell。先确认 `gh auth status` 和 `codex login status` 显示正常认证，密钥不得粘贴到 Issue。自动测试隔离目前仅验证 Windows MXC；其他平台或不支持 MXC 时会停止，不会运行无隔离测试。

先执行安全预检：

```powershell
py -3.12 automation/codex_dispatch.py --dry-run
```

`--dry-run` 用合成测试检查实际沙箱边界，并只读查询待办；不会启动 Codex 任务或修改仓库、Issue，但会在本机日志目录使用锁和保存预检日志。它不证明实际任务、Godot 或 PR 流程已经验证。

确认检测到目标 Issue 后，执行一个任务：

```powershell
py -3.12 automation/codex_dispatch.py --once
```

成功后接单器会立即推送公开任务分支并创建 Draft PR。审查 PR 的授权、凭证、测试日志和真正完成的功能；如需人工检查后才上传，应暂不启用该自动流程。
人工合并 PR 后在本机执行：

```powershell
git switch main
git pull --ff-only origin main
```

要启动持续轮询模式（必须保持终端存活）：

```powershell
py -3.12 automation/codex_dispatch.py --watch --interval 90
```

每完成一条任务就退出，防止自动连续执行未经审查的事项；不是开机自启服务。后续如确需无人值守可另行配置 Windows 任务计划。

## 失败恢复

- 如果工作区不是干净的 main，接单器停止，不会执行 reset --hard。
- 一旦 Issue 被改为 codex-in-progress 后出错：人工检查本机日志和 codex/issue-N 分支，处理完后再决定是否重标 codex-ready。
- 内容检查、隔离或测试失败时不会提交或推送；修改可能保留在任务分支的工作区或暂存区。本机隔离日志位于 LOCALAPPDATA 下的 `BruceLee-PC-Port/codex-dispatch/`。
- Godot 等缺依赖时，只报告和验证已有能力，不伪称导出 EXE 成功。
- 不把原版商业游戏的资源或可执行文件提交到 GitHub，即使仓库设为 private 也应遵守。

项目开发阶段参见 docs/PHASES.md；当前 Issue #1 是原型的 Windows 实机验证，不是原版完整移植。
