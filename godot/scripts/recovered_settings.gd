extends RefCounted
class_name PortRecoveredSettings
## Recovered `gui::CSettings` values used by the in-game (training) Settings
## screens.
##
## Everything here comes from `tools/build_training_settings.py`:
##   * the defaults are the exact float constants `CApplication::Init` writes
##     in libdefault.so (music_volume 0.5, sound_volume 0.5, input_layout 0.0,
##     camera_tilt 1.0, input_gui_alpha 0.25);
##   * `CApplication::Update` maps `music_volume` -> CFXManager::SetMusicVolume
##     and `sound_volume` -> CFXManager::SetSoundVolume, so the port binds the
##     same two values to Music/Sound AudioServer buses;
##   * the +/- 0.1 step and the [0, 1] clamp are `MusicVolumeIncrease/Decrease`
##     and `SettingsValue0to1Modify` in libdefault.so.
##
## This store is only display/mixer state; it never feeds combat logic.

const BUS_MUSIC := "Music"
const BUS_SOUND := "Sound"

static var _defaults: Dictionary = {}
static var _values: Dictionary = {}
static var _configured := false


static func configure(defaults: Dictionary) -> void:
	_defaults = defaults.duplicate()
	_values = defaults.duplicate()
	_configured = true


static func is_configured() -> bool:
	return _configured


static func reset() -> void:
	_values = _defaults.duplicate()
	apply_audio()


static func defaults() -> Dictionary:
	return _defaults.duplicate()


static func get_value(key: String, fallback: float = 0.0) -> float:
	return float(_values.get(key, fallback))


static func set_value(key: String, value: float) -> void:
	_values[key] = clampf(value, 0.0, 1.0)


static func adjust(key: String, delta: float) -> float:
	var value: float = clampf(get_value(key) + delta, 0.0, 1.0)
	_values[key] = value
	return value


static func ensure_audio_buses() -> void:
	for bus_name: String in [BUS_MUSIC, BUS_SOUND]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index: int = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


static func apply_audio() -> void:
	ensure_audio_buses()
	_set_bus_volume(BUS_MUSIC, get_value("music_volume", 0.5))
	_set_bus_volume(BUS_SOUND, get_value("sound_volume", 0.5))


static func _set_bus_volume(bus_name: String, value: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))


static func assign_player(player: Node, channel: String) -> void:
	var stream_player: AudioStreamPlayer = player as AudioStreamPlayer
	if stream_player == null:
		return
	ensure_audio_buses()
	stream_player.bus = channel
