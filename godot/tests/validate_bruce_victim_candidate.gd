extends SceneTree
## Validate the local merged Bruce candidate and its victim animations.

const Fighter = preload("res://scripts/fighter.gd")
const VICTIM_CLIPS: Array[String] = [
    "all_grabbed_01_forset03",
    "all_grabbed_02_forset03",
    "all_end_attack_01_forset03",
    "all_end_attack_02_forset03",
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("Bruce candidate GLB path required")
        quit(1)
        return
    var instance = Fighter.new()
    instance.configure("bruce_victim", false, Color.WHITE)
    instance.configure_candidate_asset(args[0], "", Fighter.CANDIDATE_CLIPS, "body")
    root.add_child(instance)
    await process_frame
    if not instance.candidate_loaded:
        push_error("Bruce candidate failed to load: " + instance.candidate_load_error)
        quit(1)
        return
    var player: AnimationPlayer = instance.get_node_or_null("CandidateRoot") as AnimationPlayer
    if player == null:
        var players: Array[Node] = instance.find_children("*", "AnimationPlayer", true, false)
        if players.is_empty():
            push_error("No AnimationPlayer found")
            quit(1)
            return
        player = players[0] as AnimationPlayer
    var names: Array[String] = []
    for name: StringName in player.get_animation_list():
        names.append(String(name))
    if names.size() != 63:
        push_error("Expected 63 animations, got " + str(names.size()))
        quit(1)
        return
    for clip: String in VICTIM_CLIPS:
        if clip not in names:
            push_error("Missing victim clip: " + clip)
            quit(1)
            return
    print("BRUCE_VICTIM_CANDIDATE_VALIDATION=" + JSON.stringify({
        "animations": names.size(),
        "victim_clips": VICTIM_CLIPS,
    }))
    instance.queue_free()
    await process_frame
    quit(0)
