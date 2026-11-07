# Stage 4 notes

Stage 1–3 notes still apply unless this file replaces them.

## Art pack was not in the workspace

The stage 4 brief asked to import `cbh_art.tar.gz` (heroes, five world backgrounds, 64/128 icons, `manifest.json`). That archive was not on disk when this branch was built: no `uploads/` copy, no `cbh_art/` tree, no contact sheet. This commit does not invent replacement illustrations and label them as that pack.

`scripts/art_bank.gd` loads the pack if it is dropped in later:

- `res://assets/art/hero/hero_path_*.webp` and `hero_rank_*.webp`
- `res://assets/art/bg/bg_{mortal,spirit,heavenly,void,chaos}.webp`
- `res://assets/art/icons/*_64.png`

Until those files exist, the game keeps the stage-1 silhouette shader, `bg_mortal_night.png`, and the existing tab and upgrade icons. World changes still tint that background (spirit jade, heavenly gold, void violet, chaos scarlet) and the cultivator card drifts a few pixels so the portrait is not a static block.

## Still to land on this branch

Achievements, statistics, the uncapped live tick, late-world balance, settings, and the export pass follow in later commits. Save version stays 4 until the achievement commit bumps it.
