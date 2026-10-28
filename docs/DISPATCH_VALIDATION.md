# 接单器修复验证记录

日期：2026-10-28。环境：Windows 11 64 位、Python 3.12.10、Git 2.56.0、Codex CLI 0.164.0。

- `codex -c 'windows.sandbox="mxc"' sandbox --include-managed-config --permission-profile ':workspace' -- cmd.exe /d /c echo MXC_OK`：退出码 0。
- 在 Windows MXC 沙箱内运行 `tests` 和 `automation` 的 `unittest` 套件：25 项通过、退出码 0。测试使用 Git 索引内容的临时快照；运行前的探针确认沙箱进程无法读取快照外的测试文件，也无法连接本机测试端口。
- 在临时 Git 仓库中检查实际索引对象：已暂存的伪装二进制和模拟凭据均被拒绝，错误未输出凭据；工作区文件与暂存内容不同时，以暂存内容为准。验证程序退出码 0。
- 在临时仓库、临时本地远端和 MXC 中模拟完整控制流：正常文本会进入提交及模拟的 Draft PR 流程；测试失败和二进制内容均在提交或模拟推送前停止。GitHub 写入、对外推送与 Codex 任务调用均使用模拟，验证程序退出码 0。
- 在临时仓库执行 `python -X utf8 automation/codex_dispatch.py --dry-run`：退出码 0；实际只读查询识别出 Issue #1，临时仓库保持干净。此预检未领取 Issue、未创建 PR。

早期隔离测试暴露了 Windows 沙箱临时目录和较长路径问题；调整临时目录后复测通过。

上述结果不证明 Codex 实际任务、远程分支推送或 GitHub PR 创建的端到端流程已经通过，也不证明 Godot 场景已运行或导出。内容扫描只能拦截已实现的规则，不能证明文本没有秘密或未经授权的内容；公开仓库中的任务分支推送后立即可见。
