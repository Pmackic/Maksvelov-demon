extends RefCounted
class_name SimulationModel

const KB := 1.0
const MASS := 1.0
const BASE_WORLD_SIZE := Vector2(12.0, 10.0)
const AI_LOOKAHEAD_DT := 1.0 / 120.0
const DEFAULT_AI_LOOKAHEAD_STEPS := 5
const AI_DECISION_BETA := 18.0
const AI_OPEN_MARGIN := 0.003
const AI_HOLD_TIME := 0.02
const AI_CANDIDATE_WINDOW := 0.12
const EntropyEstimatorScript = preload("res://scripts/entropy_estimator.gd")
const ScoringSystemScript = preload("res://scripts/scoring_system.gd")

var params: Dictionary = {}
var world_rect := Rect2(Vector2.ZERO, Vector2(640, 640))
var gate_open := false
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var entropy_estimator = EntropyEstimatorScript.new()
var scoring = ScoringSystemScript.new()

var smoothed_ds_dt := 0.0
var displayed_entropy_total := 0.0
var displayed_entropy_left := 0.0
var displayed_entropy_right := 0.0
var bookkeeping_entropy := 0.0
var decision_count := 0
var run_time := 0.0

var _derivative_samples: Array[float] = []
var _derivative_window := 18
var _last_entropy_total := 0.0
var _last_metrics: Dictionary = {}
var _last_gate_state := false
var _last_ai_open_probability := 0.5
var _last_ai_closed_probability := 0.5
var _last_ai_decision_bits := 0.0
var _last_ai_decision_entropy_bits := 1.0
var _last_ai_open_disorder := 0.0
var _last_ai_closed_disorder := 0.0
var _ai_cached_gate_state := false
var _ai_hold_timer := 0.0

func configure(new_params: Dictionary, new_world_rect: Rect2, seed: int = 1) -> void:
	params = new_params.duplicate(true)
	world_rect = new_world_rect
	rng.seed = seed
	reset()

func reset() -> void:
	particles.clear()
	run_time = 0.0
	smoothed_ds_dt = 0.0
	bookkeeping_entropy = 0.0
	decision_count = 0
	_derivative_samples.clear()
	_last_gate_state = false
	_last_entropy_total = 0.0
	_last_ai_open_probability = 0.5
	_last_ai_closed_probability = 0.5
	_last_ai_decision_bits = 0.0
	_last_ai_decision_entropy_bits = 1.0
	_last_ai_open_disorder = 0.0
	_last_ai_closed_disorder = 0.0
	_ai_cached_gate_state = false
	_ai_hold_timer = 0.0
	_spawn_particles()
	_update_metrics(1.0 / 60.0, 0, 0.0)
	_derivative_samples.clear()
	smoothed_ds_dt = 0.0
	_last_entropy_total = displayed_entropy_total
	_last_metrics["smoothed_ds_dt"] = 0.0
	scoring.reset(displayed_entropy_total, abs(float(_last_metrics["delta_t"])))

func step(dt: float, gate_state: bool) -> Dictionary:
	if particles.is_empty():
		return {}
	run_time += dt
	gate_open = gate_state
	if gate_open != _last_gate_state:
		decision_count += 1
		if bool(params.get("include_bookkeeping", false)):
			if bool(params.get("perfect_demon_ai", false)):
				# AI bookkeeping is based on the actual lookahead inference confidence:
				# surprising decisions cost more bits than obvious ones.
				bookkeeping_entropy += _last_ai_decision_bits * log(2.0)
			elif gate_open:
				# Manual fallback bookkeeping path retained only for the non-AI mode.
				bookkeeping_entropy += log(2.0)
	_last_gate_state = gate_open

	var entropy_before := displayed_entropy_total
	var pre_sides := {}
	for particle in particles:
		pre_sides[int(particle["id"])] = int(particle["side"])

	var substeps: int = max(1, int(params.get("physics_substeps", 3)))
	var sub_dt: float = dt / float(substeps)
	var collision_events := 0
	for _substep in range(substeps):
		_integrate_free_motion(sub_dt)
		_resolve_wall_constraints(sub_dt)
		collision_events += _resolve_particle_collisions()

	var crossings := _detect_crossings(pre_sides)
	_update_metrics(dt, crossings.size(), entropy_before, collision_events)
	return _last_metrics

