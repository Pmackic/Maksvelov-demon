extends Control
class_name SimulationView

const ThemeConfigScript = preload("res://scripts/theme_config.gd")

var model = null
var feedback_state := 0
var feedback_time := 0.0
var gate_button_pressed := false
var visual_theme = ThemeConfigScript.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	feedback_time = max(0.0, feedback_time - delta)
	queue_redraw()

func flash_good() -> void:
	feedback_state = 1
	feedback_time = ThemeConfigScript.LAYOUT["feedback_duration"]

func flash_bad() -> void:
	feedback_state = -1
	feedback_time = ThemeConfigScript.LAYOUT["feedback_duration"]

func _draw() -> void:
	var rect := get_rect()
	draw_rect(rect, visual_theme.COLORS["bg_top"], true)
	var lower_rect := Rect2(rect.position, rect.size)
	lower_rect.position.y += rect.size.y * 0.55
	lower_rect.size.y = rect.size.y * 0.45
	draw_rect(lower_rect, visual_theme.COLORS["bg_bottom"], true)

	if model == null or model.particles.is_empty():
		return

	var margin: float = float(ThemeConfigScript.LAYOUT.get("sim_margin", 12.0))
	var sim_rect: Rect2 = Rect2(Vector2(margin, margin), rect.size - Vector2(margin * 2.0, margin * 2.0))
	var world_scale: float = sim_rect.size.x / model.world_rect.size.x
	var separator_x := sim_rect.position.x + sim_rect.size.x * 0.5
	var gate_height: float = model.get_scaled_gate_height() * world_scale
	var gate_y0 = sim_rect.position.y + (sim_rect.size.y - gate_height) * 0.5
	var gate_y1 = gate_y0 + gate_height

	draw_rect(sim_rect, Color(0, 0, 0, 0), false, 4.0, true)
	draw_rect(Rect2(sim_rect.position, Vector2(sim_rect.size.x * 0.5, sim_rect.size.y)), visual_theme.COLORS["left_chamber"], true)
	draw_rect(Rect2(Vector2(separator_x, sim_rect.position.y), Vector2(sim_rect.size.x * 0.5, sim_rect.size.y)), visual_theme.COLORS["right_chamber"], true)

	draw_line(Vector2(separator_x, sim_rect.position.y), Vector2(separator_x, gate_y0), visual_theme.COLORS["wall"], 5.0, true)
	draw_line(Vector2(separator_x, gate_y1), Vector2(separator_x, sim_rect.end.y), visual_theme.COLORS["wall"], 5.0, true)

	var gate_color = visual_theme.COLORS["gate_open"] if model.gate_open else visual_theme.COLORS["gate_closed"]
	var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() / 1000.0 * TAU / ThemeConfigScript.LAYOUT["pulse_period"])
	draw_rect(Rect2(Vector2(separator_x - 8.0, gate_y0), Vector2(16.0, gate_height)), gate_color * pulse, true)

	if feedback_time > 0.0:
		var alpha = feedback_time / ThemeConfigScript.LAYOUT["feedback_duration"]
		var flash_color = visual_theme.COLORS["good_flash"] if feedback_state > 0 else visual_theme.COLORS["bad_flash"]
		draw_rect(sim_rect.grow(4.0), flash_color * Color(1, 1, 1, alpha * 0.35), true)

	var metrics = model.get_metrics()
	var mean_speed: float = float(metrics["global_mean_speed"])
	var speed_std: float = max(0.0001, float(metrics["global_speed_std"]))
	var display_std: float = max(0.0001, speed_std * 0.55)
	var bimodal_demo := bool(model.params.get("bimodal_demo_init", false))
	var slow_anchor: float = model.get_scaled_showcase_speed(float(model.params.get("slow_speed", 0.45)))
	var fast_anchor: float = model.get_scaled_showcase_speed(float(model.params.get("fast_speed", 2.8)))
	var anchor_span: float = max(0.0001, fast_anchor - slow_anchor)
	for particle in model.particles:
		var world_pos: Vector2 = particle["pos"]
		var local: Vector2 = _world_to_view(world_pos, sim_rect)
		var speed: float = (particle["vel"] as Vector2).length()
		var color = visual_theme.COLORS["mean"]
		if bimodal_demo:
			var normalized: float = clamp((speed - slow_anchor) / anchor_span, 0.0, 1.0)
			if normalized <= 0.5:
				color = visual_theme.COLORS["slow"].lerp(visual_theme.COLORS["mean"], normalized / 0.5)
			else:
				color = visual_theme.COLORS["mean"].lerp(visual_theme.COLORS["fast"], (normalized - 0.5) / 0.5)
		else:
			var z: float = clamp((speed - mean_speed) / display_std, -3.0, 3.0)
			var signed_strength: float = sign(z) * pow(abs(z) / 3.0, 0.65)
			if signed_strength < 0.0:
				color = visual_theme.COLORS["mean"].lerp(visual_theme.COLORS["slow"], abs(signed_strength))
			elif signed_strength > 0.0:
				color = visual_theme.COLORS["mean"].lerp(visual_theme.COLORS["fast"], signed_strength)
		var radius: float = float(particle["radius"]) * world_scale
		draw_circle(local, max(2.0, radius), color)
		draw_arc(local, max(2.0, radius), 0.0, TAU, 18, Color(0.08, 0.1, 0.14, 0.8), 1.5, true)

func _world_to_view(world_pos: Vector2, sim_rect: Rect2) -> Vector2:
	var local = (world_pos - model.world_rect.position) / model.world_rect.size
	return sim_rect.position + local * sim_rect.size
