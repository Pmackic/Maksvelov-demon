# plan.md

## Phase 1 — Physics skeleton
- Create 2D chamber scene with separator and gate
- Implement particle state update
- Implement elastic wall and particle collisions
- Implement deterministic reinitialization from parameters

## Phase 2 — Thermodynamics layer
- Compute per-side kinetic observables
- Compute T_left, T_right, DeltaT
- Implement coarse-grained phase-space entropy estimator
- Add smoothed displayed entropy derivative

## Phase 3 — Gameplay layer
- Gate interaction
- Good/bad crossing detection
- Feedback effects
- Run lifecycle and reset

## Phase 4 — Scores and presets
- Reversal timer
- Single-event entropy drop score
- Total reversal score
- Preset parameter packs
- Persistent highscores by parameter hash

## Phase 5 — Mobile UI
- Portrait layout
- Large gate button
- Slider panel
- Compact observables panel
- Help overlay

## Phase 6 — Docs and tests
- README
- PHYSICS_NOTES
- PRESENTATION_SCRIPT
- TODO_ART_SWAP
- TESTING
- Basic invariants / regression tests

## Phase 7 — Polish
- Placeholder sound cues
- Animation pulses
- Better labels and formatting
- Final pass on comments
