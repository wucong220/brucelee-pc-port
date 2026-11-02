# Bruce 受害方候选（本地）

## 目的

为 Brick 的 grabcompl/endattack 准备 Bruce 的受害动画。原始 59 段候选没有这些
clip，因此不把 grabcompl/endattack 写进运行时。

## 已解出并合并的 clip

- `all_grabbed_01_forset03`
- `all_grabbed_02_forset03`
- `all_end_attack_01_forset03`
- `all_end_attack_02_forset03`

## 本地候选

- `D:\BruceLeeWork\bruce_candidate_63_victim_20261102.glb`
- 5,156,692 字节
- SHA-256 `6b7b583da4950fec2dd62da7c7c2736306ffbe71b63180e0c13442a5292404cf`

Godot 验证：

```text
BRUCE_VICTIM_CANDIDATE_VALIDATION={"animations":63,"victim_clips":[
  "all_grabbed_01_forset03","all_grabbed_02_forset03",
  "all_end_attack_01_forset03","all_end_attack_02_forset03"]}
```

## 合并方式

新增只读/离线工具 `tools/merge_glb_animations.py`：从独立受害动画 GLB 复制
animation accessor、bufferView 和二进制数据，按节点名称重映射 channel，不重建
网格、材质或 skin。工具已有 Python 回归测试。

该候选仍只保存在仓库外，不进入 Git。

运行时已接入受击侧 `grabbed1`/`grabbed2`：Brick `grab1_brick`/`grab2_brick`
命中后，玩家播放 `all_grabbed_01/02_forset03`，按档案分别回到 `facedownidle`
和 `faceupidle`。`validate_brick_grab_victim.gd` 用真实物理帧验证了状态进入、
返回、以及 6/20 伤害。`endattack`/grabcompl 攻击方链仍未接入；不能因为受击
状态完成就声称完整 grabcompl/endattack 已完成。
