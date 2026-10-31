# Economy simulator

Читает `../data/*.json`, реализует `../docs/FORMULAS.md`, гоняет ботов:

- `greedy_cheapest`
- `best_roi` (гибрид: прорыв + короткий payback)
- `rush_breakthrough`
- `rebirth_early` / `rebirth_late`
- `talent_focused` / `artifact_focused`
- `offline_heavy` (3 check-in/day: 10m active + 8h offline, automation runs while away)

```bash
python3 tools/sim/run_sim.py
# or: cd tools/sim && python3 run_sim.py
```

Reads `data/*.json` at the repo root (`../../data` from this folder). Reports land in `tools/sim/reports/`.
