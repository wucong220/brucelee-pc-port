extends SceneTree
## Validate the imported candidate's bind-space geometry and key bones.


const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
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

    var measured: Dictionary = CandidateBounds.scene_bounds(instance)
    if not measured["error"].is_empty():
        push_error("Could not measure candidate bounds: " + measured["error"])
        quit(1)
        return
    var union: AABB = measured["bounds"]
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
    for mesh_report: Dictionary in measured["meshes"]:
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
    var bone_reports: Dictionary = measured["bones"]
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
        "position": [union.position.x, union.position.y, union.position.z],
        "size": [union.size.x, union.size.y, union.size.z],
        "body_height": body_height,
        "scale_to_1_8": 1.8 / union.size.y,
        "meshes": measured["meshes"],
        "bones": bone_reports,
    }))
    quit(0)
