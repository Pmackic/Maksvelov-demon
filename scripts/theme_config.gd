extends RefCounted
class_name ThemeConfig

# Centralized theme values. This is a UX/theme configuration file, not a physics file.
# Colors, pulse timings, labels, and placeholder audio choices can be swapped here without
# changing the simulation logic.

const COLORS := {
	"bg_top": Color("0d1622"),
	"bg_bottom": Color("122235"),
	"panel": Color("f1ecdf"),
	"panel_alt": Color("e3dbc8"),
	"panel_border": Color("14212d"),
	"text": Color("13202b"),
	"muted": Color("6c7c89"),
	"accent": Color("145da0"),
	"accent_hover": Color("1a74c3"),
	"accent_pressed": Color("10497d"),
	"text_on_accent": Color("eef4fb"),
	"left_chamber": Color("15304d"),
	"right_chamber": Color("3f2025"),
	"wall": Color("b8c7d6"),
	"gate_closed": Color("ffd166"),
	"gate_open": Color("7ee081"),
	"good_flash": Color("8ef0b5"),
	"bad_flash": Color("f2a3a3"),
	"slow": Color("4ea3ff"),
	"mean": Color("9b7bff"),
	"fast": Color("ff5b4d")
}

const LAYOUT := {
	"sim_margin": 12.0,
	"panel_corner": 18,
	"gate_button_height": 76,
	"feedback_duration": 0.45,
	"pulse_period": 0.6
}