func get_metrics() -> Dictionary:
	return _last_metrics

func get_scaled_radius() -> float:
	return float(params.get("radius", 0.18)) * _geometry_scale()

func get_scaled_gate_height() -> float:
	return float(params.get("gate_height", 2.0)) * _geometry_scale()

func get_scaled_showcase_speed(raw_speed: float) -> float:
	# Showcase speed is scaled by horizontal world span so perceived on-screen
	# motion remains readable as the aspect-ratio-driven world width changes.
	var width_ratio: float = world_rect.size.x / BASE_WORLD_SIZE.x
	return raw_speed * max(0.75, width_ratio)

func get_ai_lookahead_steps() -> int:
	return int(params.get("ai_lookahead_steps", DEFAULT_AI_LOOKAHEAD_STEPS))

func get_ai_lookahead_time() -> float:
	return AI_LOOKAHEAD_DT * float(get_ai_lookahead_steps())

func should_ai_open_gate(dt: float = AI_LOOKAHEAD_DT) -> bool:
	if particles.is_empty():
		_last_ai_open_probability = 0.5
		_last_ai_closed_probability = 0.5
		_last_ai_decision_bits = 0.0
		_last_ai_decision_entropy_bits = 0.0
		_ai_cached_gate_state = false
		_ai_hold_timer = 0.0
		return false
	if not _has_ai_gate_candidate():
		_last_ai_open_probability = 0.0
		_last_ai_closed_probability = 1.0
		_last_ai_decision_bits = 0.0
		_last_ai_decision_entropy_bits = 0.0
		_last_ai_open_disorder = 1.0 - float(_last_metrics.get("sorting_score", 0.0))
		_last_ai_closed_disorder = _last_ai_open_disorder
		_ai_cached_gate_state = false
		_ai_hold_timer = 0.0
		return false
	if _ai_hold_timer > 0.0:
		_ai_hold_timer = max(0.0, _ai_hold_timer - dt)
		return _ai_cached_gate_state
	var open_disorder: float = _estimate_ai_disorder(true)
	var closed_disorder: float = _estimate_ai_disorder(false)
	_last_ai_open_disorder = open_disorder
	_last_ai_closed_disorder = closed_disorder
	var open_weight: float = exp(-AI_DECISION_BETA * open_disorder)
	var closed_weight: float = exp(-AI_DECISION_BETA * closed_disorder)
	var total_weight: float = max(1e-9, open_weight + closed_weight)
	_last_ai_open_probability = open_weight / total_weight
	_last_ai_closed_probability = closed_weight / total_weight
	var choose_open: bool = open_disorder < closed_disorder - AI_OPEN_MARGIN
	if not choose_open and _ai_cached_gate_state and open_disorder < closed_disorder + AI_OPEN_MARGIN * 0.5:
		choose_open = true
	var chosen_probability: float = _last_ai_open_probability if choose_open else _last_ai_closed_probability
	_last_ai_decision_bits = -log(max(1e-9, chosen_probability)) / log(2.0)
	_last_ai_decision_entropy_bits = _binary_entropy_bits(_last_ai_open_probability)
	if choose_open != _ai_cached_gate_state:
		_ai_cached_gate_state = choose_open
		_ai_hold_timer = AI_HOLD_TIME
	return choose_open

