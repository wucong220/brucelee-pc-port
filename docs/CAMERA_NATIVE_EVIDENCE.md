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

## 玩家移动（相对镜头/对手）
- `CFighter::UpdateOppRelativeOrientation`（Ghidra `0x1b10b0`）取对手场景坐标并用旋转矩阵计算本角色相对朝向，证明角色朝向不是固定世界 X 轴。
- 当前 PC 实现把 WASD 转成“中点极坐标”：`W/S` 改半径，`A/D` 改角度；`validate_polar_movement.gd` 检查 S 沿径向、D 沿切向。
- 尚未定位到原版把左右/上下键直接映射到半径/角度的唯一函数；该输入语义来自原版视频观察，不能冒充已反编译证明。
