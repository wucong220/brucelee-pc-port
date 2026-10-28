# 本机初始化记录

日期：2026-10-28。项目为占位战斗原型和研究工具，不能视为原版游戏移植成品。

- 操作系统：Windows 11 64 位。
- Git：2.56.0；Python：3.12.10；GitHub CLI：2.103.0。
- 原始初始化 ZIP 的条目 CRC 校验通过；其中 4 个二进制样本已转移到 `%LOCALAPPDATA%\BruceLee-PC-Port\decoded_frames`，原始 ZIP 未修改。
- `python -m unittest discover -s tests -v`：3 项通过，退出码 0。测试使用合成数据，不能证明原版资源格式已完整解析。
- 在 PATH 和常见安装目录中未发现 Godot 可执行程序；尚未实际导入或运行 Godot 项目，也未导出或验证 Windows 构建物。
- `.gitignore` 排除原始样本、常见媒体和模型、导出物及本机凭证；它不能阻止其他同步软件上传文件，强制添加时也不能代替逐项审核。
