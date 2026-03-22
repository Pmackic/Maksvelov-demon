extends RefCounted
class_name ScoringSystem

# Scoring is derived from displayed coarse-grained entropy metrics and temperature contrast.
# This is separate from microscopic physics and separate from experimental bookkeeping cost.

var baseline_entropy := 0.0
var baseline_delta_t := 0.0
var score_a_longest_negative_interval := 0.0
var score_b_single_event_drop := 0.0
var score_c_total_reduction := 0.0
var score_d_delta_t_gain := 0.0

var _negative_interval_active := false
var _negative_interval_time := 0.0
var _positive_persistence := 0.0
var _persistence_window := 0.35
var _non_increasing_active := false
var _non_increasing_positive_persistence := 0.0
var non_increasing_time := 0.0

func reset(current_entropy: float, current_delta_t: float) -> void:
	baseline_entropy = current_entropy
	baseline_delta_t = current_delta_t
	score_a_longest_negative_interval = 0.0
	score_b_single_event_drop = 0.0
	score_c_total_reduction = 0.0
	score_d_delta_t_gain = 0.0
	_negative_interval_active = false
	_negative_interval_time = 0.0
	_positive_persistence = 0.0
	_non_increasing_active = false
	_non_increasing_positive_persistence = 0.0
	non_increasing_time = 0.0

func update_frame(dt: float, smoothed_ds_dt: float, entropy_total: float, delta_t_abs: float, crossing_count: int = 0, gate_was_open: bool = false) -> void:
	if smoothed_ds_dt <= 0.0:
		if not _non_increasing_active:
			_non_increasing_active = true
			non_increasing_time = 0.0
			_non_increasing_positive_persistence = 0.0
		non_increasing_time += dt
		_non_increasing_positive_persistence = 0.0
	elif _non_increasing_active:
		_non_increasing_positive_persistence += dt
		if _non_increasing_positive_persistence >= _persistence_window:
			_non_increasing_active = false
			_non_increasing_positive_persistence = 0.0
			non_increasing_time = 0.0
	if smoothed_ds_dt < 0.0:
		if not _negative_interval_active:
			_negative_interval_active = true
			_negative_interval_time = 0.0
			_positive_persistence = 0.0
		_negative_interval_time += dt
		score_a_longest_negative_interval = max(score_a_longest_negative_interval, _negative_interval_time)
	else:
		if _negative_interval_active:
			_positive_persistence += dt
			if _positive_persistence >= _persistence_window:
				_negative_interval_active = false
				_negative_interval_time = 0.0
				_positive_persistence = 0.0
	if gate_was_open and crossing_count > 0:
		score_c_total_reduction = max(score_c_total_reduction, baseline_entropy - entropy_total)
	score_d_delta_t_gain = max(score_d_delta_t_gain, delta_t_abs - baseline_delta_t)

func record_crossing_delta(entropy_before: float, entropy_after: float, crossing_count: int) -> void:
	if crossing_count <= 0:
		return
	var average_drop := (entropy_before - entropy_after) / float(crossing_count)
	score_b_single_event_drop = max(score_b_single_event_drop, average_drop)

func as_dictionary() -> Dictionary:
	return {
		"score_a_longest_negative_interval": score_a_longest_negative_interval,
		"score_b_single_event_drop": score_b_single_event_drop,
		"score_c_total_reduction": score_c_total_reduction,
		"score_d_delta_t_gain": score_d_delta_t_gain,
		"non_increasing_time": non_increasing_time
	}
