# 本地候选动画 GLB 导出

转换器将经验证的 Mesh、Skl 和 ANM 绑定为候选 GLB。输入可从用户指定的本地
路径只读加载，包括工作区；原始游戏资产不得提交。输出必须位于仓库及已知
同步目录之外。ANM 骨架引用与提供的 Skl SHA-256 必须同时匹配。工具只读取
输入，并拒绝覆盖已有输出；写入完整的临时文件后，以不覆盖方式发布。
Windows 使用同目录重命名并拒绝已存在的目标；POSIX 使用不覆盖的同目录
硬链接后删除临时文件，若文件系统不支持硬链接则报错。

`--include-object-transforms`、骨骼姿态组合、坐标空间、动画插值和根运动
均为候选实现，尚未通过原版运行时逐帧对照。导出成功或 Godot 能播放不能
证明动作方向、物理位移、关节姿态及战斗行为与原版一致。

## 本机九段验证

以下路径为本机示例，需要已使用只读 PAK 提取工具准备用户自己的资源。
输出路径需选择**不存在的新文件**。来源骨架的 SHA-256 为
`4a6d4532b42d6cbee3016b849befc2dc98c089e72fa4cfe291d9550f059412e3`。

```powershell
$taskRoot = 'C:\Users\Lenovo\AppData\Local\BruceLee-PC-Port'
$assetRoot = Join-Path $taskRoot 'validation-f0c9a3a-20261029\adreno_200'
$animRoot = Join-Path $taskRoot 'reaction-candidate-20261030'
$meshRoot = Join-Path $taskRoot 'mesh-format-20261029\adreno_200\objects\hw\bl_brucelee_01_high\meshes'
$taskOutput = Join-Path $animRoot 'bruce_candidate_windows_rename_verify.glb'
$converterArgs = @(
    (Join-Path $meshRoot 'bl_brucelee_01_body_hw_skhigh.Mesh'),
    '--skeleton', (Join-Path $assetRoot 'skeletons\bl_brucelee_01_High.Skl'),
    '--include-object-transforms',
    '--expected-skeleton-reference', 'skeletons/bl_brucelee_01_high.skl',
    '--expected-skeleton-sha256', '4a6d4532b42d6cbee3016b849befc2dc98c089e72fa4cfe291d9550f059412e3',
    '--rigid-attachment', (Join-Path $meshRoot 'bl_brucelee_01_hair_hw_skhigh.Mesh'),
    'bl_brucelee_01_hair_hw_skhigh', '--output', $taskOutput
)
foreach ($name in @('m01_idle_01.anm', 'm01_pnch_low_01.anm', 'm01_kick_low_01.anm')) {
    $converterArgs += @('--animation', (Join-Path $assetRoot "animation\$name"))
}
foreach ($name in @('all_block_high.anm', 'all_block_low.anm', 'all_block_mid.anm',
        'all_impct_light_frnt_high.anm', 'all_impct_light_frnt_low.anm',
        'all_impct_light_frnt_mid.anm')) {
    $converterArgs += @('--animation', (Join-Path $animRoot $name))
}
py -3.12 -X utf8 -B tools/character_to_gltf.py @converterArgs
```

本机执行退出码 0，输出 557,144 字节，SHA-256 为
`c8f6bb23b5ad91a94e6c743afed8cee46cfe48df466668070c97434815c22e8c`，
与迁移前本机候选文件一致。通过只读 `kdf_fighting_set.read_archive_resource`
逐项核对 Skl、两个 Mesh、九个 ANM 与用户本机外层 ZIP 的 SHA-256 一致；
另读取 GLB 头和 JSON，确认九个动作名称、来源 ANM 哈希及非空通道。上述
检查均退出码 0，不代表九段动画已逐帧视觉验收。

验证命令及结果：

```powershell
py -3.12 -X utf8 -B -m unittest discover -s tests -p 'test*.py' -q
# 177 tests, OK (1 skipped), exit 0

$godot = 'C:\Users\Lenovo\AppData\Local\BruceLee-PC-Port\godot-portable-773280yg\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --editor --path godot --quit
# exit 0
& $godot --headless --path godot --script res://tests/validate_candidate_animation.gd -- $taskOutput --expect-hair
# exit 0: checks 69 bones and idle/punch/kick, including head/hair motion

git diff --check
# exit 0
```

Godot 校验脚本使用相同 SHA-256 的首次迁移输出 `bruce_candidate_migration_verify.glb`，
目前只检查 idle/punch/kick 三段；另外六段受击和格挡动作的
本轮证据为来源哈希及 glTF 结构检查，不能据此宣称其视觉表现已验收。
本机 Windows 缺少创建符号链接的权限，输出悬空符号链接的回归测试被跳过；
真实 Windows 同目录重命名、并发目标不覆盖、失败清理及输出目录限制测试均通过。
测试通过阻止硬链接调用确认 Windows 发布不依赖硬链接；当前未在 FAT32、exFAT
或 POSIX 文件系统实测。

旧版只包含 object 层级而没有已观察对象采样声明的 Skl 仍可解析基础层级并
导出静态模型；此时 `object_static_transforms` 为 `None`。显式启用对象变换
或执行动画绑定时，缺失或不完整的对象变换会被拒绝，且不会生成 GLB。
