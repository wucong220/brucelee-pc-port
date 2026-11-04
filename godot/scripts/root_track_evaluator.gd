extends RefCounted
class_name RootTrackEvaluator

## Port bridge for the ROOT TRANSFORM VALUE at a recovered sample index.
##
## IMPORTANT: this is NOT native ANM decoding. The native
## CRootPlayerBase::GetOutput / CAnimProvider::BuildFrame path that turns a
## sample index into a TTransform was NOT recovered (documented as unrecovered
## in docs/FIGHTING_SET_FINDINGS.md). This evaluator reads a real Godot
## AnimationPlayer position track at the integer sample index produced by the
## recovered ReplaySampleMath arithmetic, so the headless / matrix tests can
## exercise the real Godot animation path without inventing native math.
##
## Fractional samples (native smooth-flag branch) fail closed here: the native
## BuildFrame interpolation is unrecovered, so `supports_fractional()` is false.

var animation_player: AnimationPlayer = null
var clip_name: String = ""
var track_index: int = -1
var last_error: String = ""


func _init(player: AnimationPlayer = null) -> void:
    animation_player = player


func set_clip(name: String) -> bool:
    last_error = ""
    if animation_player == null:
        last_error = "no-animation-player"
        return false
    if not animation_player.has_animation(name):
        last_error = "clip-not-found: %s" % name
        return false
    clip_name = name
    var anim: Animation = animation_player.get_animation(name)
    track_index = -1
    for t in anim.get_track_count():
        if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
            track_index = t
            break
    if track_index < 0:
        last_error = "no-position-track: %s" % name
        return false
    return true


func supports_fractional() -> bool:
    return false


func fields_for_clip(_name: String) -> Dictionary:
    # Deliberately fail closed: CAnimRes+0x3C / +0x40 (duration samples and
    # duration*1000/framerate) are native resource fields, not Godot clip
    # fields. Callers must supply proven values explicitly.
    return {"ok": false, "reason": "clip-fields-required"}


func key_count() -> int:
    if animation_player == null or clip_name.is_empty() or track_index < 0:
        return 0
    var anim: Animation = animation_player.get_animation(clip_name)
    return anim.track_get_key_count(track_index)


func root_position(sample: float) -> Variant:
    last_error = ""
    if animation_player == null or track_index < 0:
        last_error = "clip-not-bound"
        return null
    if sample != floor(sample):
        last_error = "fractional-sample-unrecovered"
        return null
    var anim: Animation = animation_player.get_animation(clip_name)
    var count: int = anim.track_get_key_count(track_index)
    if count == 0:
        last_error = "empty-position-track"
        return null
    var index: int = clampi(int(sample), 0, count - 1)
    return anim.track_get_key_value(track_index, index)