func _has_ai_gate_candidate() -> bool:
	var separator_x := world_rect.position.x + world_rect.size.x * 0.5
	var gate_height: float = get_scaled_gate_height()
	var gate_y0 := world_rect.position.y + (world_rect.size.y - gate_height) * 0.5
	var gate_y1 := gate_y0 + gate_height
	var horizon_time: float = min(get_ai_lookahead_time(), AI_CANDIDATE_WINDOW)
	for particle in particles:
		var pos: Vector2 = particle["pos"]
		var vel: Vector2 = particle["vel"]
		var radius: float = float(particle["radius"])
		if vel.x == 0.0:
			continue
		var heading_to_gate := (pos.x < separator_x and vel.x > 0.0) or (pos.x > separator_x and vel.x < 0.0)
		if not heading_to_gate:
			continue
		var time_to_separator: float = abs(separator_x - pos.x) / max(0.0001, abs(vel.x))
		if time_to_separator > horizon_time:
			continue
		var predicted_y: float = pos.y + vel.y * time_to_separator
		if predicted_y >= gate_y0 - radius and predicted_y <= gate_y1 + radius:
			return true
	return false

func _estimate_ai_disorder(gate_state: bool) -> float:
	# "Perfect demon" approximation for the demo:
	# evaluate both actions from the full current gas microstate over a short,
	# deterministic lookahead and choose the branch with lower future displayed
	# gas disorder. This is still finite-horizon control, not a mathematically
	# global optimum over all future times.
	var saved_particles: Array[Dictionary] = particles
	var saved_gate_open: bool = gate_open
	var branch_particles: Array[Dictionary] = _clone_particles(saved_particles)
	particles = branch_particles
	gate_open = gate_state
	var lookahead_steps: int = get_ai_lookahead_steps()
	var lookahead_dt: float = AI_LOOKAHEAD_DT
	for _step in range(lookahead_steps):
		_integrate_free_motion(lookahead_dt)
		_resolve_wall_constraints(lookahead_dt)
		_resolve_particle_collisions()
	var entropy_data: Dictionary = entropy_estimator.compute(particles, params, world_rect)
	var disorder: float = 1.0 - float(entropy_data.get("sorting_score", 0.0))
	particles = saved_particles
	gate_open = saved_gate_open
	return disorder

func _clone_particles(source_particles: Array[Dictionary]) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for particle in source_particles:
		copy.append({
			"id": int(particle["id"]),
			"pos": Vector2(particle["pos"]),
			"vel": Vector2(particle["vel"]),
			"side": int(particle["side"]),
			"radius": float(particle["radius"])
		})
	return copy

func _binary_entropy_bits(p: float) -> float:
	var clamped_p: float = clamp(p, 1e-9, 1.0 - 1e-9)
	return -(clamped_p * log(clamped_p) + (1.0 - clamped_p) * log(1.0 - clamped_p)) / log(2.0)

func _geometry_scale() -> float:
	# Geometry scale is a presentation/physics coupling choice:
	# when the effective world rectangle changes with screen aspect, scale circular
	# particle radius and gate aperture together by the isotropic area-equivalent
	# factor so contact geometry remains consistent across aspect ratios.
	var width_ratio: float = world_rect.size.x / BASE_WORLD_SIZE.x
	var height_ratio: float = world_rect.size.y / BASE_WORLD_SIZE.y
	return sqrt(max(0.0001, width_ratio * height_ratio))

func _spawn_particles() -> void:
	var total_n := int(params["atom_count"])
	var left_n := total_n / 2
	var right_n := total_n - left_n
	var radius: float = get_scaled_radius()
	var separator_x := world_rect.position.x + world_rect.size.x * 0.5
	var left_rect := Rect2(world_rect.position + Vector2(radius, radius), Vector2(world_rect.size.x * 0.5 - 2.0 * radius, world_rect.size.y - 2.0 * radius))
	var right_rect := Rect2(Vector2(separator_x + radius, world_rect.position.y + radius), Vector2(world_rect.size.x * 0.5 - 2.0 * radius, world_rect.size.y - 2.0 * radius))
	for i in range(left_n):
		particles.append(_make_particle(i, 0, left_rect, float(params["t_left"]), radius))
	for i in range(right_n):
		particles.append(_make_particle(left_n + i, 1, right_rect, float(params["t_right"]), radius))
	if bool(params.get("presentation_gate_seed", false)):
		_apply_presentation_gate_seed()

