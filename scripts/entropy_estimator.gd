extends RefCounted
class_name EntropyEstimator

# Coarse-grained one-particle entropy estimator.
# This is deliberately not the fine-grained Gibbs entropy of the exact Hamiltonian system.
# We bin observable one-particle data by chamber, position cell, and speed bin, then compute
# S_cg = -sum_i p_i ln(p_i) with k_B = 1. See PHYSICS_NOTES.md for rationale.

func compute(particles: Array, params: Dictionary, world_rect: Rect2) -> Dictionary:
	var total_bins: Dictionary = {}
	var left_bins: Dictionary = {}
	var right_bins: Dictionary = {}
	var side_speed_bins: Dictionary = {}
	var chamber_width: float = world_rect.size.x * 0.5
	var speed_max: float = _speed_reference(particles)
	var assignments: Array[Dictionary] = []

	for particle in particles:
		var side: int = particle["side"]
		var pos: Vector2 = particle["pos"]
		var vel: Vector2 = particle["vel"]
		var chamber_origin_x: float = world_rect.position.x if side == 0 else world_rect.position.x + chamber_width
		var local_x: float = clamp((pos.x - chamber_origin_x) / chamber_width, 0.0, 0.999999)
		var local_y: float = clamp((pos.y - world_rect.position.y) / world_rect.size.y, 0.0, 0.999999)
		var x_bin := mini(int(local_x * int(params["bin_x"])), int(params["bin_x"]) - 1)
		var y_bin := mini(int(local_y * int(params["bin_y"])), int(params["bin_y"]) - 1)
		var speed: float = vel.length()
		var s_bin := mini(int((speed / speed_max) * int(params["speed_bins"])), int(params["speed_bins"]) - 1)
		var key := "%d|%d|%d|%d" % [side, x_bin, y_bin, s_bin]
		var side_speed_key := "%d|%d" % [side, s_bin]
		assignments.append({"id": particle["id"], "key": key, "side": side})
		total_bins[key] = int(total_bins.get(key, 0)) + 1
		side_speed_bins[side_speed_key] = int(side_speed_bins.get(side_speed_key, 0)) + 1
		if side == 0:
			left_bins[key] = int(left_bins.get(key, 0)) + 1
		else:
			right_bins[key] = int(right_bins.get(key, 0)) + 1

	return {
		"total_entropy": _shannon_from_counts(total_bins, particles.size()),
		"left_entropy": _shannon_from_counts(left_bins, _count_side(assignments, 0)),
		"right_entropy": _shannon_from_counts(right_bins, _count_side(assignments, 1)),
		"side_speed_entropy": _shannon_from_counts(side_speed_bins, particles.size()),
		"sorting_score": _sorting_score_from_bins(side_speed_bins, particles.size()),
		"side_speed_boltzmann_entropy": _boltzmann_from_counts(side_speed_bins, particles.size()),
		"min_entropy_scale": 0.0,
		"max_entropy_scale": _max_entropy_scale(particles.size(), params),
		"side_speed_max_scale": _side_speed_max_scale(particles.size(), params),
		"side_speed_boltzmann_max_scale": _side_speed_boltzmann_max_scale(particles.size(), params),
		"assignments": assignments
	}

func _speed_reference(particles: Array) -> float:
	var max_speed: float = 0.0
	for particle in particles:
		max_speed = max(max_speed, (particle["vel"] as Vector2).length())
	return max(0.0001, max_speed * 1.001)

func _count_side(assignments: Array[Dictionary], side: int) -> int:
	var count := 0
	for entry in assignments:
		if int(entry["side"]) == side:
			count += 1
	return count

func _shannon_from_counts(counts: Dictionary, total_count: int) -> float:
	if total_count <= 0:
		return 0.0
	var entropy: float = 0.0
	for key in counts.keys():
		var p: float = float(counts[key]) / float(total_count)
		if p > 0.0:
			entropy -= p * log(p)
	return entropy

func _boltzmann_from_counts(counts: Dictionary, total_count: int) -> float:
	if total_count <= 0:
		return 0.0
	var entropy: float = _log_factorial(total_count)
	for count in counts.values():
		entropy -= _log_factorial(int(count))
	return entropy

func _max_entropy_scale(total_count: int, params: Dictionary) -> float:
	# For the displayed coarse-grained one-particle entropy, the lowest possible
	# value is 0 when all particles occupy one coarse bin. The largest possible
	# value for a run with N particles and M coarse bins is ln(min(N, M)),
	# because the normalized occupancy distribution cannot have more than N
	# non-empty bins and cannot exceed the number of available bins.
	var total_bins: int = 2 * int(params["bin_x"]) * int(params["bin_y"]) * int(params["speed_bins"])
	var accessible_states: int = maxi(1, mini(total_count, total_bins))
	return log(max(1.0, float(accessible_states)))

func _side_speed_max_scale(total_count: int, params: Dictionary) -> float:
	var total_bins: int = 2 * int(params["speed_bins"])
	var accessible_states: int = maxi(1, mini(total_count, total_bins))
	return log(max(1.0, float(accessible_states)))

func _side_speed_boltzmann_max_scale(total_count: int, params: Dictionary) -> float:
	if total_count <= 0:
		return 0.0
	var total_bins: int = maxi(1, 2 * int(params["speed_bins"]))
	var occupied_bins: int = mini(total_count, total_bins)
	var base_fill: int = total_count / occupied_bins
	var remainder: int = total_count % occupied_bins
	var entropy: float = _log_factorial(total_count)
	for bin_index in range(occupied_bins):
		var count: int = base_fill + (1 if bin_index < remainder else 0)
		entropy -= _log_factorial(count)
	return entropy

func _sorting_score_from_bins(side_speed_bins: Dictionary, total_count: int) -> float:
	if total_count <= 0:
		return 0.0
	var side_counts := {0: 0, 1: 0}
	var speed_bin_counts: Dictionary = {}
	for key in side_speed_bins.keys():
		var parts := String(key).split("|")
		var side: int = int(parts[0])
		var speed_bin: int = int(parts[1])
		var count: int = int(side_speed_bins[key])
		side_counts[side] = int(side_counts[side]) + count
		speed_bin_counts[speed_bin] = int(speed_bin_counts.get(speed_bin, 0)) + count

	var h_side: float = _shannon_from_counts(side_counts, total_count)
	if h_side <= 0.000001:
		return 0.0

	var h_side_given_speed := 0.0
	for speed_bin in speed_bin_counts.keys():
		var speed_total: int = int(speed_bin_counts[speed_bin])
		if speed_total <= 0:
			continue
		var conditional_counts := {
			0: int(side_speed_bins.get("0|%d" % int(speed_bin), 0)),
			1: int(side_speed_bins.get("1|%d" % int(speed_bin), 0))
		}
		h_side_given_speed += (float(speed_total) / float(total_count)) * _shannon_from_counts(conditional_counts, speed_total)
	return clamp((h_side - h_side_given_speed) / h_side, 0.0, 1.0)

func _log_factorial(n: int) -> float:
	if n <= 1:
		return 0.0
	var total: float = 0.0
	for i in range(2, n + 1):
		total += log(float(i))
	return total
