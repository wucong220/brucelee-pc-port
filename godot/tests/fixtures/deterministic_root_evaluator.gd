extends RefCounted
class_name DeterministicRootEvaluator

## Test double for the root transform VALUE at a sample index.
## The native ANM decode / BuildFrame is unrecovered; this fixture supplies
## deterministic values so the recovered COMPOSITION can be asserted.
## It is not native math and is never claimed as such.

var clip_name: String = ""


func set_clip(name: String) -> bool:
    clip_name = name
    return not name.is_empty()


func supports_fractional() -> bool:
    return false


func root_position(sample: float) -> Variant:
    if sample != floor(sample):
        return null
    return Vector3(2.0 * sample, 3.0 * sample, -sample)
