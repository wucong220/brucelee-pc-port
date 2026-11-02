# 原版资源覆盖进度（2026-11-03）

## 当前候选
- Bruce：`bruce_candidate_shared_reactions_20261103.glb`，91 段动画（69 段基础 + 22 个共享 `all_*` 反应）
- Brick：`brick_candidate_shared_reactions_20261103.glb`，77 段动画（52 段基础 + 25 个共享 `all_*` 反应）
- 候选均在仓库外，未提交 Git。

## 已验证
- Godot 4.7.2 headless：Bruce/Brick 均加载成功；69 骨；新增 clip 均能驱动骨架运动。
- 导出包 self-test：
  - `candidate_textures_loaded=true`
  - `opponent_candidate_loaded=true`
  - `opponent_textures_loaded=true`
  - `voice_loaded=30`, `voice_errors=0`

## 仍未完成
- 新增共享反应动画尚未全部映射到 `REACTION_PROFILES` 的方向/强度变体；`_build_native_reactions` 会在 clip 可用时使用原生 link 名称，但需要逐条实机验证。
- 全包资源总账仍是：角色 2/10、骨骼 2/5、场景 0/10、UI 0/128、音频约 30/203。
- 原版场景、UI、其余 8 个角色尚未导入。

## 边界
候选动画的 `object_transform_space`、逐帧视觉、命中盒、root motion 仍为 CANDIDATE，不代表原版逐帧还原。
