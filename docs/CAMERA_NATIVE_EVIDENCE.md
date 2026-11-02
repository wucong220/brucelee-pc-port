# 原生相机证据（CBeatEmUpCamera）

## 反编译链
- `krm::CBeatEmUpGame::CameraUpdate`（Ghidra 地址 `0x188d88`；符号表值 `0x178d88` 存在 0x10000 镜像基址偏移）先读取双方角色位置，再调用：
  `krm::CBeatEmUpCamera::Update(camera, time, player_pos, opponent_pos, ...)`
- `krm::CBeatEmUpCamera::Update`（Ghidra 地址 `0x244230`）使用双方位置的差值、距离和中点，计算镜头位置；没有发现“强制 player 在左侧”或“按 player 在左/右旋转 180°”的分支。
- 镜头参数（距离、FOV、阻尼）来自原型/候选，不是本文件证明的原版数值。

## 行为
- 相机围绕双方中点，位于两人水平连线的垂直平分线上。
- 因此两人的连线在屏幕上保持水平，双方始终面向对方。
- W/S 是前后（S=stepback、W=stepfwd），A/D 是左右侧移（A=stepleft、D=stepright）。
- 镜头保持两人连线水平，因此 S 不会把人物和敌人错位；输入是屏幕绝对方向，玩家在左或在右都用 S + D + L。

## 验证
- `validate_fight_camera.gd`：检查双方投影 y 差 ≤ 2px，并覆盖左右交换和深度移动轨迹。
- `validate_special_high_kick_input.gd`：S + D + L。
- `validate_special_high_kick_mirror.gd`：右侧同样 S + D + L，由镜头旋转保持相对位置。
