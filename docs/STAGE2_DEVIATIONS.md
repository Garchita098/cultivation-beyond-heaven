# Stage 2 deviations

Stage 1 notes in `docs/STAGE1_DEVIATIONS.md` still apply. These are the stage 2 choices.

1. **Save version is 3.** Stage 1 already shipped version 2. `migrate_1_to_2` is unchanged; `migrate_2_to_3` adds talents, artifacts, shop levels, automation toggles, and reveal flags. A version-1 document still walks 1 → 2 → 3.

2. **Paths and Ascension are hooks.** Rebirth 5 shows the five paths and stores nothing until Stage 3. `path_id` is saved and already scales a matching relic and root synergy, but the game never sets it. Rebirth 25 shows the Ascension gate. Spirit World is not playable.

3. **Element synergies were added to `talents.json`.** The file's `synergy_with` tags point at path currencies, which do not exist yet. Pairs of elements give a multiplier now so equipping roots matters before paths.

4. **Path-only relic effects are a partial multiplier.** `sacrifice_efficiency`, `absorb_rate`, `time_skip_charge`, and `rule_slot` contribute `stage2_hook_as_mult` (0.5) of their value to production until those paths exist. Stage 3 artifacts are not in the drop list.

5. **Drops are a fixed order, not a gacha spinner.** One relic on Foundation Late, then one per rebirth, two per rebirth from the fifth. Duplicates raise the lowest level. Empty equip slots fill themselves. There is no tap to roll.

6. **Karma shop spending is refused when it would lower Qi/s.** Unspent shards are still the +5% multiplier. The automation and the sim bots share that check.

7. **Stage cap is 2** (through Soul Transformation Peak). The Python sim uses the same cap, so golden ticks include it.

8. **Nascent and soul breakthrough costs were retuned.** The draft values (1e16 and up) were a wall, not a stage-2 climb. See `docs/BALANCE_NOTES.md`.
