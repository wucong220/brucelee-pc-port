extends SceneTree
func _initialize() -> void:
    var path: String = "D:/BruceLeeWork/bruce_candidate_92_movefwd_20261103.glb"
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--candidate-glb="):
            path = a.trim_prefix("--candidate-glb=")
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var err: Error = doc.append_from_file(path, state)
    print("PROBE_GLB err=", err)
    var scene: Node = doc.generate_scene(state)
    print("PROBE_GLB scene=", scene)
    if scene != null:
        var players: Array[Node] = scene.find_children("*", "AnimationPlayer", true, false)
        print("PROBE_GLB players=", players.size())
        for p in players:
            var ap: AnimationPlayer = p as AnimationPlayer
            var names: PackedStringArray = ap.get_animation_list()
            print("PROBE_GLB clips=", names.size(), " first=", str(names.slice(0, 6)))
            for n in names:
                if str(n).begins_with("m01_idle") or str(n).begins_with("m01_pnch") or names.find(n) < 2:
                    var anim: Animation = ap.get_animation(n)
                    var pos_tracks: int = 0
                    for t in anim.get_track_count():
                        if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
                            pos_tracks += 1
                    print("PROBE_GLB clip=", n, " tracks=", anim.get_track_count(), " pos3d=", pos_tracks)
        scene.free()
    quit(0)
