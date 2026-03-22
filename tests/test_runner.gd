extends SceneTree

const SimulationModelScript = preload("res://scripts/simulation_model.gd")
const PersistenceStoreScript = preload("res://scripts/persistence.gd")
const PresetLibraryScript = preload("res://scripts/preset_library.gd")

var failures: Array[String] = []

func _init() -> void:
	_run_all()
	if failures.is_empty():
		print("All tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _run_all() -> void:
	_test_energy_conservation()
	_test_pair_collision_conservation()
	_test_dense_mode_has_collisions()
	_test_temperature_ordering()
	_test_entropy_stability()
	_test_persistence_hash()
	_test_mobile_layout()

func _test_energy_conservation() -> void:
	var model = SimulationModelScript.new()
	var params := PresetLibraryScript.sandbox_defaults()
	params["atom_count"] = 20
	params["wall_coupling"] = 0.0
	model.configure(params, Rect2(Vector2.ZERO, Vector2(640, 640)), 12345)
	var before := _total_ke(model.particles)
	for _i in range(300):
		model.step(1.0 / 120.0, false)
	var after := _total_ke(model.particles)
	_assert(abs(before - after) < 0.08, "Elastic mode drifted too far in total kinetic energy: %f vs %f" % [before, after])

func _test_pair_collision_conservation() -> void:
	var model = SimulationModelScript.new()
	model.params = PresetLibraryScript.sandbox_defaults()
	model.particles.clear()
	model.particles.append({"id": 0, "pos": Vector2(100, 100), "vel": Vector2(1.0, 0.0), "side": 0, "radius": 10.0})
	model.particles.append({"id": 1, "pos": Vector2(118, 100), "vel": Vector2(-1.0, 0.0), "side": 0, "radius": 10.0})
	var p_before := _total_momentum(model.particles)
	var e_before := _total_ke(model.particles)
	model._resolve_particle_collisions()
	var p_after := _total_momentum(model.particles)
	var e_after := _total_ke(model.particles)
	_assert(p_before.distance_to(p_after) < 0.0001, "Pair collision momentum changed too much.")
	_assert(abs(e_before - e_after) < 0.0001, "Pair collision kinetic energy changed too much.")

func _test_temperature_ordering() -> void:
	var model = SimulationModelScript.new()
	var params := PresetLibraryScript.sandbox_defaults()
	params["bimodal_demo_init"] = false
	params["presentation_gate_seed"] = false
	params["atom_count"] = 40
	params["t_left"] = 1.8
	params["t_right"] = 0.4
	model.configure(params, Rect2(Vector2.ZERO, Vector2(640, 640)), 99)
	var metrics := model.get_metrics()
	_assert(float(metrics["left_temperature"]) > float(metrics["right_temperature"]), "Hotter left initialization did not produce larger mean kinetic energy.")

func _test_dense_mode_has_collisions() -> void:
	var model = SimulationModelScript.new()
	var params := PresetLibraryScript.presets()[2].duplicate(true)
	model.configure(params, Rect2(Vector2.ZERO, Vector2(12.0, 10.0)), 42)
	var seen_collision := false
	for _i in range(240):
		var metrics := model.step(1.0 / 120.0, false)
		if int(metrics.get("collision_events", 0)) > 0:
			seen_collision = true
			break
	_assert(seen_collision, "Dense collisional preset did not produce visible pair collisions.")

func _test_entropy_stability() -> void:
	var model = SimulationModelScript.new()
	model.configure(PresetLibraryScript.sandbox_defaults(), Rect2(Vector2.ZERO, Vector2(640, 640)), 77)
	for _i in range(240):
		model.step(1.0 / 120.0, _i % 40 < 12)
	var metrics := model.get_metrics()
	_assert(is_finite(float(metrics["total_entropy"])), "Displayed entropy became non-finite.")
	_assert(is_finite(float(metrics["smoothed_ds_dt"])), "Displayed entropy derivative became non-finite.")

func _test_persistence_hash() -> void:
	var store = PersistenceStoreScript.new()
	var params := PresetLibraryScript.sandbox_defaults()
	params["atom_count"] = 37
	var hash_key := store.canonical_hash(params)
	var scores := {
		"score_a_longest_negative_interval": 1.5,
		"score_b_single_event_drop": 0.3,
		"score_c_total_reduction": 0.7,
		"score_d_delta_t_gain": 0.2
	}
	store.update_scores(hash_key, scores)
	var loaded := store.get_scores(hash_key)
	_assert(abs(float(loaded["score_c_total_reduction"]) - 0.7) < 0.0001, "Persistent scores did not round-trip by parameter hash.")

func _test_mobile_layout() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	var gate_button: Button = scene.get_node("%GateButton")
	var sim_view: Control = scene.get_node("%SimulationView")
	_assert(ProjectSettings.get_setting("display/window/size/viewport_height") > ProjectSettings.get_setting("display/window/size/viewport_width"), "Project is not configured portrait-first.")
	_assert(gate_button.custom_minimum_size.y >= 72.0, "Gate button is too small for touch-first layout.")
	_assert(sim_view.custom_minimum_size.y >= 320.0, "Simulation view is too compressed for portrait readability.")
	scene.free()

func _total_ke(particles: Array) -> float:
	var total := 0.0
	for particle in particles:
		total += 0.5 * (particle["vel"] as Vector2).length_squared()
	return total

func _total_momentum(particles: Array) -> Vector2:
	var total := Vector2.ZERO
	for particle in particles:
		total += particle["vel"]
	return total

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
