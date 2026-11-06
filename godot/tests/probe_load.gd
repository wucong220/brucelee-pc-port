extends SceneTree
func _initialize() -> void:
    var a = preload("res://scripts/titem_pool.gd").new()
    print("POOL_OK ", a.live_count())
    var b = preload("res://scripts/replay_sample_math.gd")
    print("MATH_OK ", b.frame_from_delta(1000, 0.5))
    var c = preload("res://scripts/replay_seek.gd").new()
    print("SEEK_OK ", c.get_method_list().size())
    var d = preload("res://tests/fixtures/deterministic_root_evaluator.gd").new()
    print("FIXTURE_OK ", d.root_position(2.0))
    var e = preload("res://scripts/root_track_evaluator.gd").new()
    print("ROOT_OK ", e.supports_fractional())
    quit(0)
