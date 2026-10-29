extends RefCounted
## Measure the candidate GLB's imported bind-space geometry.
## The CPU skinning path intentionally supports only the observed glTF layout.


static func transformed_aabb(transform: Transform3D, bounds: AABB) -> AABB:
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


static func skinned_aabb(mesh_instance: MeshInstance3D) -> Dictionary:
    if mesh_instance.mesh == null or mesh_instance.skin == null:
        return {}
    if not mesh_instance.transform.is_equal_approx(Transform3D.IDENTITY):
        return {
            "error": "CPU skinning only supports the observed identity mesh transform",
        }
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


static func scene_bounds(instance: Node) -> Dictionary:
    var union: AABB
    var has_union: bool = false
    var mesh_reports: Array[Dictionary] = []
    for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        if mesh_instance.mesh == null:
            continue
        var skinned_result: Dictionary = skinned_aabb(mesh_instance)
        if skinned_result.has("error"):
            return {
                "error": "%s: %s" % [
                    mesh_instance.name, skinned_result["error"],
                ],
            }
        var bounds: AABB
        if skinned_result.has("bounds"):
            bounds = skinned_result["bounds"]
        else:
            bounds = transformed_aabb(
                mesh_instance.global_transform, mesh_instance.get_aabb()
            )
        if not has_union:
            union = bounds
            has_union = true
        else:
            union = union.merge(bounds)
        mesh_reports.append({
            "name": String(mesh_instance.name),
            "position": [bounds.position.x, bounds.position.y, bounds.position.z],
            "size": [bounds.size.x, bounds.size.y, bounds.size.z],
        })
    if not has_union:
        return {"error": "node tree has no measurable MeshInstance3D"}

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
    return {
        "error": "",
        "bounds": union,
        "meshes": mesh_reports,
        "bones": bone_reports,
    }
