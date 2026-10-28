# 本机 Codex Issue 自动接单器

ChatGPT 可以通过 GitHub 连接创建 Issue，但**只有用户启动本机接单器后，任务才会在这台电脑的 Codex CLI 中执行**。创建 Issue 本身不会远程启动 Codex。

## 安全边界

- 只接收由 wucong220 创建、状态 Open、包含 codex-ready 标签的 Issue；评论、陌生账号的 Issue 不执行。
- 仅在无未提交改动的 main 分支开始任务，要求 origin 指向 wucong220/brucelee-pc-port，创建独立分支 codex/issue-N。
- Codex 使用 `codex exec --sandbox workspace-write`，不会启用 --yolo；不允许静默安装软件、访问凭证或下载原版游戏内容。
- 只暂存限定目录内的源码、文本配置、测试和报告，且检验扩展名、大小、符号链接；原版 APK、ZPAK、SO、PAK、模型、音效、EXE 均不上传。**这些检查不能替代审查和独立沙箱**。
- 本地运行完成后自动创建 Draft PR，等待人工审查；绝不自动合并或直接推送 main。日志仅保存在本机 LOCALAPPDATA 目录。
- 为降低误操作，单次启动只执行一条任务；失败不自动重试，保留任务分支和日志。

## Windows 首次启用

在已安装 Git、GitHub CLI、Codex CLI 和 Python 3.12 的项目根目录打开 PowerShell。先确认 `gh auth status` 和 `codex login status` 显示正常认证，密钥不得粘贴到 Issue。

先执行安全预检：

```powershell
py -3.12 automation/codex_dispatch.py --dry-run
py -3.12 -m unittest discover -s automation -p 'test_*.py' -v
```

确认检测到目标 Issue 后，执行一个任务：

```powershell
py -3.12 automation/codex_dispatch.py --once
```

成功后接单器会推送任务分支并创建 Draft PR。审查 PR，确保没有原版资产、凭证，检查测试日志和真正完成的功能。
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
- Godot 等缺依赖时，只报告和验证已有能力，不伪称导出 EXE 成功。
- 不把原版商业游戏的资源或可执行文件提交到 GitHub，即使仓库设为 private 也应遵守。

项目开发阶段参见 docs/PHASES.md；当前 Issue #1 是原型的 Windows 实机验证，不是原版完整移植。
