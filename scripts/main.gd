extends Control

const SIM_BASE_HEIGHT := 10.0
const FIXED_DT := 1.0 / 120.0
const ThemeConfigScript = preload("res://scripts/theme_config.gd")
const PresetLibraryScript = preload("res://scripts/preset_library.gd")
const PersistenceStoreScript = preload("res://scripts/persistence.gd")
const SimulationModelScript = preload("res://scripts/simulation_model.gd")

@onready var simulation_view = %SimulationView
@onready var metrics_panel: PanelContainer = $RootMargin/MainVBox/MetricsPanel
@onready var metrics_margin: MarginContainer = $RootMargin/MainVBox/MetricsPanel/MetricsMargin
@onready var metrics_vbox: VBoxContainer = $RootMargin/MainVBox/MetricsPanel/MetricsMargin/MetricsVBox
@onready var bottom_panel: PanelContainer = $RootMargin/MainVBox/BottomPanel
@onready var bottom_margin: MarginContainer = $RootMargin/MainVBox/BottomPanel/BottomScroll/BottomMargin
@onready var bottom_vbox: VBoxContainer = $RootMargin/MainVBox/BottomPanel/BottomScroll/BottomMargin/BottomVBox
@onready var setup_label: Label = $RootMargin/MainVBox/BottomPanel/BottomScroll/BottomMargin/BottomVBox/SetupLabel
@onready var top_row: HBoxContainer = $RootMargin/MainVBox/BottomPanel/BottomScroll/BottomMargin/BottomVBox/TopRow
@onready var controls_grid: GridContainer = $RootMargin/MainVBox/BottomPanel/BottomScroll/BottomMargin/BottomVBox/ControlsGrid
@onready var toggle_row: VBoxContainer = $RootMargin/MainVBox/BottomPanel/BottomScroll/BottomMargin/BottomVBox/ToggleRow
@onready var preset_select: OptionButton = %PresetSelect
@onready var theory_note: RichTextLabel = %TheoryNote
@onready var gate_button: Button = %GateButton
@onready var reset_button: Button = %ResetButton
@onready var n_slider: HSlider = %AtomCountSlider
@onready var n_value: Label = %AtomCountValue
@onready var left_name: Label = %LeftTempName
@onready var left_slider: HSlider = %LeftTempSlider
@onready var left_value: Label = %LeftTempValue
@onready var right_name: Label = %RightTempName
@onready var right_slider: HSlider = %RightTempSlider
@onready var right_value: Label = %RightTempValue
@onready var coupling_slider: HSlider = %WallCouplingSlider
@onready var coupling_value: Label = %WallCouplingValue
@onready var ai_lookahead_name: Label = %AILookaheadName
@onready var ai_lookahead_slider: HSlider = %AILookaheadSlider
@onready var ai_lookahead_value: Label = %AILookaheadValue
@onready var ai_demon_toggle: CheckBox = %AIDemonToggle
@onready var obs_label: RichTextLabel = %ObservablesLabel
@onready var entropy_bar: ProgressBar = %EntropyBar
@onready var entropy_label: Label = %EntropyLabel
@onready var score_label: RichTextLabel = %ScoreLabel
@onready var status_label: Label = %StatusLabel
@onready var highscore_label: RichTextLabel = %HighscoreLabel
@onready var audio_feedback = %AudioFeedback

var visual_theme = ThemeConfigScript.new()
var preset_defs: Array[Dictionary] = []
var persistence = PersistenceStoreScript.new()
var model = SimulationModelScript.new()
var manual_gate_pressed := false
var current_params: Dictionary = {}
var current_hash := ""
var local_highscores: Dictionary = {}
var _syncing_controls := false
var _status_kind := 0

