# Presentation Script

## 90-Second Version

This is Maxwell's Demon as an inspectable 2D hard-disk gas, not a claim that the second law is literally broken. Each particle is an equal-mass classical disk with Newtonian motion and elastic collisions. The player controls only the gate between the two chambers.

The temperatures shown on the left and right are estimated directly from translational kinetic energy in 2D, so hotter means higher average `0.5 v^2`. The particles are colored by speed z-score: blue is slow, purple is near the current mean, red is fast.

The entropy bar is explicitly labeled as a coarse-grained observable entropy. It bins particles by chamber, position, and speed, then computes `S_cg = -sum p ln p`. That is useful for showing visible organization, but it is not the exact fine-grained entropy of the full microscopic state.

So the honest story is: the demon can create temporary coarse-grained order by selective gating, but full thermodynamic accounting also has to consider information and control cost. That optional bookkeeping mode is shown separately here and is not mixed into the main score.

## 2-Minute Version

Maxwell's Demon is usually introduced as a thought experiment: a tiny gatekeeper sorts fast and slow molecules and seems to make hot hotter and cold colder. This project turns that into a mobile-first sandbox while keeping the scientific framing explicit.

At the microscopic level, the baseline model is a classical 2D gas of equal-mass hard disks. The particles move according to Newtonian mechanics. Pair collisions are elastic, wall collisions are elastic unless I deliberately turn on the wall-coupling slider, and the initial velocity components are sampled from Gaussians with variance `k_B T / m`. In the default units, `k_B = m = 1`, so the variance is just `T`.

The temperatures on each side are not decorative. In two dimensions, the translational temperature estimator is the mean kinetic energy per particle, so with these units it is `T = mean(0.5 v^2)`. That makes the left/right readings and `DeltaT` directly tied to the simulated state.

The key honesty point is the entropy display. The bar here is not the exact Gibbs entropy of the full isolated system. It is a coarse-grained one-particle entropy estimator. I bin particles by which side they are on, where they are within the chamber, and how fast they are moving. From those occupancies I compute `S_cg = -sum p ln p`. That gives a visible measure of organization that audiences can read immediately, but it is only a coarse-grained observable.

So when the player makes a good gate decision and the displayed entropy trend goes negative, what we can honestly say is that coarse-grained visible disorder decreased. What we cannot honestly say is that the second law has been fully defeated. That would require complete accounting for the demon's measurement, memory, and erasure costs. This build keeps that separate, with an optional experimental bookkeeping mode inspired by Landauer-style reasoning.
