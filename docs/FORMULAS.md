# FORMULAS — Cultivation: Beyond Heaven

Единый источник формул для `sim/` и Godot `Economy.gd`. Идентификаторы — English; числа — из `data/*.json`.

## 1. Большие числа (BigNum)

Пара `(mantissa: float, exponent: int)`, `value = mantissa * 10^exponent`, нормализация `1.0 <= |mantissa| < 10.0` (ноль: `(0, 0)`).

Сейв: строка `"0"`, десятичная при `|exponent| < 15`, иначе `"<mantissa>e<exponent>"` (см. `sim/bignum.py`).

Запрещены `NaN` / `±Inf` — clamp к `0` + лог ошибки.

### Форматирование UI

- `exponent < 3`: число с 0–2 знаками
- `3 <= exponent < 33`: суффиксы K/M/B/T/Qa/Qi/Sx/Sp/Oc
- `exponent >= 33`: `X.YYeZ`

## 2. Производство Ци (ядро stage 1)

```
flat_sum   = Σ (effect_value * level)     # effect_type == flat_prod
mult_add   = Σ (effect_value * level)     # effect_type == mult_prod
mult_factor= 1 + mult_add
speed_mult = 1 + Σ (effect_value * level) # effect_type == speed_mult
cost_red   = min(0.8, Σ effect_value*level) # cost_reduction

rank_mult  = ranks[current_rank].prod_mult          # абсолютный
karma_mult = 1 + karma_shards * perm_mult_per_karma
path_mult  = 1.0  # до выбора пути; см. §7
talent_mult= 1.0  # Π экипированных + синергии
artifact_mult = 1.0

qi_per_sec = base_qi_per_sec
           * (1 + flat_sum)
           * mult_factor
           * rank_mult
           * karma_mult
           * rebirth_shop_mult
           * path_mult
           * talent_mult
           * artifact_mult
           * speed_mult
```

`base_qi_per_sec` из `balance.json` (по умолчанию `1.0`).

**Строго нет tap-to-earn.**

## 3. Стоимость улучшения

```
raw_cost(level) = base_cost * growth^level
cost(level)     = raw_cost(level) * (1 - cost_red)
```

## 4. Прорыв ранга

```
breakthrough_cost = next_rank.cost_qi * (1 - breakthrough_discount)
```

`prod_mult` в JSON — абсолютный множитель текущего ранга (кривая уже кумулятивная).

## 5. Rebirth → Karma Shards

Условие: `rank_index >= min_rank_index_to_rebirth` (core_peak = 15).

```
karma_gain = floor(
    base
  + log10(max(1, lifetime_qi)) / from_lifetime_qi_log10_div
  + highest_rank_index * from_highest_rank_index
)
```

Persist / reset — `data/rebirth.json`.

## 6. Оффлайн

```
eff = min(1.0, offline.efficiency + bonuses)
absent = min(absent_sec, hard_cap_hours * 3600)
if absent <= soft_cap_hours * 3600:
    gained = qi_per_sec * absent * eff
else:
    gained = qi_per_sec * soft * eff
           + qi_per_sec * (absent - soft) * eff * 0.5
```

Burst-пути / демонические жертвы: chunked sim шагом `chunk_seconds`.

## 7. Пути (path_mult)

| Path | Правило |
|------|---------|
| heavenly_sword | Вне бурста `outside_burst_mult`; в бурсте `burst_mult_base + level * per_level` |
| demon_emperor | Без жертвы `idle_penalty_mult`; после жертвы — burst + permanent_gain |
| immortal | `active_play_mult * (1+rate)^hours`; бонус offline_efficiency |
| world_devourer | `1 + min(cap, types_absorbed * per_type)` + конвертация ресурсов |
| time_lord | Не прямой mult; time-skip / speed_mult поверх `qi_per_sec` |

Параметры — `data/paths.json`.

## 8. Ascension / миры

Spirit World: `essence_ratio ∈ [0,1]` делит сырой прирост; скидка прорыва `min(cap, essence * discount_per)`.

## 9. ROI (боты / автопокупка)

```
d_prod = production(level+1) - production(level)
roi    = d_prod / cost(level)
payback_sec = cost / d_prod
```

## 10. Stage 2 — таланты, артефакты, лавка, оффлайн с автоматизацией

Числа только из JSON. `path_mult` остаётся `1` до Stage 3. `path_id` уже включает синергию корня и `path_match_effect_scale` артефакта.

```
talent_value = roll + level * effect_gain_per_level
```

Экипированные корни (до `max_equipped`) входят в формулу §2 по своему `effect_type`. `mult_prod` перемножается. Синергия стихий (`element_synergies`) — дополнительный множитель. Синергия `synergy_with` срабатывает, только если тег есть у выбранного `path_id`.

