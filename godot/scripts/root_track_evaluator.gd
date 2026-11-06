extends RefCounted
class_name RootTrackEvaluator

## Port bridge for the ROOT TRANSFORM VALUE at a recovered sample index.
##
## Native ANM decoding is now recovered for raw tracks and for the proven
## `waveletsample` codec (see scripts/anm_track_codec.gd,
## scripts/wavelet_anm_codec.gd + scripts/native_root_output.gd). Bind a decoded
## ANM clip with bind_anm() and this evaluator returns the recovered native
## TTransform VALUE at BOTH integer and fractional (smooth-flag) samples.
## Without an ANM binding the legacy Godot AnimationPlayer bridge is kept for
## the existing port tests, and fractional samples still FAIL CLOSED.
##
## Evidence: docs/FIGHTING_SET_FINDINGS.md, report/REPORT.md of
## D:\BruceLeeWork\buildframe-fractional-20261104 (direct ARM disassembly of
## libdefault.so sha256 1da7a30...) and
## D:\BruceLeeWork\wavelet-codec-20261104 (CWaveletDecoder::UpdateToFrame
## @0x00418aa0 / @0x0041a914 executed under Unicorn on real ANM tracks).
## Unproven codecs and out-of-range samples fail closed.

const NativeRootOutputScript = preload("res://scripts/native_root_output.gd")
const WaveletAnmCodecScript = preload("res://scripts/wavelet_anm_codec.gd")
const _SUPPORTED_CODECS: Array[String] = [
    "rawfixedsample", "rawfloatsample", "waveletsample"]

var animation_player: AnimationPlayer = null
var clip_name: String = ""
var track_index: int = -1
var last_error: String = ""
var anm_fixture: Dictionary = {}


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


func _prepare_track(track: Variant) -> bool:
    if track == null or not (track is Dictionary):
        last_error = "track-required"
        return false
    var codec: String = String(track.get("codec", ""))
    if not _SUPPORTED_CODECS.has(codec):
        last_error = "unsupported-codec:" + codec
        return false
    if codec != "waveletsample":
        return true
    ## Decode once at bind time so an invalid stream fails closed before any
    ## value is evaluated, mirroring the native one-time resource decode.
    var decoded: Dictionary = WaveletAnmCodecScript.decode(track)
    if not bool(decoded.get("ok", false)):
        last_error = "unsupported-codec:waveletsample:" + String(
            decoded.get("reason", "unknown"))
        return false
    if int(decoded.get("nonzero_padding_streams", 0)) != 0:
        last_error = "unsupported-codec:waveletsample:nonzero-padding"
        return false
    track["keys"] = decoded["keys"]
    track["wavelet_frames"] = int(decoded["frames"])
    track["wavelet_nonzero_padding"] = int(decoded["nonzero_padding_streams"])
    return true


func bind_anm(fixture: Dictionary) -> bool:
    ## Bind proven decoded ANM root tracks. Only the proven raw and wavelet
    ## codecs are accepted; anything else fails closed.
    last_error = ""
    if fixture == null or fixture.is_empty():
        last_error = "anm-clip-required"
        return false
    var tracks: Dictionary = fixture.get("tracks", {})
    var positions: Variant = tracks.get("positions", null)
    if positions == null:
        last_error = "missing-positions"
        return false
    if not _prepare_track(positions):
        return false
    for key in ["rotations", "scales"]:
        var extra: Variant = tracks.get(key, null)
        if extra != null and not _prepare_track(extra):
            return false
    anm_fixture = fixture
    return true


func supports_fractional() -> bool:
    return not anm_fixture.is_empty()


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


func root_transform(sample: float) -> Dictionary:
    ## Recovered CRootPlayerBase::GetOutput TTransform VALUE at `sample`.
    if anm_fixture.is_empty():
        last_error = "anm-clip-not-bound"
        return {"ok": false, "reason": "anm-clip-not-bound"}
    var out: Dictionary = NativeRootOutputScript.compose(anm_fixture, sample)
    if not bool(out["ok"]):
        last_error = String(out["reason"])
    return out


func root_position(sample: float) -> Variant:
    if not anm_fixture.is_empty():
        var out: Dictionary = root_transform(sample)
        if not bool(out["ok"]):
            return null
        var p: Array = out["position"]
        return Vector3(float(p[0]), float(p[1]), float(p[2]))
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
