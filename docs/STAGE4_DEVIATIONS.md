# Stage 4 notes

Stage 1–3 notes still apply unless this file replaces them.

## Art

`assets/art/` holds the generated pack: hero webp (path and rank; `hero_default` dropped as a duplicate of `hero_base`), 720×1280 world webp (png and 360 copies dropped), and icons at 64 and 128. `ArtBank` still falls back to the stage-1 placeholders if a file is missing. The cultivator uses the path sprite when a path is joined, otherwise the rank sprite, with an additive path-tinted aura, float, and Qi motes behind it. Each world uses its background with a slow drift and fog. Text sits on dark panels.

## Live numbers

Qi past 1e300 is a mantissa and an exponent in both the sim and the Godot tick. Early values stay on the float path, so golden ticks still match. Save version is 5.

## Frame cost and package size

The economy steps at `balance.tick_seconds` (0.25s). A frame only accumulates time, and a hitch runs at most 20 steps. Hero and world textures import as VRAM-compressed (ETC2/ASTC). The 128px icon masters live in `assets/art/icons128/` and are excluded from the APK; the UI uses the 64px set. The export preset also leaves out `tools/`, `docs/`, `test/`, and `.github/`.

Debug APK before the art pack (CI artifact on the settings commit): **58,849,567 bytes** (about 56.1 MiB). The size after compression is the `cbh-debug-apk` artifact on the optimization commit.

## Worlds after the first ascension

Heavenly rites, void seals, and chaos attunements are bought with that world's resource and change pressure, dust, forge slots, or Qi. Breakthrough costs after an ascension use `ascension_cost_scale` and `ascension_later_scale`. See `docs/BALANCE_NOTES.md`.