func _ready() -> void:
	_apply_theme()
	preset_defs = [PresetLibraryScript.sandbox_defaults()]
	preset_defs.append_array(PresetLibraryScript.presets())
	for preset in preset_defs:
		preset_select.add_item(preset["label"])
	_connect_signals()
	resized.connect(_on_layout_changed)
	simulation_view.resized.connect(_on_layout_changed)
	bottom_panel.resized.connect(_on_layout_changed)
	preset_select.select(0)
	_apply_preset(preset_defs[0])
	_apply_dynamic_ui_scale()
	highscore_label.visible = false
	obs_label.visible = false
	status_label.visible = false

func _physics_process(_delta: float) -> void:
	if model.params.is_empty():
		return
	var gate_state := model.should_ai_open_gate(FIXED_DT) if ai_demon_toggle.button_pressed else manual_gate_pressed
	var metrics_before = model.get_metrics()
	var entropy_before := float(metrics_before.get("total_entropy", 0.0))
	var metrics = model.step(FIXED_DT, gate_state)
	simulation_view.model = model
	var entropy_after := float(metrics.get("total_entropy", 0.0))
	_update_ui(metrics)
	if int(metrics.get("crossing_count", 0)) > 0 and entropy_after < entropy_before:
		simulation_view.flash_good()
		audio_feedback.play_good()
		_status_kind = 1
	elif int(metrics.get("crossing_count", 0)) > 0 and entropy_after > entropy_before:
		simulation_view.flash_bad()
		audio_feedback.play_bad()
		_status_kind = -1
	else:
		_status_kind = 0

func _connect_signals() -> void:
	preset_select.item_selected.connect(_on_preset_selected)
	reset_button.pressed.connect(_reset_run)
	gate_button.button_down.connect(func() -> void: manual_gate_pressed = true)
	gate_button.button_up.connect(func() -> void: manual_gate_pressed = false)
	n_slider.value_changed.connect(func(value: float) -> void:
		if _syncing_controls:
			return
		n_value.text = str(int(value))
		_update_showcase_param("atom_count", int(value))
	)
	left_slider.value_changed.connect(func(value: float) -> void:
		if _syncing_controls:
			return
		left_value.text = "%.2f" % value
		_update_showcase_param("left_fast_fraction", value)
	)
	right_slider.value_changed.connect(func(value: float) -> void:
		if _syncing_controls:
			return
		right_value.text = "%.2f" % value
		_update_showcase_param("right_fast_fraction", value)
	)
	coupling_slider.value_changed.connect(func(value: float) -> void:
		if _syncing_controls:
			return
		coupling_value.text = "%.2f" % value
		if current_params.get("preset_id", "") != "sandbox":
			return
		_update_showcase_param("wall_coupling", value)
	)
	ai_lookahead_slider.value_changed.connect(func(value: float) -> void:
		if _syncing_controls:
			return
		ai_lookahead_value.text = str(int(value))
		if current_params.get("preset_id", "") != "sandbox":
			return
		_update_showcase_param("ai_lookahead_steps", int(value))
	)
	ai_demon_toggle.toggled.connect(func(pressed: bool) -> void:
		if _syncing_controls:
			return
		if current_params.get("preset_id", "") != "sandbox":
			return
		_update_showcase_param("perfect_demon_ai", pressed)
	)

