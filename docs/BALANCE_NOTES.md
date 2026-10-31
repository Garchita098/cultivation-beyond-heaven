# Balance notes (sim iteration)

## Accepted pacing (rebirth_early / best_roi, 2026-10-31)

| Milestone | Time |
|-----------|------|
| first_upgrade | 6.0s |
| first_breakthrough | 1.4m |
| qi_early | 8.1m |
| foundation_early | 22.3m |
| core_early | 41.9m |
| core_peak / first_rebirth | 59.0m |
| walls | 0 |

## Remaining soft issues

1. **best_roi longest gap ~27m** в mid (между крупными рангами при save-for-breakthrough) — под порогом 30m, но близко. Можно чуть снизить `core_early`/`foundation_peak` или дать мелкий flat upgrade mid-core.
2. **first_breakthrough ~1.4m** у лучшей стратегии чуть быстрее целевого окна 2–5m (у greedy ~3.7m). Приемлемо: «хороший» игрок быстрее.
3. **offline_heavy** до первого rebirth ~16h календарных — ожидаемо при 3 check-in/day без автопокупки; stage 2 automation должен это сгладить.
4. **mult_prod аддитивный пул** намеренно сдерживает взрыв; late-game рост опирается на rank_mult + rebirth karma + path rules, не на бесконечный Π(1+ev*L).
5. Stage 2–3 числа в JSON — черновики; после внедрения путей пересимулировать с path hooks.

## Как крутить

- Ранний пейсинг: `ranks.json` costs mortal_* / qi_*
- Rebirth timing: `core_*` costs + upgrade growth в `upgrades.json`
- Стены: смотреть `sim/reports/sim_report.json` → `walls`
