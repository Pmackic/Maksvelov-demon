# Physics Notes

## Scope

The core model is a classical 2D gas of equal-mass hard disks in two chambers. The most important scientific distinction in this project is between:

1. Microscopic state evolution.
2. Displayed coarse-grained observable entropy.
3. Demon information-processing cost.

Those are intentionally not merged into one misleading number.

## Microscopic Dynamics

### Free Motion

Between collisions, each particle follows Newtonian inertial motion:

`r(t + dt) = r(t) + v(t) dt`

with constant velocity over the step.

### Pair Collisions

For two equal masses, an elastic collision changes only the velocity components along the collision normal. The tangential component is preserved. In center-of-mass language, this is the standard equal-mass hard-disk result.

In the discrete solver, overlapping pairs are separated and their relative normal velocity is reflected. This preserves total momentum and kinetic energy up to numerical tolerance.

### Wall Collisions

With wall coupling `= 0`, wall collisions are perfectly elastic:

- reverse normal velocity component
- preserve tangential component

That is the intended isolated baseline.

## Initialization and Temperature

For the theory reference initialization, velocities are initialized from independent Gaussian components:

`v_x, v_y ~ N(0, sigma^2)`

with

`sigma^2 = k_B T / m`.

In the default dimensionless units:

- `k_B = 1`
- `m = 1`
- so `sigma^2 = T`

For a 2D ideal gas with only translational degrees of freedom,

`<K> = k_B T`

because there are two quadratic translational modes, each contributing `0.5 k_B T`.

So the displayed chamber temperature estimator is

`T_side = mean(K) / k_B = mean(0.5 m v^2) / k_B`

and in default units:

`T_side = mean(0.5 v^2)`.

Current presentation presets also expose a showcase initialization:

- each side is initialized as a slow/fast mixture
- `Fast frac L` sets the left fast-particle share
- `Fast frac R` sets the right fast-particle share

This showcase initialization is intentionally easier to control live in a presentation than pure temperature sliders. It is not the same thing as literal Maxwell-Boltzmann temperature initialization, and the project should say so explicitly.

## Why Coarse-Grained Entropy Is Used

The exact fine-grained Gibbs entropy of a closed Hamiltonian system does not simply fall because the player sees a temporary sort. For a presentation, though, audiences need a visible scalar that responds to the observable one-particle distribution.

So the project uses a coarse-grained one-particle phase-space estimator:

- side
- spatial cell
- speed bin

This produces

`S_cg = -sum_i p_i ln(p_i)`.

What this means:

- It is an entropy-like observable tied to visible organization.
- It is sensitive to binning choice.
- It is not the full thermodynamic entropy production accounting.

That is why the UI calls it `Displayed S_cg` and not simply `entropy`.

## Smoothed Derivative

The displayed `dS/dt` is a short moving average over recent entropy estimates.

Important:

- only the displayed derivative is smoothed
- the physics state is not smoothed
- the entropy value itself is not artificially filtered in the collision dynamics

This is a UX approximation used only to reduce score noise.

## Wall Coupling / Bath Approximation

When wall coupling is greater than zero, outgoing wall-collision velocities are blended with a Gaussian sample tied to the side temperature.

Interpretation:

- this is a weak boundary thermostat approximation
- it is not exact Hamiltonian isolation
- it is included only because many presentations benefit from showing a bath-assisted case explicitly

The preset and UI label this as wall coupling / bath assistance.

## Demon Bookkeeping Cost

The optional experimental mode adds a simple `ln 2` per gate-open decision. This is a deliberately rough Landauer-style note, not a full measurement-memory-erasure model.

It is kept separate because:

- the control protocol is not modeled in full detail
- real informational thermodynamic cost depends on the measurement/storage/erasure story
- mixing it into the core score would overclaim precision

## Limitations

- The solver is discrete-time, not event-driven exact billiards.
- Hard disks have no internal structure or quantum behavior.
- The gate decision logic is player-driven manual control, not an optimized feedback controller.
- The entropy proxy is one-particle and coarse-grained.

These limitations are acceptable here because the project prioritizes inspectability and scientific clarity over maximal physical fidelity.
