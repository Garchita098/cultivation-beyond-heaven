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

## Stage 2 pacing (2026-10-31, after rebirth / talents / artifacts)

`rebirth_early` gaps: **45.9m, 17.5m, 8.9m, 6.2m, 4.6m**. First rebirth stays inside 45–60m. Each of the next four runs is shorter. `best_roi` longest wait is **10.3m** (was ~27m) until a deep `breath_meditation` level; no early/mid wall. `offline_heavy` (10m active + 8h offline, 3×/day) reaches rebirth 5 at **~41h** calendar time.

What moved the 27m pause: lower `foundation_peak` / `core_*` costs, `meridian_opening` growth 1.22 → 1.20, and `foundation_mantra` (flat, from Foundation Mid) so a save-up has something to buy. Nascent and soul costs were draft-scale (1e16+); they are now a stage-2 climb instead of a multi-hour wall. Re-sim after paths.

`talent_focused` matches `rebirth_early`: a karma shard in the shop beats +0.02 on a root, so the bot refuses upgrades that cut production. `artifact_focused` is a little faster (45.6m first rebirth) because relic levels spend Qi.

## Remaining soft issues

1. **first_breakthrough ~1.4m** у лучшей стратегии чуть быстрее целевого окна 2–5m (у greedy ~3.7m). Приемлемо: «хороший» игрок быстрее.
2. **offline_heavy** делает примерно одно перерождение за визит, пока нет авто-rebirth (оно с 10-го). Пять перерождений укладываются в ~2 суток, не в одни.
3. **mult_prod аддитивный пул** намеренно сдерживает взрыв; late-game рост опирается на rank_mult + rebirth karma + path rules, не на бесконечный Π(1+ev*L).
4. Пути и миры включены в Stage 3. Первое вознесение (Духовный мир) у чистых путей: **1.47h–1.71h**, разброс **1.161** (порог 1.25). Меч бьёт всплесками, демон жертвует Ци, бессмертный копит часы, пожиратель ест типы, время открывает окна скорости. Смешанный мир (сущность 50%) медленнее: 2.44h. Стены на этих прогонах не вылезли за поздний порог.

5. **Цены рангов stage 3 снижены.** Черновик (void 2e20 при множителе ×2 после души) был стеной. Кривая от void_early 4e13 идёт геометрически до beyond 2e23. Потолок живой экономики — 1e300 (float64). Нотация сейва держит экспоненту 1e6.

## Как крутить

- Ранний пейсинг: `ranks.json` costs mortal_* / qi_*
- Rebirth timing: `core_*` costs + upgrade growth в `upgrades.json`
- Стены: смотреть `sim/reports/sim_report.json` → `walls`