func _apply_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.set_color("font_color", "Label", visual_theme.COLORS["text"])
	ui_theme.set_color("font_color", "CheckBox", visual_theme.COLORS["text"])
	ui_theme.set_color("font_color", "Button", visual_theme.COLORS["text_on_accent"])
	ui_theme.set_color("font_color", "OptionButton", visual_theme.COLORS["text_on_accent"])
	ui_theme.set_color("font_color", "RichTextLabel", visual_theme.COLORS["text"])
	ui_theme.set_color("default_color", "RichTextLabel", visual_theme.COLORS["text"])
	ui_theme.set_color("font_placeholder_color", "LineEdit", visual_theme.COLORS["muted"])
	ui_theme.set_font_size("font_size", "Label", 16)
	ui_theme.set_font_size("font_size", "CheckBox", 15)
	ui_theme.set_font_size("font_size", "Button", 16)
	ui_theme.set_font_size("font_size", "OptionButton", 16)
	ui_theme.set_font_size("font_size", "ProgressBar", 16)
	ui_theme.set_font_size("normal_font_size", "RichTextLabel", 15)
	ui_theme.set_font_size("bold_font_size", "RichTextLabel", 16)

	var button_style := StyleBoxFlat.new()
	button_style.bg_color = visual_theme.COLORS["accent"]
	button_style.border_color = visual_theme.COLORS["panel_border"]
	button_style.corner_radius_top_left = 14
	button_style.corner_radius_top_right = 14
	button_style.corner_radius_bottom_left = 14
	button_style.corner_radius_bottom_right = 14
	button_style.content_margin_left = 12
	button_style.content_margin_right = 12
	button_style.content_margin_top = 10
	button_style.content_margin_bottom = 10
	button_style.border_width_left = 2
	button_style.border_width_top = 2
	button_style.border_width_right = 2
	button_style.border_width_bottom = 2

	var button_hover := button_style.duplicate()
	button_hover.bg_color = visual_theme.COLORS["accent_hover"]
	var button_pressed := button_style.duplicate()
	button_pressed.bg_color = visual_theme.COLORS["accent_pressed"]
	var checkbox_off := button_style.duplicate()
	checkbox_off.bg_color = visual_theme.COLORS["panel_alt"]
	var checkbox_on := button_style.duplicate()
	checkbox_on.bg_color = visual_theme.COLORS["accent"]

	ui_theme.set_stylebox("normal", "Button", button_style)
	ui_theme.set_stylebox("hover", "Button", button_hover)
	ui_theme.set_stylebox("pressed", "Button", button_pressed)
	ui_theme.set_stylebox("normal", "OptionButton", button_style)
	ui_theme.set_stylebox("hover", "OptionButton", button_hover)
	ui_theme.set_stylebox("pressed", "OptionButton", button_pressed)
	ui_theme.set_stylebox("normal", "CheckBox", checkbox_off)
	ui_theme.set_stylebox("pressed", "CheckBox", checkbox_on)
	ui_theme.set_stylebox("hover", "CheckBox", checkbox_off)
	ui_theme.set_color("font_color", "CheckBox", visual_theme.COLORS["text"])

	var progress_bg := StyleBoxFlat.new()
	progress_bg.bg_color = Color("c9d2dc")
	progress_bg.border_color = visual_theme.COLORS["panel_border"]
	progress_bg.corner_radius_top_left = 10
	progress_bg.corner_radius_top_right = 10
	progress_bg.corner_radius_bottom_left = 10
	progress_bg.corner_radius_bottom_right = 10
	progress_bg.border_width_left = 2
	progress_bg.border_width_top = 2
	progress_bg.border_width_right = 2
	progress_bg.border_width_bottom = 2

	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = visual_theme.COLORS["fast"]
	progress_fill.corner_radius_top_left = 8
	progress_fill.corner_radius_top_right = 8
	progress_fill.corner_radius_bottom_left = 8
	progress_fill.corner_radius_bottom_right = 8

	theme = ui_theme
	ui_theme.set_stylebox("background", "ProgressBar", progress_bg)
	ui_theme.set_stylebox("fill", "ProgressBar", progress_fill)

	var style := StyleBoxFlat.new()
	style.bg_color = visual_theme.COLORS["panel"]
	style.border_color = visual_theme.COLORS["panel_border"]
	style.corner_radius_top_left = ThemeConfigScript.LAYOUT["panel_corner"]
	style.corner_radius_top_right = ThemeConfigScript.LAYOUT["panel_corner"]
	style.corner_radius_bottom_left = ThemeConfigScript.LAYOUT["panel_corner"]
	style.corner_radius_bottom_right = ThemeConfigScript.LAYOUT["panel_corner"]
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	$RootMargin/MainVBox/MetricsPanel.add_theme_stylebox_override("panel", style)
	$RootMargin/MainVBox/BottomPanel.add_theme_stylebox_override("panel", style)
	gate_button.custom_minimum_size.y = ThemeConfigScript.LAYOUT["gate_button_height"]
	gate_button.add_theme_font_size_override("font_size", 20)
	entropy_bar.custom_minimum_size.y = 28
	entropy_label.add_theme_color_override("font_color", visual_theme.COLORS["text"])
	entropy_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_font_size_override("normal_font_size", 17)
	score_label.add_theme_font_size_override("bold_font_size", 18)
	_apply_dynamic_ui_scale()

