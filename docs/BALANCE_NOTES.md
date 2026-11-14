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

5. **Цены рангов stage 3 снижены.** Черновик (void 2e20 при множителе ×2 после души) был стеной. Кривая от void_early 4e13 идёт геометрически до beyond 2e23. Живой тик больше не обрезает Ци на 1e300: дальше значение хранится как мантисса и степень. Нотация сейва держит экспоненту 1e6.

## Stage 4 — after the first ascension (2026-11-07)

First-ascension times are unchanged (sword 1.61h, demon 1.47h, immortal 1.68h, devourer 1.57h, time lord 1.70h, spread 1.154). Post-ascension breakthrough costs are multiplied by `ascension_cost_scale` (2.2) per ascension already completed, and from the second ascension onward also by `ascension_later_scale` (140). Each ascension also adds `ascension_echo` (1.0, so +100% Qi per ascension).

Active bots, one decision per second, gaps measured after the first ascension:

| Path | 1st | 2nd | 3rd | Longest purchase gap after 1st |
|------|-----|-----|-----|--------------------------------|
| heavenly sword | 1.61h | 1.83h | 1.93h | 3.4m |
| demon emperor | 1.47h | 3.58h | 4.18h | 12.3m |
| world devourer | 1.57h | 3.64h | still in Heavenly at 4.2h | 11.2m |
| immortal | 1.68h | not within 4h | — | 12.8m |
| time lord | 1.70h | not within 4h | — | 14.1m |

Heavenly rites, void seals, and chaos attunements are bought from that world's resource. The sword clears Heavenly in a few minutes because bursts outrun the cost scale. The demon stays about 24 minutes and buys all four rites. Immortal and time lord are still on the spirit-world ladder at 4h; their longest gap stays under about 15 minutes. A 9h run at a harsher scale showed those two paths can sit on Integration / Mahayana for a long time, so the shipped scale keeps that gate crossable.

## Как крутить

- Ранний пейсинг: `ranks.json` costs mortal_* / qi_*
- Rebirth timing: `core_*` costs + upgrade growth в `upgrades.json`
- Стены: смотреть `sim/reports/sim_report.json` → `walls`