Артефакт: `ev = effect_value * (1 + effect_gain_fraction * level)`, и `ev *= path_match_effect_scale`, если путь совпал. Эффекты путей без механики (`sacrifice_efficiency`, `absorb_rate`, `time_skip_charge`, `rule_slot`) дают `artifact_mult *= (1 + ev * stage2_hook_as_mult)`.

Лавка кармы:

```
cost(level) = max(1, floor(cost * growth^level))
shop_mult   = 1 + karma_prod_1.level * value
```

`karma_mult` считается от **непотраченных** осколков. Покупка, которая снижает производство, не совершается.

Ролл корня детерминированный (`cbh_unit`, один и тот же в симе и в Godot): один раз на `qi_early`, один раз на каждый `milestone_ranks`, и один на каждое перерождение. Пустой слот заполняется сам. Реликвии выпадают по `drop_order` на `foundation_late` и на перерождении (`grant_per_rebirth`, с 5-го — `grant_per_rebirth_after_gacha`).

Оффлайн: если включены автопокупка, автопрорыв или авто-rebirth, расчёт идёт чанками `chunk_seconds` с теми же решениями, что и в бою. Иначе — closed-form §6.

## 11. Детекция стен

Непрерывный интервал без покупки улучшения и без прорыва:

- early (`rank_index < 8`): ≥ 600 s
- mid (`< 20`): ≥ 1800 s
- late: ≥ 3600 s

Пороги — `balance.walls`.

## 12. Stage 3 — пути, миры, исследования, вознесение

Пока путь не выбран (`path_joined` ложь), мир смертный, нет законов и знаков Дао, производство и цены совпадают с §2–§10.

```
qi_per_sec = stage2_prod * path_mult * speed_window * law_rewrite * dao_mark_mult * qi_keep
dao_mark_mult = 1 + dao_marks * perm_mult_per_mark
qi_keep = 1 - essence_ratio          # только Spirit World, ratio ∈ {0, 0.25, 0.5, 0.75}
```

| Path | path_mult |
|------|-----------|
| heavenly_sword | вне всплеска `outside_burst_mult`; во всплеске `burst_mult_base + level * per_level + узлы`. Узел «Кромка» на время всплеска домножает на `(1 + flat_sum * value)` |
| demon_emperor | без жертвы `idle_penalty * (1+permanent)`; после жертвы `1+permanent`; в окне жертвы `sacrifice_burst_mult * (1+permanent)`. Жертва сжигает долю Ци. Узел «Цена ранга» ещё снимает 1 подступень ранга |
| immortal | `active_play_mult * (1+rate)^(starting_hours + cultivated_hours)`. Оффлайн-часы копят часы быстрее. Эффективность оффлайна +`offline_efficiency_bonus`, потолок `offline_efficiency_cap` |
| world_devourer | `1 + min(cap-1, types * per_type) + devour_bonus`. Тип — поглощённое улучшение, реликвия или ресурс мира |
| time_lord | прямой mult = 1. Окно скорости `speed_mult_value` на `speed_mult_duration_sec` за заряд. Time-skip тратит накопленные оффлайн-секунды (`bank_ratio` от отсутствия), не тап |

Законы Дао (слот, не множитель «ещё ×k»):

- `flat_power`: `(1+mult_add)` становится `(1+mult_add)^(1+value)`
- `growth_exp`: цена `base * growth^(level * value)`
- `time_log`: производство `* (1 + value * log10(1+hours))`, прорыв `* 1.2`
- `bonus_level_every`: каждая N-я покупка даёт ещё уровень
- `breakthrough_half_if_bank`: прорыв стоит половину Ци и списывает банк времени

Режимы реальности (ранг Слияния Тела, `reality_stitch`):

- dilated: производство `* dilated_prod`, цены `* dilated_cost`, часы `* dilated_time`
- inverted: `(1+flat)*(1+mult)` заменяется на `(1+flat)*exp(min(cap, mult*coeff))`

Миры: Spirit делит поток. Heavenly раз в `tribulation_interval_sec` сравнивает `log10(prod) + rank * weight` с давлением; успех открывает окно, где flat дополнительно входит множителем. Void срезает Ци выше `prod * retain_seconds` в пыль. Chaos копит семена и открывает слоты кузницы.

Вознесение (rebirth ≥ 25 и ранг входа следующего мира) обнуляет Ци, тренировки, ранг, карму и лавку. Путь, корни, реликвии и исследования остаются. Награда — Знаки Дао. Оффлайн с путём или миром считается чанками. Живая экономика — float64 с потолком `balance.magnitude_cap` (1e300). Запись BigNum держит экспоненту до `notation_max_exponent` (1e6).