func _apply_dynamic_ui_scale() -> void:
	if not is_node_ready():
		return
	var available_height: float = max(220.0, bottom_panel.size.y)
	var design_height: float = _bottom_panel_design_height()
	var scale_factor: float = clamp(available_height / design_height, 0.48, 1.05)
	var label_size: int = int(round(14.0 * scale_factor))
	var value_size: int = int(round(16.0 * scale_factor))
	var button_size: int = int(round(16.0 * scale_factor))
	var rich_normal: int = int(round(15.0 * scale_factor))
	var rich_bold: int = int(round(17.0 * scale_factor))
	var section_size: int = int(round(19.0 * scale_factor))
	var margin_h: int = int(round(16.0 * scale_factor))
	var margin_v: int = int(round(12.0 * scale_factor))
	var row_height: float = round(30.0 * scale_factor)
	var tall_row_height: float = round(52.0 * scale_factor)
	var gate_height: float = round(float(ThemeConfigScript.LAYOUT["gate_button_height"]) * scale_factor)
	var note_height: float = round(72.0 * scale_factor)
	var name_width: float = round(118.0 * scale_factor)
	var value_width: float = round(56.0 * scale_factor)

	bottom_margin.add_theme_constant_override("margin_left", margin_h)
	bottom_margin.add_theme_constant_override("margin_right", margin_h)
	bottom_margin.add_theme_constant_override("margin_top", margin_v)
	bottom_margin.add_theme_constant_override("margin_bottom", margin_v)
	bottom_vbox.add_theme_constant_override("separation", int(round(8.0 * scale_factor)))
	top_row.add_theme_constant_override("separation", int(round(8.0 * scale_factor)))
	controls_grid.add_theme_constant_override("h_separation", int(round(8.0 * scale_factor)))
	controls_grid.add_theme_constant_override("v_separation", int(round(6.0 * scale_factor)))
	toggle_row.add_theme_constant_override("separation", int(round(6.0 * scale_factor)))

	gate_button.custom_minimum_size.y = gate_height
	gate_button.add_theme_font_size_override("font_size", int(round(20.0 * scale_factor)))
	reset_button.custom_minimum_size.y = tall_row_height
	reset_button.add_theme_font_size_override("font_size", button_size)
	preset_select.custom_minimum_size.y = tall_row_height
	preset_select.add_theme_font_size_override("font_size", button_size)
	setup_label.custom_minimum_size.y = row_height
	setup_label.add_theme_font_size_override("font_size", section_size)
	ai_demon_toggle.custom_minimum_size.y = tall_row_height
	ai_demon_toggle.add_theme_font_size_override("font_size", label_size)

	entropy_bar.custom_minimum_size.y = 26.0
	entropy_label.add_theme_font_size_override("font_size", 16)
	theory_note.custom_minimum_size.y = note_height
	theory_note.add_theme_font_size_override("normal_font_size", rich_normal)
	theory_note.add_theme_font_size_override("bold_font_size", rich_bold)
	score_label.custom_minimum_size.y = 84.0
	score_label.add_theme_font_size_override("normal_font_size", 15)
	score_label.add_theme_font_size_override("bold_font_size", 16)
	highscore_label.custom_minimum_size.y = note_height
	highscore_label.add_theme_font_size_override("normal_font_size", rich_normal)
	highscore_label.add_theme_font_size_override("bold_font_size", rich_bold)
	status_label.add_theme_font_size_override("font_size", value_size)
	status_label.custom_minimum_size.y = row_height

	for child in controls_grid.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size", value_size if child.name.ends_with("Value") else label_size)
			child.custom_minimum_size.y = row_height
			if child.name.ends_with("Value"):
				child.custom_minimum_size.x = value_width
				child.autowrap_mode = TextServer.AUTOWRAP_OFF
			else:
				child.custom_minimum_size.x = name_width
				child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif child is HSlider:
			child.custom_minimum_size.y = tall_row_height
			child.custom_minimum_size.x = 0.0

