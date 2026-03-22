# README_BRIEF.md

Maxwell’s Demon is a mobile-first 2D simulation/game where the player controls a gate between two chambers of gas.

The atoms obey simple classical 2D mechanics with elastic collisions. The left and right chambers can start at different temperatures, represented by different speed distributions. The player tries to selectively let particles cross in a way that strengthens the temperature gradient.

The displayed entropy is a coarse-grained statistical measure over observable particle distributions, not the exact microscopic entropy of the full isolated system. This makes the sandbox scientifically honest while still letting the audience see the relation between sorting, temperature difference, and informational control.

Main player goal:
- make hot hotter and cold colder
- sustain negative displayed entropy trend
- set highscores for parameter presets
