extends SceneTree
## Measure candidate geometry and key bones in the generated Godot scene.


const EXPECTED_MINIMUM_Y: float = -0.09393310546875
const EXPECTED_VISUAL_HEIGHT: float = 173.415954589844
const EXPECTED_BODY_HEIGHT: float = 166.335632324219
const EXPECTED_BONE_Y: Dictionary = {
    "pelvis": 93.4421997070313,
    "head": 149.398300170898,
    "l foot": 9.97993469238281,
    "r foot": 9.97990417480469,
    "r toe0": 0.0590057373046875,
}
const BOUNDS_TOLERANCE: float = 0.01


func _initialize() -> void:
    call_deferred("_run_check")


func _transformed_aabb(transform: Transform3D, bounds: AABB) -> AABB:
    var minimum: Vector3 = Vector3(INF, INF, INF)
    var maximum: Vector3 = Vector3(-INF, -INF, -INF)
    var high: Vector3 = bounds.position + bounds.size
    for x: float in [bounds.position.x, high.x]:
        for y: float in [bounds.position.y, high.y]:
            for z: float in [bounds.position.z, high.z]:
                var point: Vector3 = transform * Vector3(x, y, z)
                minimum = minimum.min(point)
                maximum = maximum.max(point)
    return AABB(minimum, maximum - minimum)


func _skinned_aabb(mesh_instance: MeshInstance3D) -> Dictionary:
    if mesh_instance.mesh == null or mesh_instance.skin == null:
        return {}
    var skeleton: Skeleton3D = mesh_instance.get_node_or_null(
        mesh_instance.skeleton
    ) as Skeleton3D
    if skeleton == null:
        return {"error": "skinned mesh has no Skeleton3D"}
    var minimum: Vector3 = Vector3(INF, INF, INF)
    var maximum: Vector3 = Vector3(-INF, -INF, -INF)
    for surface: int in mesh_instance.mesh.get_surface_count():
        var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var bones := PackedInt32Array(arrays[Mesh.ARRAY_BONES])
        var weights := PackedFloat32Array(arrays[Mesh.ARRAY_WEIGHTS])
        if vertices.is_empty() or bones.is_empty() or weights.is_empty():
            continue
        var influences: int = weights.size() / vertices.size()
        if influences <= 0 or bones.size() % influences != 0:
            return {"error": "invalid bone influence layout"}
        for vertex_index: int in vertices.size():
            var source: Vector3 = vertices[vertex_index]
            var skinned: Vector3 = Vector3.ZERO
            var total_weight: float = 0.0
            for influence: int in influences:
                var offset: int = vertex_index * influences + influence
                var weight: float = weights[offset]
                if weight <= 0.0:
                    continue
                var bind_index: int = bones[offset]
                var bone_index: int = mesh_instance.skin.get_bind_bone(bind_index)
                if bone_index < 0:
                    bone_index = skeleton.find_bone(
                        mesh_instance.skin.get_bind_name(bind_index)
                    )
                if bone_index < 0:
                    return {"error": "skin bind references a missing bone"}
                var skin_transform: Transform3D = (
                    skeleton.get_bone_global_pose(bone_index)
                    * mesh_instance.skin.get_bind_pose(bind_index)
                )
                skinned += (skin_transform * source) * weight
                total_weight += weight
            if total_weight <= 0.0:
                continue
            var point: Vector3 = skeleton.global_transform * (skinned / total_weight)
            minimum = minimum.min(point)
            maximum = maximum.max(point)
    if minimum.x == INF:
        return {}
    return {"bounds": AABB(minimum, maximum - minimum)}