func _bottom_panel_design_height() -> float:
	var grid_rows: int = int(ceil(float(controls_grid.get_child_count()) / max(1.0, float(controls_grid.columns))))
	var visible_blocks := 6
	# gate button, setup label, top row, theory note, controls grid, toggle row
	var design_height: float = 24.0
	design_height += 76.0
	design_height += 30.0
	design_height += 42.0
	design_height += 72.0
	design_height += float(grid_rows) * 52.0
	design_height += 42.0
	design_height += float(max(0, visible_blocks - 1)) * 8.0
	return max(320.0, design_height)

func _apply_preset(preset: Dictionary) -> void:
	current_params = preset.duplicate(true)
	_sync_controls_from_params()
	_rebuild_model()
	theory_note.text = "[b]%s[/b]\n%s" % [preset["label"], preset["theory_note"]]

func _sync_controls_from_params() -> void:
	_syncing_controls = true
	n_slider.value = int(current_params["atom_count"])
	n_value.text = str(int(n_slider.value))
	left_slider.value = float(current_params["left_fast_fraction"])
	left_value.text = "%.2f" % left_slider.value
	right_slider.value = float(current_params["right_fast_fraction"])
	right_value.text = "%.2f" % right_slider.value
	coupling_slider.value = float(current_params["wall_coupling"])
	coupling_value.text = "%.2f" % coupling_slider.value
	ai_lookahead_slider.value = int(current_params.get("ai_lookahead_steps", 5))
	ai_lookahead_value.text = str(int(ai_lookahead_slider.value))
	ai_demon_toggle.button_pressed = bool(current_params.get("perfect_demon_ai", false))
	var sandbox = current_params["preset_id"] == "sandbox"
	left_name.text = "Udeo brzih u levoj komori"
	right_name.text = "Udeo brzih u desnoj komori"
	left_slider.min_value = 0.0
	left_slider.max_value = 1.0
	right_slider.min_value = 0.0
	right_slider.max_value = 1.0
	n_slider.editable = sandbox
	left_slider.editable = true
	right_slider.editable = true
	coupling_slider.editable = sandbox
	ai_lookahead_name.visible = sandbox
	ai_lookahead_slider.visible = sandbox
	ai_lookahead_value.visible = sandbox
	ai_lookahead_slider.editable = sandbox
	ai_demon_toggle.disabled = not sandbox
	_syncing_controls = false

func _update_showcase_param(key: String, value) -> void:
	current_params[key] = value
	if key == "perfect_demon_ai":
		current_params["include_bookkeeping"] = bool(value)
	_rebuild_model()

func _rebuild_model() -> void:
	var sim_rect := _current_world_rect()
	model.configure(current_params, sim_rect, _seed_from_params(current_params))
	simulation_view.model = model
	current_hash = persistence.canonical_hash(current_params)
	local_highscores = persistence.get_scores(current_hash)
	_update_ui(model.get_metrics())

func _seed_from_params(params: Dictionary) -> int:
	var hash_key = persistence.canonical_hash(params)
	return hash_key.substr(0, 7).hex_to_int()

func _reset_run() -> void:
	model.configure(current_params, _current_world_rect(), _seed_from_params(current_params))
	_update_ui(model.get_metrics())

