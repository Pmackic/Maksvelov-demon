extends RefCounted
class_name PersistenceStore

const SAVE_PATH := "user://highscores.cfg"

var _config := ConfigFile.new()

func _init() -> void:
	var err := _config.load(SAVE_PATH)
	if err != OK and err != ERR_DOES_NOT_EXIST:
		push_warning("Could not load highscores.cfg: %s" % err)

func canonical_hash(params: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_canonical_string(params).to_utf8_buffer())
	return context.finish().hex_encode()

func _canonical_string(value) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort()
			var parts: Array[String] = []
			for key in keys:
				parts.append("%s:%s" % [str(key), _canonical_string(value[key])])
			return "{%s}" % ",".join(parts)
		TYPE_ARRAY:
			var parts: Array[String] = []
			for item in value:
				parts.append(_canonical_string(item))
			return "[%s]" % ",".join(parts)
		_:
			return str(value)

func get_scores(hash_key: String) -> Dictionary:
	return _config.get_value("scores", hash_key, {
		"score_a_longest_negative_interval": 0.0,
		"score_b_single_event_drop": 0.0,
		"score_c_total_reduction": 0.0,
		"score_d_delta_t_gain": 0.0
	})

func update_scores(hash_key: String, new_scores: Dictionary) -> Dictionary:
	var current := get_scores(hash_key)
	var changed := false
	for key in new_scores.keys():
		var updated = max(float(current.get(key, 0.0)), float(new_scores[key]))
		if updated > float(current.get(key, 0.0)):
			changed = true
		current[key] = updated
	if changed:
		_config.set_value("scores", hash_key, current)
		_config.save(SAVE_PATH)
	return current
