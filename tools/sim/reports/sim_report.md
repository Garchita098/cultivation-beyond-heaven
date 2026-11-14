# Simulation Report — Cultivation: Beyond Heaven (Stage 3)

**Best strategy (active):** `artifact_focused`

## Milestone times (best strategy)

| Milestone | Time |
|-----------|------|
| first_upgrade | 6.0s |
| first_breakthrough | 1.4m |
| rank:qi_early | 8.2m |
| rank:foundation_early | 22.1m |
| rank:foundation_late | 29.8m |
| rank:core_early | 35.9m |
| rank:core_peak | 45.6m |
| rebirth_unlocked | 45.6m |
| first_rebirth | 45.6m |
| rebirth:2 | 1.04h |
| rebirth:3 | 1.19h |
| rebirth:4 | 1.29h |
| rebirth:5 | 1.36h |
| talent_roll:unlock | 8.2m |
| artifact:jade_slip | 29.8m |
| rank:mortal_mid | 1.4m |
| rank:mortal_late | 2.9m |
| rank:mortal_peak | 5.4m |
| rank:qi_mid | 10.6m |
| rank:qi_late | 14.7m |
| rank:qi_peak | 18.5m |
| rank:foundation_mid | 25.4m |
| rank:foundation_peak | 32.7m |
| rank:core_mid | 39.0m |
| rank:core_late | 41.9m |

## Rebirth gaps

| Strategy | R1 | R2 | R3 | R4 | R5 | Walls | Longest wait |
|----------|----|----|----|----|----|-------|--------------|
| greedy_cheapest | — | — | — | — | — | 0 | 27.0s |
| best_roi | — | — | — | — | — | 0 | 7.2m |
| rush_breakthrough | — | — | — | — | — | 0 | 3.9m |
| rebirth_early | 45.9m | 17.5m | 8.9m | 6.2m | 4.6m | 0 | 17.5m |
| rebirth_late | 57.1m | 21.0m | 11.0m | 7.7m | 5.5m | 0 | 20.5m |
| talent_focused | 45.9m | 17.5m | 8.9m | 6.2m | 4.6m | 0 | 17.5m |
| artifact_focused | 45.6m | 17.0m | 8.7m | 6.0m | 4.5m | 0 | 17.0m |
| offline_heavy | 16.33h | 8.17h | 8.17h | 8.17h | 4.3m | 5 | 8.17h |

## Key milestones

| Strategy | First upgrade | First BT | Core Peak | First Rebirth | Rebirth 5 |
|----------|---------------|----------|-----------|---------------|-----------|
| greedy_cheapest | 6.0s | 3.7m | not reached | not reached | not reached |
| best_roi | 6.0s | 1.4m | 45.9m | not reached | not reached |
| rush_breakthrough | 6.0s | 1.6m | 49.7m | not reached | not reached |
| rebirth_early | 6.0s | 1.4m | 45.9m | 45.9m | 1.39h |
| rebirth_late | 6.0s | 1.4m | 45.9m | 57.1m | 1.70h |
| talent_focused | 6.0s | 1.4m | 45.9m | 45.9m | 1.39h |
| artifact_focused | 6.0s | 1.4m | 45.6m | 45.6m | 1.36h |
| offline_heavy | 6.0s | 1.4m | 16.33h | 16.33h | 40.91h |

## Pacing issues (artifact_focused)
- none

best_roi longest wait: 7.2m until `upgrade:meridian_opening:L96`

offline_heavy calendar to last recorded rebirth: 40.91h rebirths=5

## Stage 3 — time to first ascension

Active bots step once per second after the shared early game. First ascension enters the Spirit World.

| Strategy | Ascension | Rebirths | Bursts | Sacrifices | Absorbs | Speed windows | Compound hours |
|----------|-----------|----------|--------|------------|---------|---------------|----------------|
| path_heavenly_sword | 1.61h | 25 | 10 | 0 | 0 | 0 | 0.24 |
| path_demon_emperor | 1.47h | 25 | 0 | 22 | 0 | 0 | 0.10 |
| path_immortal | 1.68h | 25 | 0 | 0 | 0 | 0 | 0.30 |
| path_world_devourer | 1.57h | 25 | 0 | 0 | 22 | 0 | 0.19 |
| path_time_lord | 1.70h | 25 | 0 | 0 | 0 | 2 | 0.32 |
| mixed_switch | 1.64h | 25 | 6 | 0 | 0 | 1 | 0.17 |
| mixed_world | 2.39h | 25 | 0 | 0 | 0 | 0 | 0.73 |

Pure paths span 1.47h – 1.70h (spread 1.154, cap 1.25).

## World probes (7 minutes from Soul Transformation)

| World | Essence | Fragments | Dust | Seeds | Tribulations |
|-------|---------|-----------|------|-------|--------------|
| spirit_world | 7.379e+09 | 0 | 0 | 2 | 0 |
| heavenly_world | 9.616e+09 | 2.2 | 0 | 2 | 2 |
| void_dimension | 4.315e+09 | 0 | 3.512e+09 | 2 | 0 |
| chaos_origin | 3.847e+09 | 0 | 0 | 3 | 0 |

Notation supports exponent 1000000 (`1.23e1000000`). Live Qi keeps exponents past 300 instead of clamping at 1e300.

Stage 3 checks: none.