func _run_check() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected a local GLB path")
        quit(1)
        return
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
    await process_frame
    await process_frame

    var union: AABB
    var has_union: bool = false
    var mesh_reports: Array[Dictionary] = []
    for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        if mesh_instance.mesh == null:
            continue
        var skinned_result: Dictionary = _skinned_aabb(mesh_instance)
        if skinned_result.has("error"):
            push_error(
                "Could not measure %s: %s"
                % [mesh_instance.name, skinned_result["error"]]
            )
            quit(1)
            return
        var bounds: AABB
        if skinned_result.has("bounds"):
            bounds = skinned_result["bounds"]
        else:
            bounds = _transformed_aabb(
                mesh_instance.global_transform, mesh_instance.get_aabb()
            )
        if not has_union:
            union = bounds
            has_union = true
        else:
            union = union.merge(bounds)
        mesh_reports.append({
            "name": String(mesh_instance.name),
            "local_position": [
                mesh_instance.get_aabb().position.x,
                mesh_instance.get_aabb().position.y,
                mesh_instance.get_aabb().position.z,
            ],
            "local_size": [
                mesh_instance.get_aabb().size.x,
                mesh_instance.get_aabb().size.y,
                mesh_instance.get_aabb().size.z,
            ],
            "transform_origin": [
                mesh_instance.global_transform.origin.x,
                mesh_instance.global_transform.origin.y,
                mesh_instance.global_transform.origin.z,
            ],
            "position": [bounds.position.x, bounds.position.y, bounds.position.z],
            "size": [bounds.size.x, bounds.size.y, bounds.size.z],
        })
    if not has_union:
        push_error("Candidate GLB has no measurable MeshInstance3D")
        quit(1)
        return

    var bone_reports: Dictionary = {}
    var skeletons: Array[Node] = instance.find_children("*", "Skeleton3D", true, false)
    if skeletons.size() == 1:
        var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
        for bone_name: String in ["pelvis", "head", "l foot", "r foot", "r toe0"]:
            var bone_index: int = skeleton.find_bone(bone_name)
            if bone_index >= 0:
                var pose: Transform3D = skeleton.global_transform * (
                    skeleton.get_bone_global_pose(bone_index)
                )
                bone_reports[bone_name] = [
                    pose.origin.x, pose.origin.y, pose.origin.z,
                ]

    if absf(union.position.y - EXPECTED_MINIMUM_Y) > BOUNDS_TOLERANCE:
        push_error(
            "Candidate minimum Y changed: %.6f, expected %.6f"
            % [union.position.y, EXPECTED_MINIMUM_Y]
        )
        quit(1)
        return
    if absf(union.size.y - EXPECTED_VISUAL_HEIGHT) > BOUNDS_TOLERANCE:
        push_error(
            "Candidate visual height changed: %.6f, expected %.6f"
            % [union.size.y, EXPECTED_VISUAL_HEIGHT]
        )
        quit(1)
        return
    var body_height: float = 0.0
    for mesh_report: Dictionary in mesh_reports:
        if String(mesh_report["name"]).contains("body"):
            var mesh_size: Array = mesh_report["size"]
            body_height = float(mesh_size[1])
    if absf(body_height - EXPECTED_BODY_HEIGHT) > BOUNDS_TOLERANCE:
        push_error(
            "Candidate body height changed: %.6f, expected %.6f"
            % [body_height, EXPECTED_BODY_HEIGHT]
        )
        quit(1)
        return
    for bone_name: String in EXPECTED_BONE_Y:
        if not bone_reports.has(bone_name):
            push_error("Candidate skeleton is missing bone: " + bone_name)
            quit(1)
            return
        var actual_y: float = bone_reports[bone_name][1]
        var expected_y: float = EXPECTED_BONE_Y[bone_name]
        if absf(actual_y - expected_y) > BOUNDS_TOLERANCE:
            push_error(
                "Candidate bone %s Y changed: %.6f, expected %.6f"
                % [bone_name, actual_y, expected_y]
            )
            quit(1)
            return

    print("CANDIDATE_BOUNDS=" + JSON.stringify({
        "root_position": [
            instance.global_position.x,
            instance.global_position.y,
            instance.global_position.z,
        ],
        "root_scale": [instance.scale.x, instance.scale.y, instance.scale.z],
        "position": [union.position.x, union.position.y, union.position.z],
        "size": [union.size.x, union.size.y, union.size.z],
        "body_height": body_height,
        "scale_to_1_8": 1.8 / union.size.y,
        "meshes": mesh_reports,
        "bones": bone_reports,
    }))
    quit(0)
