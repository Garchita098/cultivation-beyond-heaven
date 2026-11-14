# Stage 1 deviations from TECH_PLAN.md

The plan is still the architecture. These are the concrete changes.

1. **Godot project is the repo root, not `godot/`.** `res://data` is the same `data/*.json` the Python sim reads. A second copy under `godot/data` would drift. `tools/sim/economy.py` therefore loads `../../data`.

2. **`BigNum` is a `class_name` value type, not an autoload.** An autoload is one shared number. The other singletons (`GameState`, `Economy`, `SaveSystem`, `OfflineCalc`, `Content`, `EventBus`, plus a no-op `Automation` hook) are autoloads.

3. **`BigNum.cmp` aligns exponents.** FORMULAS and the tech plan ask for that. The Python sim compares via `to_float`, which becomes inf past exponent 300. Saves split mantissa and exponent when `|exponent| >= 15`, so `1.23e400` stays finite. The sim's `from_save_str` collapses that overflow to zero.

4. **The frame pump is `scenes/main.gd`.** Autoload `_process` would also tick during headless tests. `main.gd` calls `GameState.tick`, `Automation.try_act` (no-op in stage 1), and `SaveSystem.maybe_autosave`.

5. **Stage 1 breakthroughs stop at ranks with `stage <= 1` (through Core Peak).** Later ranks stay on the ladder as a lock. The golden-tick parity sim does not use that cap, so it still matches `tools/sim`.

6. **UI theme is `ui/cbh_theme.gd` (StyleBoxFlat), not a binary `.tres`.** Placeholder PNGs live under `assets/` for the later art pass. The cultivator on screen is `assets/shaders/cultivator_aura.gdshader`.

7. **`export_presets.cfg` is committed without keystore secrets.** CI generates a debug keystore and passes `GODOT_ANDROID_KEYSTORE_DEBUG_*`. The debug APK uses the prebuilt template (Gradle off). Godot 4.7 rejects a minSdk override unless Gradle is on, so `gradle_build/min_sdk` is left empty. The 4.7 Android template manifest is minSdk 24. Portrait lock is the project handheld orientation. ETC2/ASTC import is enabled because Android export requires it.
