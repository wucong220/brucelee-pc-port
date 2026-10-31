# 中段眩晕来源与候选验证

## 来源

`data.zpak` SHA-256 `364b30a10991d6fdc48bb3e1655e19538caee75bd6ddf81962524647e4cab05c`；`adreno_200/set/brucelee.set` SHA-256 `860b6dac1ae5043456fbf72b1cd93a5a1c76f036b3b995df5e57ce68b4d3762c`，PAKD offset 21016054，resource ID `f3d1549105ba342bc17b86a33b3834a0`。通过 `tools/kdf_fighting_set.read_archive_resource` 与 `tools/kdf_combat_reactions._parse_set` 只读解析。

直接链接：125 轻高眩晕受击→stunfall [13,17]；129 轻低→stunfall [13,16]；131 中→stunfall [15,20]；210 impactable+normal+medium+healthzero→impactstunlow；211 normal+low→impactstunlow；288 impactstunlow→stun [14,17]；284 stun→stun2 [55,61]；285 stun2→stunfall [55,61]；286 stunfall→faceupko [71,79]；134 impactsfromstun+brutal→stunbrutalimpact；133 stunbrutalimpact→facedownko [40,45]；96 canblock+brutal→highblockbrutal；346 highblockbrutal→idle2 [17,20]。brutal 格挡的原始 action/link 字段和哈希见 `reports/brutal_block_evidence.json`（link 96 conditions=impact/oppattackstrengthbrutal；link 346 time=[17,20]；action canblock=[6,20]、facing=[0,20]、radius=25；ANM `all_block_high_brutal.anm` SHA-256 `874c4e1574bcf8f2bb9361b35a83fce7fe70a7acb920d0f82a52522bf0b967f5`，header duration=20、framerate=30、version=7）。brutal 普通中段链见 `reports/impactbrutalmid_evidence.json`（link 237 conditions=impact/oppattackstrengthbrutal/oppattackheightmed/oppattackdirfrontal，entry_frame=6；link 337 time=[25,28]；ANM `all_sp_pnch_low_forset04.anm` header duration=28、framerate=30、version=7）。brutal 普通高段左右链见 `reports/impactbrutal_high_evidence.json`（links 235/236 conditions 和 301/302 [39,45]/[41,45]；两个 ANM 的 SHA-256 与 header duration=45、framerate=30、version=7）。普通方向 light 链见 `reports/normal_directional_evidence.json`（links 221/222/224/225，四个 ANM header duration=17、framerate=30、version=7；return links 293/294/295 为 [15,17]→idle，296 为 [13,17]→idle）。hard 方向链见 `reports/hard_directional_evidence.json`（links 229/231/233 和 return 298/291/316；ANM duration 分别 29/29/17、framerate=30、version=7）。hard 正面低段链见 `reports/hard_frontlow_evidence.json`（links 213/214/228，return 289 healthzero [21,23]→facedownko、299 [20,23]→facedownidle；ANM duration=23、framerate=30、version=7）。hard 正面高段致命链见 `reports/hard_fronthigh_lethal_evidence.json`（link 113 healthzero [23,29]→faceupko，114 非致命 →faceupidle；ANM 证据与动作记录一致）。组入口 126/130 normal、128 hard、132 medium、134 brutal 条件可能重叠；normal/medium 与 hard/medium 的选择是 PC 候选，不证明原版优先级；当前配置没有 brutal 来源。stunimpact 属于 impactsfromstun，但当前候选拒绝再次受击，原版重入未验证。

## impactable 来源动作及窗口

只读解析得到：idle [0,140]、stepfwd [0,20]、stepback [0,19]、movefwd [0,14]、moveback [0,17]、stepright [0,124]、stepleft [0,76]、skipback [0,76]、skipfwd [0,44]；highpunch1 [0,101]、highpunch2 [0,81]、highpunch3 [0,85]、lowpunch1 [0,69]、lowpunch2 [0,65]、lowpunch3 [0,81]；highkick1 [0,73]、highkick2 [0,95]、highkick3 [17,51]、lowkick1 [0,86]、lowkick2 [0,27]、lowkick3 [0,56]；parryhigh [30,62]、parrylow [17,27]、parryattack [15,85]；idle2 [0,43]、idle3 [0,143]；attacktofloor [0,90]；facedowngetup [12,19]、facedownattack [29,35]、faceupgetup [9,24]、faceupattack [32,38]；impactlightfronthigh [0,17]、impactlightfrontlow [0,17]、impactlightfrontmid [0,16]、impacthardfrontmid [0,30]、impactlightrighthigh [0,17]、impactlightlefthigh [0,17]、impactlightrightlow [0,17]、impactlightleftlow [0,17]；grab1miss [0,47]、grab2miss [0,14]、specialpunchlowmiss [16,33]、specialpunchhighmiss [0,122]、specialkickhigh [17,57]、specialkicklowmiss [24,50]、endattack2 [0,235]；以及对手专属动作的同名变体，当前 Bruce 候选不使用。

候选门控只映射当前可达的 idle、idle2、facedowngetup、facedownattack、attacktofloor、已识别攻击动作和已加载轻受击状态；其他状态 fail closed。中段眩晕受击选 [15,20] 的候选首帧 15；`stun/stun2` 和 `stunfall` 分别选来源窗口 [55,61]/[71,79] 的起点 55/71，不是原版精确调度。idle 使用 Default.set 的 PC 近似。

## 本地验证

Godot 4.7.2 stable headless，APPDATA/TEMP 使用本地 godot-userdata：

- `--path godot --script res://tests/validate_stun.gd -- D:/BruceLeeWork/bruce_candidate_48_hair.glb`：退出 0；输出 `STUN_VALIDATION={"animation":"all_stunned","scope":"prototype stun path for healthzero normal hits; source impactstun timing is not fully recovered","state_chain":["stun","stun2","stunfall","faceupko"]}`；日志含系统根证书存储读取错误，脚本结果成功。
- `validate_stun_heavy.gd -- D:/BruceLeeWork/bruce_candidate_50_hair.glb`：退出 0；`STUN_HEAVY_VALIDATION` 输出 hard→faceupko 与 brutal→facedownko 三例。
- `validate_ground_pose.gd -- .../bruce_candidate_23.glb .../brick_candidate_7.glb`：退出 0。
- `validate_faceup_impact.gd -- .../bruce_candidate_23.glb .../brick_candidate_7.glb`：退出 0。

candidate48 SHA-256 `d59e91193bdc30af1b3240d78cb32bb1113a405f28557fa749ae68175cbe2b7b`；candidate50 `cadd1b1b9bf53a4dbec45ac99f86a21db9686aeaf59569fe250ce0ff38b26605`。精确命令和原始日志仍以本地 shell 输出为准，未把系统证书错误当作测试失败。
