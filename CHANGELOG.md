# Changelog

## 0.10.0

- Enabled Arms (specialization 71) by default and disabled Fury (72) and Protection (73) by default.
- Added character-scoped master and per-specialization switches, with `/ew on`, `/ew off`, and `/ew spec on|off`.
- Added independent bar width, height, and spacing controls while reusing the existing overall scale slider.
- Deferred protected native Aura rebuilds and visibility changes until combat ends; disabling immediately invalidates predictions and alert state.
- Reorganized the settings panel around character/spec controls, display toggles, sizing, scaling, and alert controls.
- Added migration, multi-character isolation, specialization lifecycle, combat shutdown, and sizing regression coverage.

## 0.9.1

- Added independent predicted countdowns and progress fills to external red debt bars.
- Transferred the earliest external timer into the five-slot group when a new stack is gained below the cap, preserving its remaining time.
- Added a full-duration timer for each additional overflow proc.
- Kept the five in-group bars green and external debt bars red.
- Removed external-bar fade cycles so countdown values remain readable.
- Added regression coverage for timer transfer, expiration preservation, and cleared UI state.

## 0.9.0

- Split the addon into nine focused Lua modules.
- Added targeted Cooldown Manager observation, state recovery, and protected native aura rendering.
- Added five vertical bars, prediction status, debt animation, alerts, settings, and optional diagnostics.
