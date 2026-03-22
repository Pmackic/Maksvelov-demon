# agent.md

You are building a Godot 4 educational simulation/game called **Maxwell’s Demon**.

## Mission
Produce a mobile-first, inspectable, scientifically honest 2D sandbox that demonstrates demon-style sorting of a classical gas without falsely claiming a real second-law violation.

## Core rules
1. Never blur the line between:
   - exact microscopic dynamics,
   - coarse-grained displayed entropy,
   - information-processing cost of the demon.
2. Prefer documented approximations over hidden complexity.
3. Every equation must be traceable in comments/docs.
4. Mobile-first and presentation-first:
   - readable in portrait
   - large touch targets
   - minimal cognitive load
5. Code must be easy for a human to inspect and modify quickly.

## What “done” means
- The sim runs.
- The player can operate the gate.
- Left/right temperatures differ visibly.
- Entropy and score logic are explained and working.
- Preset levels exist.
- Placeholder art is swappable.
- Docs are strong enough for a scientist audience.

## Priorities
1. Scientific honesty
2. Stable simulation
3. Clean UI
4. Readable code
5. Presentable polish

## Avoid
- “Looks right” fake physics
- Mystery constants without explanation
- Overengineered architecture
- Fancy art before core sim correctness
- Any claim that the full second law is broken

## If uncertain
Choose the option that is:
- easier to explain,
- easier to inspect,
- more clearly documented,
- less likely to overclaim.
