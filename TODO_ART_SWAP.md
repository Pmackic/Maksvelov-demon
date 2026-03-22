# TODO Art / Audio Swap

Replacement points are centralized so the scientific code does not need visual edits.

## Visual Theme

- `scripts/theme_config.gd`
  - chamber colors
  - gate colors
  - particle speed colors
  - panel colors
  - flash/pulse colors

## Placeholder Assets

- `assets/placeholders/app_icon.svg`
- `assets/placeholders/atom_placeholder.svg`
- `assets/placeholders/gate_placeholder.svg`

These are not hard-wired into the simulation draw path yet; they exist as clear replacement anchors for later skinning.

## UI Scene

- `scenes/Main.tscn`
  - control sizes
  - button labels
  - panel arrangement

## Simulation Rendering

- `ui/SimulationView.gd`
  - particle draw style
  - gate glow
  - assist rings
  - chamber backgrounds

## Audio

- `scripts/audio_feedback.gd`
  - `play_good()`
  - `play_bad()`

Current tones are synthetic placeholders generated at runtime. Replace with sample playback if preferred.

## Fonts

- currently uses Godot fallback fonts
- future theme swap can add imported fonts and theme overrides in `scenes/Main.tscn` or a dedicated theme resource