func _make_particle(id_value: int, side: int, rect: Rect2, temperature: float, radius: float) -> Dictionary:
	var pos := Vector2.ZERO
	for _attempt in range(300):
		pos = Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		var overlapping := false
		for other in particles:
			if pos.distance_to(other["pos"]) < 2.1 * radius:
				overlapping = true
				break
		if not overlapping:
			break
	var vel := _sample_initial_velocity(side, temperature)
	return {
		"id": id_value,
		"pos": pos,
		"vel": vel,
		"side": side,
		"radius": radius
	}

func _sample_initial_velocity(side: int, temperature: float) -> Vector2:
	if bool(params.get("bimodal_demo_init", false)):
		return _sample_bimodal_demo_velocity(side, temperature)
	var sigma := sqrt(max(0.0001, KB * temperature / MASS))
	return Vector2(_randn() * sigma, _randn() * sigma)

func _sample_bimodal_demo_velocity(side: int, temperature: float) -> Vector2:
	# Experimental non-Maxwellian initialization for presentation only.
	# It creates a bimodal speed distribution from explicit slow/fast speed peaks.
	# This is intentionally not a literal temperature initialization and should not
	# be confused with the default Gaussian component sampling rule.
	var fast_fraction: float = float(params["left_fast_fraction"] if side == 0 else params["right_fast_fraction"])
	var slow_speed: float = get_scaled_showcase_speed(float(params.get("slow_speed", 0.35)))
	var fast_speed: float = get_scaled_showcase_speed(float(params.get("fast_speed", 2.6)))
	var target_speed: float = fast_speed if rng.randf() < fast_fraction else slow_speed
	var spread: float = max(0.04, target_speed * 0.12)
	var speed: float = max(0.0, target_speed + _randn() * spread)
	var angle: float = rng.randf_range(0.0, TAU)
	return Vector2(cos(angle), sin(angle)) * speed

func _apply_presentation_gate_seed() -> void:
	# Presentation-only initialization aid:
	# place a few particles near the gate so the player can quickly create a small
	# coarse-grained entropy reduction by opening the gate a few times.
	# This changes only the initial microscopic seed of the default sandbox.
	var separator_x := world_rect.position.x + world_rect.size.x * 0.5
	var gate_center_y := world_rect.position.y + world_rect.size.y * 0.5
	var left_candidates: Array[Dictionary] = []
	var right_candidates: Array[Dictionary] = []
	for particle in particles:
		if int(particle["side"]) == 0:
			left_candidates.append(particle)
		else:
			right_candidates.append(particle)
	if left_candidates.size() < 2 or right_candidates.size() < 2:
		return
	left_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["vel"] as Vector2).length() > (b["vel"] as Vector2).length()
	)
	right_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["vel"] as Vector2).length() < (b["vel"] as Vector2).length()
	)
	var y_offsets := [-0.55, 0.55]
	for i in range(2):
		var fast_left: Dictionary = left_candidates[i]
		var fast_left_speed: float = max(0.6, (fast_left["vel"] as Vector2).length())
		fast_left["pos"] = Vector2(separator_x - (0.95 + float(i) * 0.35), gate_center_y + y_offsets[i])
		fast_left["vel"] = Vector2(fast_left_speed, 0.0)
		fast_left["side"] = 0
	for i in range(2):
		var slow_right: Dictionary = right_candidates[i]
		var slow_right_speed: float = min(0.5, max(0.12, (slow_right["vel"] as Vector2).length()))
		slow_right["pos"] = Vector2(separator_x + (0.95 + float(i) * 0.35), gate_center_y - y_offsets[i])
		slow_right["vel"] = Vector2(-slow_right_speed, 0.0)
		slow_right["side"] = 1

func _integrate_free_motion(dt: float) -> void:
	for particle in particles:
		particle["pos"] = (particle["pos"] as Vector2) + (particle["vel"] as Vector2) * dt

