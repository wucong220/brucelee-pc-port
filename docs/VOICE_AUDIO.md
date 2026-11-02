# Bruce Lee 原版怪叫/攻击音效

## 来源
从原版 `data.zpak` 的 `Core.pakd000` 解码，路径：

`adreno_200/sounds/voices/bruce_lee/`

保留原始 WAV，不做变调、合成或替换。包内副本：
`DragonWarrior-Voice-20261103/audio/bruce_lee/`

## 映射
- `attack_light/Hit_Light_1..9_BL.wav`：普通拳脚和连段，每个攻击动作分配原始轻攻击怪叫
- `special/m01_sp_kick_high.wav`：SPECIAL HIGH KICK
- `special/m01_sp_pnch_low.wav`：SPECIAL PUNCH LOW
- `special/M01_SP_Pnch_High.avi_OPTION_2.wav`：SPECIAL PUNCH HIGH
- `special/m01_grab_01.wav`：GRAB 1
- `special/M01_Grab_02_Back_Breaker.wav`：GRAB 2
- `special/M01_End_Attack_01...` / `M01_End_Attack_02...`：终结技 1/2
- SPECIAL LOW KICK 原包没有单独 `sp_kick_low` 人声文件，使用原始 `Hit_Light_9_BL.wav`，不伪造新录音

## 触发
- `player.attack_started` 每次攻击起手时播放一次
- 同一时间只保留一个 Bruce 语音，避免连段重叠成噪音
- 命中/格挡的物理撞击声仍由原 `Punch_Body_Light_1`、`Kick_Body_Light_1`、`Block_Arms_2` 播放

## 验证
- `validate_bruce_voice_audio`：30 个动作键加载，0 个加载错误，出拳后创建播放器
- 包内 `audio/bruce_lee` 共 21 个原始 WAV，约 2.43 MB
