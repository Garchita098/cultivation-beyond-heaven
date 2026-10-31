# Cultivation: Beyond Heaven

Portrait Android idle cultivation game: Qi gathers on its own, with ranks, breakthroughs, and offline progress.

Stage 2 adds rebirth, karma, spiritual roots, artifacts, and automation. There is no tap-to-earn. Qi per second comes from rank, trainings, karma, roots, and relics. Design notes are in `docs/`. Balance numbers live only in `data/*.json`.

## Play

Open the repo in Godot 4.7 and run the main scene (`720×1280`, portrait). Tabs: Cultivation, Upgrades, Ranks, Roots, Artifacts, Karma, Automation. A tab stays quiet until its rank or rebirth tier, then a short reveal opens it. Rebirth asks for confirmation. Paths and Ascension are visible hooks only.

## Economy sim

```bash
python3 tools/sim/check_golden.py
python3 tools/sim/run_sim.py
```

The simulator reads `data/` at the repo root. Reports go to `tools/sim/reports/`.

## Headless tests

```bash
CBH_TEST=1 godot4 --headless --path . -s res://test/run_tests.gd
```

Covers BigNum format and save strings, save migration, offline gains versus simulated ticks, and parity with `tools/sim/reports/golden_ticks.json`.

## Screenshots and Android

```bash
# Xvfb on :99 at 720x1280, then:
godot4 --path . --display-driver x11 --audio-driver Dummy --rendering-driver opengl3 \
  -- --screenshots /tmp/cbh-shots
godot4 --headless --path . --export-debug "Android" build/cbh-debug.apk
```

CI (`.github/workflows/ci.yml`) runs the sim, the headless tests, the seven tab screenshots, and a debug APK signed with a throwaway keystore. Package id `com.cbh.cultivation`, minSdk 24.

Architecture differences from `docs/TECH_PLAN.md` are listed in `docs/STAGE1_DEVIATIONS.md`.
