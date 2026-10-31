# Stage 3 deviations

Stage 1 and stage 2 notes still apply.

1. **Save version is 4.** `migrate_3_to_4` adds `stage3`, `dao_marks`, and `ascension_count`. A version-1 document still walks 1 → 2 → 3 → 4.

2. **Path mechanics start only after an explicit choice** (`path_joined`). A saved `path_id` from stage 2 still only scales a matching relic until the player (or a bot) joins the path. Joining is free the first time. Switching spends karma and wipes that path's nodes, currency, and permanents.

3. **Stage cap is 3.** Ranks through Beyond Heaven are on the ladder. Stage 3 breakthrough costs in `ranks.json` were lowered from the draft (1e20 and up). Those drafts were a wall, not a climb. See `docs/BALANCE_NOTES.md`.

4. **The live economy is float64, capped at 1e300.** BigNum saves and the UI formatter still round-trip an exponent of 1,000,000 (`1.23e1000000`). Past the cap, Qi clamps instead of becoming NaN.

5. **Ascension into the Void** treats `unlock_requirement.min` as the ascension count *after* the transition, so the third ascension can enter. Spirit still requires Nascent Peak and 25 rebirths. Heavenly still requires Immortal Ascendant. Chaos still requires Law Weaver. Void and Chaos are a playable first layer (entropy retain, one rewrite, two forge slots), not the full endgame loop.

6. **Hook relic effects become real rules once that path is joined.** Until then they stay the stage 2 partial multiplier. `rule_slot` adds a law slot instead of a multiplier.

7. **Research is a timer queue** unlocked with the five paths (rebirth 5). It runs online and inside offline chunks. It does not spend taps.

8. **Path bots in the sim step once per second.** Golden ticks stay on the 0.25s stage-2 clock and still match.
