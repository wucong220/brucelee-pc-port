# Godot 真实资源候选集成

本分支提供在仓库外加载 Bruce Lee 候选 GLB 和 Hair/Body 纹理的 Godot 接线。
仓库不包含原版 APK、ZPAK、SO、模型、纹理、动画或转换后的二进制资产。

## 输入

- 候选 GLB：`body_hair_idle_punch_kick_candidate.glb`
- 纹理目录：`body_diffuse.png`、`body_normal.png`、`body_material.png`、
  `hair_diffuse.png`、`hair_normal.png`、`hair_material.png`
- Godot 4.7.2 stable

两个输入必须位于仓库外。Godot 运行时的 GLB/纹理加载器会拒绝仓库内路径；
设置环境变量或使用一键验证脚本：

```powershell
.\validate_candidate.ps1 `
  -CandidateGlb 'C:\private\body_hair_idle_punch_kick_candidate.glb' `
  -TextureRoot 'C:\private\candidate-textures' `
  -GodotExe 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe'
```

脚本先执行 Python 测试，再运行一次无界面 Godot 导入，随后验证普通战斗 smoke、
真实动画、真实纹理和端到端战斗。

`validate_candidate_textures.gd` 使用程序生成的 4×4 PNG 验证材质装配和 shader
选择；真实纹理文件由 `validate_combat_candidate.gd` 加载。两者都不等于原版
GPU 最终像素、法线方向或 Alpha 混合效果已经验收。

## 已验证

`LOCAL_TESTED + CANDIDATE`：

- 69 根骨骼、idle/punch/kick 三段动画。
- 动画验证固定检查 69 根骨骼、关键骨骼索引/名称以及三段动画时长。
- 头发作为 head 下的无蒙皮附件随头部移动。
- Body 使用 opaque shader，Hair 使用 blend shader。
- 六张 Hair/Body 纹理和三项 shader 参数加载成功。
- 真实 GLB、纹理、idle/punch 动画和战斗状态可在同一场景联动。
- `lowpunch1` 使用帧 5–8、`lowkick1` 使用帧 7–10，基础伤害均为 5。
- 帧边界、大步长跨阶段不丢时以及单次命中去重由 Godot 回归测试覆盖。

本地验证输出：

```text
PROTOTYPE_VALIDATION={"blocked_kick_target_health":99.4,"ko_and_restart":true,"punch_target_health":95.0}
COMBAT_CANDIDATE_VALIDATION={"candidate_loaded":true,"candidate_textures_loaded":true,"candidate_visual_height":1.8,"idle_clip":"m01_idle_01","punch_clip":"m01_pnch_low_01","punch_target_health":95.0}
CANDIDATE_VALIDATION=PASS
```

## 边界

- 尚未与原版 Adreno 画面逐帧、逐像素对照。
- 格挡减伤、攻击距离、推力和 `heavy` 仍使用原型规则。
- `attack_radius/body_part/height/strength/direction` 已作为候选元数据保存，
  但其运行时碰撞和受击反馈映射尚未闭合。
- 未验证 Windows EXE/PCK 在目标机器上的导出和运行。
- 本分支测试通过不等于原版角色动画、光照、碰撞或战斗规则已完成运行时复刻。