func _resolve_wall_constraints(_dt: float) -> void:
	var min_x := world_rect.position.x
	var max_x := world_rect.end.x
	var min_y := world_rect.position.y
	var max_y := world_rect.end.y
	var separator_x := world_rect.position.x + world_rect.size.x * 0.5
	var gate_height: float = get_scaled_gate_height()
	var gate_y0 := world_rect.position.y + (world_rect.size.y - gate_height) * 0.5
	var gate_y1 := gate_y0 + gate_height
	var coupling := float(params.get("wall_coupling", 0.0))
	for particle in particles:
		var pos: Vector2 = particle["pos"]
		var vel: Vector2 = particle["vel"]
		var radius := float(particle["radius"])
		if pos.x - radius < min_x:
			pos.x = min_x + radius
			vel.x = abs(vel.x)
			_apply_wall_coupling(particle, Vector2.RIGHT, coupling)
		elif pos.x + radius > max_x:
			pos.x = max_x - radius
			vel.x = -abs(vel.x)
			_apply_wall_coupling(particle, Vector2.LEFT, coupling)
		if pos.y - radius < min_y:
			pos.y = min_y + radius
			vel.y = abs(vel.y)
			_apply_wall_coupling(particle, Vector2.DOWN, coupling)
		elif pos.y + radius > max_y:
			pos.y = max_y - radius
			vel.y = -abs(vel.y)
			_apply_wall_coupling(particle, Vector2.UP, coupling)

		var in_gate_band := pos.y >= gate_y0 and pos.y <= gate_y1
		if abs(pos.x - separator_x) < radius:
			if not (gate_open and in_gate_band):
				if pos.x < separator_x:
					pos.x = separator_x - radius
					vel.x = -abs(vel.x)
				else:
					pos.x = separator_x + radius
					vel.x = abs(vel.x)
			else:
				if pos.x < separator_x:
					particle["side"] = 0 if pos.x < separator_x else 1
				else:
					particle["side"] = 1 if pos.x > separator_x else 0
		particle["pos"] = pos
		particle["vel"] = vel
		particle["side"] = 0 if pos.x < separator_x else 1

func _apply_wall_coupling(particle: Dictionary, normal: Vector2, coupling: float) -> void:
	if coupling <= 0.0:
		return
	# Non-isolated wall heat sink approximation:
	# after the elastic bounce, remove a fraction of kinetic energy by shrinking the
	# outgoing velocity magnitude. This is deterministic damping, not randomization.
	var damping: float = clamp(coupling, 0.0, 0.45)
	particle["vel"] = (particle["vel"] as Vector2) * (1.0 - damping)

func _resolve_particle_collisions() -> int:
	var n := particles.size()
	var collision_events := 0
	for i in range(n):
		for j in range(i + 1, n):
			var a := particles[i]
			var b := particles[j]
			var pos_a: Vector2 = a["pos"]
			var pos_b: Vector2 = b["pos"]
			var delta := pos_b - pos_a
			var min_dist := float(a["radius"]) + float(b["radius"])
			var dist_sq := delta.length_squared()
			if dist_sq <= 0.000001 or dist_sq >= min_dist * min_dist:
				continue
			var dist := sqrt(dist_sq)
			var normal := delta / dist
			var rel := (a["vel"] as Vector2) - (b["vel"] as Vector2)
			var rel_n := rel.dot(normal)
			if rel_n >= 0.0:
				var overlap_only := (min_dist - dist) * 0.5
				a["pos"] = pos_a - normal * overlap_only
				b["pos"] = pos_b + normal * overlap_only
				continue
			collision_events += 1
			var impulse := rel_n
			a["vel"] = (a["vel"] as Vector2) - normal * impulse
			b["vel"] = (b["vel"] as Vector2) + normal * impulse
			var overlap := (min_dist - dist) * 0.5
			a["pos"] = pos_a - normal * overlap
			b["pos"] = pos_b + normal * overlap
	return collision_events

func _detect_crossings(pre_sides: Dictionary) -> Array[int]:
	var crossings: Array[int] = []
	for particle in particles:
		var id_value := int(particle["id"])
		if int(pre_sides[id_value]) != int(particle["side"]):
			crossings.append(id_value)
	return crossings

