# Bruce voice 导出包加载说明

2026-11-03 实测结论：

- 原始 WAV 位于包内 `audio/bruce_lee`，共 21 个，PCM16 mono，格式正常。
- 导出运行时 `CandidatePathGuard.external_path_error()` 会把可执行文件目录当作
  repository_root，因此直接指向包内 `audio/bruce_lee` 的 `BRUCELEE_VOICE_ROOT`
  会被拒绝。
- 唯一可加载路径是外部 staging：
  `%LOCALAPPDATA%\BruceLee-PC-Port\bruce-voice-20261103\adreno_200\sounds\voices\bruce_lee`
- 启动脚本必须把包内 WAV **真实复制**到该目录，不能用 junction/软链（realpath
  会落回包内并被拒绝），然后设置 `BRUCELEE_VOICE_ROOT` 到该外部目录。
- 干净 staging 实测：`voice_loaded=30, voice_errors=0`；无 staging 时：
  `voice_loaded=0, voice_errors=30`，复现“只有击打音效、没有怪叫”。
- 当前 `voices` 表 30 条只引用 15/21 个文件；`M01_victory_01_Big_Scream.wav`、
  `M01_intro_01_Steps_BL_Voice.wav` 和 pain 系列等 6 个未被引用，后续需补触发时机。