func _update_ui(metrics: Dictionary) -> void:
	if metrics.is_empty():
		return
	current_params["perfect_demon_ai"] = ai_demon_toggle.button_pressed
	current_params["include_bookkeeping"] = ai_demon_toggle.button_pressed
	var sorting_score: float = float(metrics.get("sorting_score", 0.0))
	var disorder_percent: float = clamp((1.0 - sorting_score) * 100.0, 0.0, 100.0)
	var bookkeeping_bits: float = float(metrics.get("bookkeeping_entropy", 0.0)) / log(2.0)
	var ashby_variety: String = _format_ashby_variety()
	var score_text := "[b]Metrike runde[/b]\n"
	if ai_demon_toggle.button_pressed:
		score_text += "AI lookahead %d koraka (%.3f s)\n" % [model.get_ai_lookahead_steps(), model.get_ai_lookahead_time()]
		score_text += "Poslednja AI odluka %.3f bita   neizvesnost %.3f bita\n" % [
			float(metrics.get("ai_decision_bits", 0.0)),
			float(metrics.get("ai_decision_entropy_bits", 0.0))
		]
		score_text += "Ukupan informacioni trošak AI demona %.2f bita\n" % bookkeeping_bits
	entropy_bar.min_value = 0.0
	entropy_bar.max_value = 100.0
	entropy_bar.value = disorder_percent
	entropy_label.text = "Shannonova neuređenost gasa %.1f%%   0%% = najuređenije za ove parametre   100%% = najizmešanije za ove parametre   Ashby-jeva raznovrsnost %s" % [disorder_percent, ashby_variety]
	score_label.text = score_text + "Najveći pad po atomu %.4f   rekord %.4f\nUkupan pad u rundi %.4f\nTrenutni niz bez rasta entropije %.2fs" % [
		model.scoring.score_b_single_event_drop,
		float(local_highscores.get("score_b_single_event_drop", 0.0)),
		model.scoring.score_c_total_reduction,
		model.scoring.non_increasing_time
	]
	local_highscores = persistence.update_scores(current_hash, model.scoring.as_dictionary())
	simulation_view.visible = true

func _on_preset_selected(index: int) -> void:
	_apply_preset(preset_defs[index])

func _current_world_rect() -> Rect2:
	var margin: float = float(ThemeConfigScript.LAYOUT.get("sim_margin", 12.0))
	var available_width: float = max(240.0, simulation_view.size.x)
	var available_height: float = max(320.0, simulation_view.size.y)
	var inner_size: Vector2 = Vector2(
		max(120.0, available_width - margin * 2.0),
		max(120.0, available_height - margin * 2.0)
	)
	var world_width: float = max(SIM_BASE_HEIGHT * 0.9, SIM_BASE_HEIGHT * inner_size.x / inner_size.y)
	return Rect2(Vector2.ZERO, Vector2(world_width, SIM_BASE_HEIGHT))

func _format_ashby_variety() -> String:
	var total_bins: int = 2 * int(current_params.get("bin_x", 1)) * int(current_params.get("bin_y", 1)) * int(current_params.get("speed_bins", 1))
	var atom_count: int = int(current_params.get("atom_count", 1))
	if total_bins <= 1 or atom_count <= 0:
		return "1"
	var log10_variety: float = float(atom_count) * log(float(total_bins)) / log(10.0)
	var occupancy_signature: String = " (%d atoma, %d grubih stanja po atomu)" % [atom_count, total_bins]
	if log10_variety < 6.0:
		return "%d%s" % [int(round(pow(float(total_bins), float(atom_count)))), occupancy_signature]
	return "10^%.2f%s" % [log10_variety, occupancy_signature]

func _on_layout_changed() -> void:
	_apply_dynamic_ui_scale()
	if current_params.is_empty():
		return
	var world_rect: Rect2 = _current_world_rect()
	if model.world_rect.size.is_equal_approx(world_rect.size):
		return
	_rebuild_model()