func _update_metrics(dt: float, crossing_count: int, entropy_before: float, collision_events: int = 0) -> void:
	var left_count := 0
	var right_count := 0
	var left_ke := 0.0
	var right_ke := 0.0
	var left_speed := 0.0
	var right_speed := 0.0
	var speeds: Array[float] = []

	for particle in particles:
		var vel: Vector2 = particle["vel"]
		var ke := 0.5 * MASS * vel.length_squared()
		var speed := vel.length()
		speeds.append(speed)
		if int(particle["side"]) == 0:
			left_count += 1
			left_ke += ke
			left_speed += speed
		else:
			right_count += 1
			right_ke += ke
			right_speed += speed

	var entropy_data = entropy_estimator.compute(particles, params, world_rect)
	displayed_entropy_total = float(entropy_data["total_entropy"])
	displayed_entropy_left = float(entropy_data["left_entropy"])
	displayed_entropy_right = float(entropy_data["right_entropy"])

	var ds_dt = (displayed_entropy_total - _last_entropy_total) / max(dt, 0.000001)
	_last_entropy_total = displayed_entropy_total
	_derivative_samples.append(ds_dt)
	if _derivative_samples.size() > _derivative_window:
		_derivative_samples.pop_front()
	smoothed_ds_dt = 0.0
	for sample in _derivative_samples:
		smoothed_ds_dt += sample
	smoothed_ds_dt /= max(1, _derivative_samples.size())

	var global_mean_speed := 0.0
	for speed in speeds:
		global_mean_speed += speed
	global_mean_speed /= max(1, speeds.size())
	var speed_std := 0.0
	for speed in speeds:
		speed_std += pow(speed - global_mean_speed, 2.0)
	speed_std = sqrt(speed_std / max(1, speeds.size()))

	var left_temp = left_ke / max(1, left_count)
	var right_temp = right_ke / max(1, right_count)
	var delta_t = left_temp - right_temp

	_last_metrics = {
		"left_count": left_count,
		"right_count": right_count,
		"left_temperature": left_temp,
		"right_temperature": right_temp,
		"delta_t": delta_t,
		"left_mean_speed": left_speed / max(1, left_count),
		"right_mean_speed": right_speed / max(1, right_count),
		"left_mean_ke": left_ke / max(1, left_count),
		"right_mean_ke": right_ke / max(1, right_count),
		"total_entropy": displayed_entropy_total,
		"left_entropy": displayed_entropy_left,
		"right_entropy": displayed_entropy_right,
		"side_speed_entropy": float(entropy_data["side_speed_entropy"]),
		"sorting_score": float(entropy_data["sorting_score"]),
		"side_speed_boltzmann_entropy": float(entropy_data["side_speed_boltzmann_entropy"]),
		"smoothed_ds_dt": smoothed_ds_dt,
		"max_entropy_scale": float(entropy_data["max_entropy_scale"]),
		"side_speed_max_scale": float(entropy_data["side_speed_max_scale"]),
		"side_speed_boltzmann_max_scale": float(entropy_data["side_speed_boltzmann_max_scale"]),
		"global_mean_speed": global_mean_speed,
		"global_speed_std": speed_std,
		"bookkeeping_entropy": bookkeeping_entropy,
		"collision_events": collision_events,
		"ai_open_probability": _last_ai_open_probability,
		"ai_closed_probability": _last_ai_closed_probability,
		"ai_decision_bits": _last_ai_decision_bits,
		"ai_decision_entropy_bits": _last_ai_decision_entropy_bits,
		"ai_open_disorder": _last_ai_open_disorder,
		"ai_closed_disorder": _last_ai_closed_disorder
	}
	_last_metrics["crossing_count"] = crossing_count
	scoring.record_crossing_delta(entropy_before, displayed_entropy_total, crossing_count)
	scoring.update_frame(dt, smoothed_ds_dt, displayed_entropy_total, abs(delta_t), crossing_count, gate_open)

func _randn() -> float:
	var u1: float = max(1e-9, rng.randf())
	var u2: float = rng.randf()
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)
