extends SceneTree
## Validate a locally generated opponent GLB without integrating it into combat.


const REQUIRED_ANIMATIONS: Array[String] = [
    "m03_idle_01",
    "m03_pnch_low_01",
    "m03_kck_low_01",
    "m03_movefwd",
]
const OPTIONAL_REACTION_ANIMATIONS: Array[String] = [
    "all_idle_face_down_forbigguy",
    "all_impct_facedwn",
    "all_impct_hard_frnt_low",
]
const COMBAT_ANIMATIONS: Array[String] = [
    "all_block_low",
    "all_block_mid",
    "all_idle_face_down_forbigguy",
    "all_impct_facedwn",
    "all_impct_hard_frnt_low",
    "m03_blck_high",
    "m03_idle_01",
    "m03_kck_high_01",
    "m03_kck_high_02",
    "m03_kck_high_03",
    "m03_kck_low_01",
    "m03_kck_low_02",
    "m03_kck_low_03",
    "m03_movefwd",
    "m03_movelft",
    "m03_moverht",
    "m03_pnch_high_01",
    "m03_pnch_high_02",
    "m03_pnch_high_03",
    "m03_pnch_low_01",
    "m03_pnch_low_02",
    "m03_pnch_low_03",
    "m03_stepbck",
    "m03_stepfwd",
    "m03_steplft",
    "m03_steprht",
]
const COMBAT_ANIMATIONS_31: Array[String] = [
    "all_block_low",
    "all_block_mid",
    "all_idle_face_down_forbigguy",
    "all_idle_face_up",
    "all_impct_facedwn",
    "all_impct_hard_frnt_high",
    "all_impct_hard_frnt_low",
    "all_impct_light_frnt_high",
    "all_impct_light_frnt_low",
    "all_impct_light_frnt_mid",
    "m03_blck_high",
    "m03_idle_01",
    "m03_kck_high_01",
    "m03_kck_high_02",
    "m03_kck_high_03",
    "m03_kck_low_01",
    "m03_kck_low_02",
    "m03_kck_low_03",
    "m03_movefwd",
    "m03_movelft",
    "m03_moverht",
    "m03_pnch_high_01",
    "m03_pnch_high_02",
    "m03_pnch_high_03",
    "m03_pnch_low_01",
    "m03_pnch_low_02",
    "m03_pnch_low_03",
    "m03_stepbck",
    "m03_stepfwd",
    "m03_steplft",
    "m03_steprht",
]
const COMBAT_ANIMATIONS_35: Array[String] = [
    "all_block_low",
    "all_block_mid",
    "all_idle_face_down_forbigguy",
    "all_idle_face_up",
    "all_impct_facedwn",
    "all_impct_hard_frnt_high",
    "all_impct_hard_frnt_low",
    "all_impct_light_frnt_high",
    "all_impct_light_frnt_low",
    "all_impct_light_frnt_mid",
    "m03_blck_high",
    "m03_idle_01",
    "m03_kck_high_01",
    "m03_kck_high_02",
    "m03_kck_high_03",
    "m03_kck_low_01",
    "m03_kck_low_02",
    "m03_kck_low_03",
    "m03_movefwd",
    "m03_movelft",
    "m03_moverht",
    "m03_pnch_high_01",
    "m03_pnch_high_02",
    "m03_pnch_high_03",
    "m03_pnch_low_01",
    "m03_pnch_low_02",
    "m03_pnch_low_03",
    "m03_sp_kck_high",
    "m03_sp_kck_low",
    "m03_sp_pnch_high",
    "m03_sp_pnch_low",
    "m03_stepbck",
    "m03_stepfwd",
    "m03_steplft",
    "m03_steprht",
]
const COMBAT_ANIMATIONS_28: Array[String] = [
    "all_block_low",
    "all_block_mid",
    "all_idle_face_down_forbigguy",
    "all_idle_face_up",
    "all_impct_facedwn",
    "all_impct_hard_frnt_high",
    "all_impct_hard_frnt_low",
    "m03_blck_high",
    "m03_idle_01",
    "m03_kck_high_01",
    "m03_kck_high_02",
    "m03_kck_high_03",
    "m03_kck_low_01",
    "m03_kck_low_02",
    "m03_kck_low_03",
    "m03_movefwd",
    "m03_movelft",
    "m03_moverht",
    "m03_pnch_high_01",
    "m03_pnch_high_02",
    "m03_pnch_high_03",
    "m03_pnch_low_01",
    "m03_pnch_low_02",
    "m03_pnch_low_03",
    "m03_stepbck",
    "m03_stepfwd",
    "m03_steplft",
    "m03_steprht",
]
const COMBAT_ANIMATIONS_27: Array[String] = [
    "all_block_low",
    "all_block_mid",
    "all_idle_face_down_forbigguy",
    "all_impct_facedwn",
    "all_impct_hard_frnt_high",
    "all_impct_hard_frnt_low",
    "m03_blck_high",
    "m03_idle_01",
    "m03_kck_high_01",
    "m03_kck_high_02",
    "m03_kck_high_03",
    "m03_kck_low_01",
    "m03_kck_low_02",
    "m03_kck_low_03",
    "m03_movefwd",
    "m03_movelft",
    "m03_moverht",
    "m03_pnch_high_01",
    "m03_pnch_high_02",
    "m03_pnch_high_03",
    "m03_pnch_low_01",
    "m03_pnch_low_02",
    "m03_pnch_low_03",
    "m03_stepbck",
    "m03_stepfwd",
    "m03_steplft",
    "m03_steprht",
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected one local opponent GLB path")
        quit(1)
        return
    var document: GLTFDocument = GLTFDocument.new()
    var state: GLTFState = GLTFState.new()
    if document.append_from_file(args[0], state) != OK:
        push_error("Opponent GLB could not be loaded")
        quit(1)
        return
    var instance: Node = document.generate_scene(state)
    if instance == null:
        push_error("Opponent GLB did not generate a scene")
        quit(1)
        return
    root.add_child(instance)
    var players: Array[Node] = instance.find_children("*", "AnimationPlayer", true, false)
    var skeletons: Array[Node] = instance.find_children("*", "Skeleton3D", true, false)
    if players.size() != 1 or skeletons.size() != 1:
        push_error("Expected one opponent AnimationPlayer and Skeleton3D")
        quit(1)
        return
    var player: AnimationPlayer = players[0]
    var skeleton: Skeleton3D = skeletons[0]
    if skeleton.get_bone_count() != 69:
        push_error("Expected 69 opponent skeleton bones, found %d" % skeleton.get_bone_count())
        quit(1)
        return
    var skinned_meshes: Array[MeshInstance3D] = []
    for mesh_instance: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
        if mesh_instance.skin != null:
            skinned_meshes.append(mesh_instance)
    if skinned_meshes.size() != 1 or skinned_meshes[0].mesh.get_surface_count() != 3:
        push_error("Expected one opponent skinned Mesh with three surfaces")
        quit(1)
        return
    var attachment_nodes: Array[Node] = instance.find_children("*rigid_attachment", "", true, false)
    if not attachment_nodes.is_empty():
        push_error("Unexpected rigid attachment in opponent GLB")
        quit(1)
        return
    var actual_names: Array[String] = []
    for name: StringName in player.get_animation_list():
        actual_names.append(String(name))
    actual_names.sort()
    var allowed_names: Array[String] = REQUIRED_ANIMATIONS.duplicate()
    allowed_names.append_array(OPTIONAL_REACTION_ANIMATIONS)
    for required_name: String in REQUIRED_ANIMATIONS:
        if required_name not in actual_names:
            push_error("Opponent animation set lacks " + required_name + ": "
                    + JSON.stringify(actual_names))
            quit(1)
            return
    var full_candidate: bool = actual_names.size() in [53, 55]
    var combat_candidate: bool = actual_names.size() in [26, 27, 28, 31, 35]
    var expected_combat: Array[String] = COMBAT_ANIMATIONS
    if actual_names.size() == 35:
        expected_combat = COMBAT_ANIMATIONS_35
    elif actual_names.size() == 31:
        expected_combat = COMBAT_ANIMATIONS_31
    elif actual_names.size() == 28:
        expected_combat = COMBAT_ANIMATIONS_28
    elif actual_names.size() == 27:
        expected_combat = COMBAT_ANIMATIONS_27
    if combat_candidate and actual_names != expected_combat:
        push_error("Combat opponent candidate animation set is not exact: "
                + JSON.stringify(actual_names))
        quit(1)
        return
    for actual_name: String in actual_names:
        if full_candidate:
            if (not actual_name.begins_with("m03_")
                    and actual_name not in ["all_block_low", "all_block_mid"]):
                push_error("Full opponent candidate has an unexpected clip: " + actual_name)
                quit(1)
                return
        elif not combat_candidate and actual_name not in allowed_names:
            push_error("Opponent animation set has an unexpected clip: " + actual_name)
            quit(1)
            return
    player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var report: Array[Dictionary] = []
    for animation_name: String in actual_names:
        var animation: Animation = player.get_animation(animation_name)
        player.play(animation_name)
        player.seek(0.0, true)
        var positions: Array[Vector3] = []
        var rotations: Array[Quaternion] = []
        for bone: int in skeleton.get_bone_count():
            positions.append(skeleton.get_bone_pose_position(bone))
            rotations.append(skeleton.get_bone_pose_rotation(bone))
        player.advance(animation.length * 0.5)
        var moved: bool = false
        for bone: int in skeleton.get_bone_count():
            if (positions[bone].distance_to(skeleton.get_bone_pose_position(bone)) > 0.00001
                    or absf(rotations[bone].dot(skeleton.get_bone_pose_rotation(bone))) < 0.99999):
                moved = true
                break
        if not moved:
            push_error("Opponent skeleton did not move for " + animation_name)
            quit(1)
            return
        report.append({
            "name": animation_name,
            "length": animation.length,
            "tracks": animation.get_track_count(),
        })
        player.stop()
    print("OPPONENT_CANDIDATE_VALIDATION=" + JSON.stringify({
        "bones": skeleton.get_bone_count(),
        "skinned_surfaces": skinned_meshes[0].mesh.get_surface_count(),
        "animations": report,
    }))
    quit(0)
