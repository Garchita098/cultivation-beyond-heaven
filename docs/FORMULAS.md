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

## 10. Детекция стен

Непрерывный интервал без покупки улучшения и без прорыва:

- early (`rank_index < 8`): ≥ 600 s
- mid (`< 20`): ≥ 1800 s
- late: ≥ 3600 s

Пороги — `balance.walls`.
