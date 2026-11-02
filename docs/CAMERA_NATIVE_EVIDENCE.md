# 原生相机证据（CBeatEmUpCamera）

## 反编译链
- `krm::CBeatEmUpGame::CameraUpdate`（Ghidra 地址 `0x188d88`；符号表值 `0x178d88` 存在 0x10000 镜像基址偏移）先读取双方角色位置，再调用：
  `krm::CBeatEmUpCamera::Update(camera, time, player_pos, opponent_pos, ...)`
- `krm::CBeatEmUpCamera::Update`（Ghidra 地址 `0x244230`）使用双方位置的差值、距离和中点，计算镜头位置；没有发现“强制 player 在左侧”或“按 player 在左/右旋转 180°”的分支。
- 镜头参数（距离、FOV、阻尼）来自原型/候选，不是本文件证明的原版数值。

## 行为
- 相机围绕双方中点，位于两人水平连线的垂直平分线上。
- 因此两人的连线在屏幕上保持水平，双方始终面向对方。
- 原生 step 映射：A=stepback、D=stepfwd、W=stepright、S=stepleft。
- 原生相机围绕两人中点，不锁死玩家侧位，因此可以绕完整一圈；PC 端已移除侧位锁。
- SPECIAL HIGH KICK = HOLD A + D + L，SPECIAL LOW KICK = HOLD S + D + U。

## 验证
- `validate_fight_camera.gd`：检查双方投影 y 差 ≤ 2px，并覆盖左右交换和深度移动轨迹。
- `validate_special_high_kick_input.gd`：A + D + L。
- `validate_special_low_kick_input.gd`：S + D + U。

## 玩家移动（相对镜头/对手）
- `CFighter::UpdateOppRelativeOrientation`（Ghidra `0x1b10b0`）取对手场景坐标并用旋转矩阵计算本角色相对朝向，证明角色朝向不是固定世界 X 轴。
- 当前 PC 实现把 WASD 转成“中点极坐标”：`A/D` 改半径，`W/S` 改角度；角速度按半径缩放，近距离不会突然高速旋转。`validate_polar_movement.gd` 检查 D 沿径向、S 沿切向。
- 尚未定位到原版把左右/上下键直接映射到半径/角度的唯一函数；该输入语义来自原版视频观察，不能冒充已反编译证明。
