# Stage 4 notes

Stage 1–3 notes still apply unless this file replaces them.

## Art

`assets/art/` holds the generated pack: hero webp (path and rank; `hero_default` dropped as a duplicate of `hero_base`), 720×1280 world webp (png and 360 copies dropped), and icons at 64 and 128. `ArtBank` still falls back to the stage-1 placeholders if a file is missing. The cultivator uses the path sprite when a path is joined, otherwise the rank sprite, with an additive path-tinted aura, float, and Qi motes behind it. The sprite is drawn premultiplied, with a radial feather and a dark-haze key, so the texture rectangle does not show. A soft dark ellipse sits behind the figure and is stronger on the Heavenly background. Each world uses its background with a slow drift and fog. Text sits on dark panels.

The sound toggle stays in the save and is hidden until an effect exists. Prices use three significant digits. The screenshot save has one ascension, so the statistics counter and the first-ascension toast agree.

## Live numbers

Qi past 1e300 is a mantissa and an exponent in both the sim and the Godot tick. Early values stay on the float path, so golden ticks still match. Save version is 5.

## Frame cost and package size

The economy steps at `balance.tick_seconds` (0.25s). A frame only accumulates time, and a hitch runs at most 20 steps. One Python tick of the same rules is about 27 µs early and 34 µs with a joined path and a high rank (8,000 ticks). That sits far under the 0.25 s step. Hero and world textures import as VRAM-compressed (ETC2/ASTC). The 128px icon masters live in `assets/art/icons128/` and are excluded from the APK; the UI uses the 64px set. The export preset also leaves out `tools/`, `docs/`, `test/`, and `.github/`.

Measured debug APKs (`cbh-debug.apk` from the CI artifact, not the zip):

| Build | Bytes | |
|-------|------:|--|
| Before the art pack (settings commit `5847199`, run 42379062203) | 59,337,450 | 56.6 MiB |
| Art packed, lossless import (`6003e91`, run 43549492878) | 70,604,807 | 67.3 MiB |
| VRAM compression, 128px icons excluded (`f2ee273`, run 43549636896) | 67,885,781 | 64.7 MiB |

Compression and dropping the 128px masters cut about 2.7 MiB off the post-art package. The engine and Android template still dominate the APK.

## Worlds after the first ascension

Heavenly rites, void seals, and chaos attunements are bought with that world's resource and change pressure, dust, forge slots, or Qi. Breakthrough costs after an ascension use `ascension_cost_scale` and `ascension_later_scale`. See `docs/BALANCE_NOTES.md`.
