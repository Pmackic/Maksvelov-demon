# Testing

## Headless Test Command

```bash
godot4 --headless --path . -s tests/test_runner.gd
```

## Covered Checks

- total kinetic energy stays within tolerance when walls and pair collisions are elastic
- equal-mass pair collision response preserves momentum and kinetic energy within tolerance
- hotter initialization produces larger mean kinetic energy than cooler initialization
- entropy estimator remains finite and stable
- highscores persist by exact parameter hash
- touch-oriented gate control exists as a large button in the portrait-first scene
- portrait layout loads and exposes readable core panels

## Notes

- The physics tests use tolerances because the simulation is discrete-time, not event-driven exact collision scheduling.
- The UI tests are structural, not screenshot comparisons.
- The bookkeeping channel is intentionally tested separately from core scores because it is marked experimental.
