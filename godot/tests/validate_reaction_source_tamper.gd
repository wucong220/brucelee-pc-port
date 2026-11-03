extends SceneTree
func _initialize() -> void:
    for path: String in [PortFighter.MASTER_ATTACK_CONFIG_PATH, PortFighter.SINFU_ATTACK_CONFIG_PATH, PortFighter.KEN_ATTACK_CONFIG_PATH]:
        var fighter := PortFighter.new()
        fighter.configure_attack_config(path)
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        config["reaction_profiles"]["hit"]["medium"]["exit_start_frame"] -= 1
        if not fighter._parse_attack_config(config).is_empty() or not fighter.attack_config_error.contains("source links"):
            push_error("tampered source link accepted: " + path)
            fighter.free()
            quit(1)
            return
        fighter.free()
    print("REACTION_SOURCE_TAMPER=rejected for master,sinfu,ken")
    quit(0)
