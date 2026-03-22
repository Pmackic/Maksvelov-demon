# Maxwell's Demon

Maxwell's Demon is a Godot 4, mobile-first, inspectable 2D sandbox/game. The player controls a gate between two chambers containing a classical 2D gas of equal-mass hard disks. The project is presentation-oriented, but it is framed to stay scientifically honest:

- The microscopic dynamics are Newtonian and approximately Hamiltonian when wall coupling is `0`.
- The displayed entropy bar and score use a coarse-grained one-particle estimator `S_cg`, not the exact fine-grained Gibbs entropy.
- The informational/control cost of the demon is not part of the core score. It is separated into an optional experimental bookkeeping mode.

## What Is Modeled

- Two rectangular chambers separated by a wall with a controllable gate.
- Equal-mass circular particles in 2D with velocities `(v_x, v_y)`.
- Elastic wall collisions by default.
- Elastic equal-mass pair collisions.
- Initialization from independent Gaussian velocity components with
  `sigma^2 = k_B T / m`.
- Dimensionless default units:
  - `k_B = 1`
  - `m = 1`
  - chamber size is `12 x 10` simulation units by default
  - scene distances are simulation units mapped to screen pixels by the UI
  - time is simulation time

## What Is Approximated

- Collision stepping is discrete-time and presentation-oriented, not an event-driven exact billiard solver.
- The displayed entropy is coarse-grained over side, position cells, and speed bins.
- The wall coupling slider introduces a weak thermalizing boundary blend. That is a bath approximation, not exact isolated Hamiltonian evolution.
- The optional demon bookkeeping mode adds a simple Landauer-style `ln 2` cost per gate-open decision. That is explicitly experimental and separate from the core score.
- The default `Sandbox` seed is presentation-oriented: it places a few particles near the gate to create immediate manual sorting opportunities. This is an initialization choice, not an ongoing controller or heuristic in the dynamics.
- All showcase presets now use the same `Fast frac L` / `Fast frac R` controls so the player can vary the left/right fast-particle fractions consistently across the whole presentation.

## Core Formulas

### Velocity Initialization

There are now two explicit initialization modes in the project:

- Theory reference mode:
  `v_x, v_y ~ N(0, sigma^2)`, with `sigma^2 = k_B T / m`.
- Showcase mode used by the current presets:
  particles are initialized as a bimodal slow/fast mixture with user-controlled fast fractions on the left and right.

Rationale: the Gaussian rule is the standard 2D Maxwell-Boltzmann component sampling rule for an ideal gas with equal masses, while the bimodal showcase mode is an intentionally presentation-oriented initialization that makes sorting actions legible on stage.

### Kinetic Energy

For each particle,

`K = 0.5 m v^2`

with `v^2 = v_x^2 + v_y^2`.

### Chamber Temperature Estimator in 2D

Displayed chamber temperature is estimated as

`T_side = mean(0.5 m v^2) / k_B`

and with `m = k_B = 1`,

`T_side = mean(0.5 v^2)`.

This follows from equipartition for two translational degrees of freedom.

### Coarse-Grained Entropy

Particles are binned by:

- chamber side
- spatial cell within chamber
- speed bin

If `p_i` is the normalized occupancy of coarse-grained bin `i`, the displayed entropy is

`S_cg = -k_B sum_i p_i ln(p_i)`.

With `k_B = 1`, this becomes `S_cg = -sum_i p_i ln(p_i)`.

This is a one-particle observable entropy proxy. It is not the exact fine-grained Gibbs entropy of the full closed system.

## UI / Scientific Framing

The UI and docs explicitly distinguish:

1. Exact microscopic Hamiltonian dynamics:
   - hard-disk motion and elastic collisions when wall coupling is `0`.
2. Coarse-grained observable entropy:
   - the displayed `S_cg` bar and score.
3. Demon informational/control cost:
   - optional experimental bookkeeping, kept out of the core score.

## Project Structure

- `scenes/` Godot scenes
- `scripts/` simulation, scoring, persistence, audio
- `ui/` presentation scripts
- `assets/placeholders/` simple swappable placeholder SVGs
- `docs/` reserved for extra notes
- `tests/` headless test runner

## Presets

- `Sandbox`: editable parameters and left/right fast-fraction controls.
- `Szilard-Inspired Low N`: very small `N`, using the same left/right fast-fraction controls.
- `Low-Density Sorting`: easier-to-read selective gate play with the same left/right fast-fraction controls.
- `Dense Collisional`: stronger collisional scrambling with the same left/right fast-fraction controls.
- `Wall-Coupled Bath`: explicit non-isolated wall approximation with the same left/right fast-fraction controls.

## Limitations

- The simulation is educational and inspectable, not a production molecular dynamics package.
- Pair collisions are resolved in a simple discrete pass and can miss exact continuous-time event ordering.
- No internal rotational modes, no quantum effects, no chemical interactions.
- The entropy display is intentionally coarse-grained and depends on chosen bins.
- The optional bookkeeping mode is only a minimal control-cost proxy.

## Maxwell, Szilard, and Landauer

- Maxwell's demon motivates the selective gate-control thought experiment.
- Szilard's lesson is that measurement/control matter in the accounting, especially at very low particle count.
- Landauer's lesson is that information handling can carry thermodynamic cost.

This project therefore does not claim a literal violation of the second law. It shows how local sorting can drive a visible coarse-grained decrease while leaving full thermodynamic accounting incomplete unless demon bookkeeping is modeled explicitly.

## Running

Open the folder in Godot 4.5+ and run `scenes/Main.tscn`, or:

```bash
godot4 --path . 
```

For headless tests:

```bash
godot4 --headless --path . -s tests/test_runner.gd
```
