extends SceneTree
## Load a local candidate GLB without copying it into the project.
## Example:
## godot --headless --path godot --script res://tests/validate_candidate_animation.gd \
##     -- C:/private/candidate.glb --expect-hair

const EXPECTED_BONE_COUNT: int = 69
const EXPECTED_BONES: Dictionary = {
    0: "pelvis",
    5: "head",
    32: "l hand",
    48: "r hand",
    63: "l foot",
    67: "r foot",
    68: "r toe0",
}
const EXPECTED_ANIMATION_LENGTHS: Dictionary = {
    "m01_idle_01": 3.666,
    "m01_pnch_low_01": 2.300,
    "m01_kick_low_01": 2.866,
}
const ANIMATION_LENGTH_TOLERANCE: float = 0.001


func _initialize() -> void:
    call_deferred("_run_check")


func _run_check() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty() or args.size() > 2:
        push_error("Expected a local GLB path and optional --expect-hair")
        quit(1)
        return
    if args.size() == 2 and args[1] != "--expect-hair":
        push_error("Unknown argument: " + args[1])
        quit(1)
        return
    var expect_hair: bool = args.size() == 2
    var document: GLTFDocument = GLTFDocument.new()
    var state: GLTFState = GLTFState.new()
    var error: Error = document.append_from_file(args[0], state)
    if error != OK:
        push_error("Local GLB could not be loaded: " + str(error))
        quit(1)
        return
    var instance: Node = document.generate_scene(state)
    if instance == null:
        push_error("Local GLB scene could not be generated")
        quit(1)
        return
    root.add_child(instance)
    var players: Array[Node] = instance.find_children("*", "AnimationPlayer", true, false)
    var skeletons: Array[Node] = instance.find_children("*", "Skeleton3D", true, false)
    if players.size() != 1 or skeletons.size() != 1:
        push_error("Expected one AnimationPlayer and one Skeleton3D")
        quit(1)
        return
    var player: AnimationPlayer = players[0]
    var skeleton: Skeleton3D = skeletons[0]
    if skeleton.get_bone_count() != EXPECTED_BONE_COUNT:
        push_error("Expected %d bones, found %d" % [
            EXPECTED_BONE_COUNT, skeleton.get_bone_count(),
        ])
        quit(1)
        return
    for bone_index: int in EXPECTED_BONES:
        var expected_name: String = EXPECTED_BONES[bone_index]
        if skeleton.get_bone_name(bone_index) != expected_name:
            push_error("Unexpected bone %d: expected %s, found %s" % [
                bone_index, expected_name, skeleton.get_bone_name(bone_index),
            ])
            quit(1)
            return
    var hair: MeshInstance3D
    var head: BoneAttachment3D
    if expect_hair:
        var attachments: Array[Node] = instance.find_children(
            "*rigid_attachment", "MeshInstance3D", true, false
        )
        if attachments.size() != 1:
            push_error("Expected one rigid hair attachment")
            quit(1)
            return
        hair = attachments[0]
        head = hair.get_parent().get_parent() as BoneAttachment3D
        if head == null or head.bone_name != "head" or hair.skin != null:
            push_error("Hair is not an unskinned child of the head attachment")
            quit(1)
            return

    player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var report: Dictionary = {"bones": skeleton.get_bone_count(), "animations": []}
    for animation_name in ["m01_idle_01", "m01_pnch_low_01", "m01_kick_low_01"]:
        if not player.has_animation(animation_name):
            push_error("Missing animation: " + animation_name)
            quit(1)
            return
        var animation: Animation = player.get_animation(animation_name)
        var expected_length: float = EXPECTED_ANIMATION_LENGTHS[animation_name]
        if absf(animation.length - expected_length) > ANIMATION_LENGTH_TOLERANCE:
            push_error("Unexpected %s length: %.6f, expected %.6f" % [
                animation_name, animation.length, expected_length,
            ])
            quit(1)
            return
        player.play(animation_name)
        player.seek(0.0, true)
        await process_frame
        await process_frame
        var positions: Array[Vector3] = []
        var rotations: Array[Quaternion] = []
        for bone in skeleton.get_bone_count():
            positions.append(skeleton.get_bone_pose_position(bone))
            rotations.append(skeleton.get_bone_pose_rotation(bone))
        var start_hair: Transform3D
        var start_relative: Transform3D
        if expect_hair:
            start_hair = hair.global_transform
            start_relative = head.global_transform.affine_inverse() * start_hair

        player.advance(animation.length * 0.5)
        await process_frame
        await process_frame
        var max_position_change: float = 0.0
        var max_rotation_change: float = 0.0
        for bone in skeleton.get_bone_count():
            max_position_change = maxf(
                max_position_change,
                positions[bone].distance_to(skeleton.get_bone_pose_position(bone))
            )
            var dot_value: float = absf(
                rotations[bone].dot(skeleton.get_bone_pose_rotation(bone))
            )
            max_rotation_change = maxf(
                max_rotation_change, 2.0 * acos(clampf(dot_value, 0.0, 1.0))
            )
        if max_position_change < 0.000001 and max_rotation_change < 0.000001:
            push_error("Skeleton did not move for " + animation_name)
            quit(1)
            return
        var entry: Dictionary = {
            "name": animation_name,
            "length": animation.length,
            "tracks": animation.get_track_count(),
            "max_bone_position_change": max_position_change,
            "max_bone_rotation_change_radians": max_rotation_change,
        }
        if expect_hair:
            var end_hair: Transform3D = hair.global_transform
            var end_relative: Transform3D = head.global_transform.affine_inverse() * end_hair
            var displacement: float = start_hair.origin.distance_to(end_hair.origin)
            var rotation_change: float = (
                start_hair.basis.orthonormalized().get_rotation_quaternion().angle_to(
                    end_hair.basis.orthonormalized().get_rotation_quaternion()
                )
            )
            var relative_position_error: float = (
                start_relative.origin.distance_to(end_relative.origin)
            )
            var relative_rotation_error: float = (
                start_relative.basis.orthonormalized().get_rotation_quaternion().angle_to(
                    end_relative.basis.orthonormalized().get_rotation_quaternion()
                )
            )
            if displacement < 0.000001 and absf(rotation_change) < 0.000001:
                push_error("Hair did not move for " + animation_name)
                quit(1)
                return
            if relative_position_error > 0.001 or absf(relative_rotation_error) > 0.001:
                push_error("Hair changed its transform relative to the head")
                quit(1)
                return
            entry["hair_origin_displacement"] = displacement
            entry["hair_rotation_change_radians"] = rotation_change
            entry["hair_relative_position_error"] = relative_position_error
            entry["hair_relative_rotation_error"] = relative_rotation_error
        report.animations.append(entry)
        player.stop()
    print("CANDIDATE_ANIMATION_VALIDATION=" + JSON.stringify(report))
    quit(0)
