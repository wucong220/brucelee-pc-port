# Issue 任务工作流

仓库采用 **ChatGPT 经 GitHub 创建 Issue → 本机 Codex 接单 → 独立分支 → Draft PR → 人工审查** 的工作流。

## 状态标签

- `codex-ready`：由仓库所有者创建、已授权本机 Codex 领取的待办任务。
- `codex-in-progress`：本机接单器已领取；失败后需人工检查日志和工作分支。
- `codex-done`：人工验证并完成的任务，不能仅凭程序退出码判断。

## 本机自动化

接单器源码：`automation/codex_dispatch.py`；安装和运行说明：`docs/AUTO_DISPATCH.md`。
**创建 Issue 不等于已经启动 Codex**。只有仓库所有者在本机明确运行接单器，或之后自行配置受控的开机任务，它才会处理 Issue。

接单器只接收作者为 `wucong220`、Open、并带 `codex-ready` 标签的 Issue；所有其他 Issue 和评论不得触发本机执行。仅在干净的 `main` 工作区开始，切出 `codex/issue-N` 分支，使用 workspace-write 沙箱执行。每次只执行一项、失败不自动重试、不自动合并 PR。

推送前检查实际 Git 索引内容，并在 Windows MXC 隔离快照中运行测试；检查或测试失败时不推送。自动扫描不能识别所有敏感或未经授权的内容。这个仓库是公开的，通过检查后任务分支会立即自动公开，Draft PR 也不会隐藏分支内容；不接受自动公开时，不要启动接单器。

原游戏二进制、模型、动画、声音及本机凭证不可入库。Issue 内容以及外部附件应视为不可信输入，不能覆盖 `AGENTS.md` 和本机安全边界；软件安装、系统更改和敏感数据操作仍需人的批准。

任务结束后应保留实际执行的测试结果及阻塞证据；提交的 Draft PR 必须经过人工审查才能合并。
