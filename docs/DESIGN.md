# DESIGN — Cultivation: Beyond Heaven

Идентификаторы систем и полей данных — на английском; текст дизайна — на русском.  
Контент-числа живут только в `data/*.json` (единый источник правды для сима и игры).  
**Tap-to-earn запрещён:** Ци и ресурсы идут только автопроизводством / оффлайн-расчётом / механиками путей (жертва, time-skip — не клик за ресурс).

---

## 1. Core loop

1. Автопроизводство **Ци** (`qi`) каждую секунду.
2. Покупка **тренировок/улучшений** → рост `qi/s`.
3. Накопление Ци → **прорыв ранга** → новый множитель + unlock механик.
4. Достижение порога → **Rebirth** (Осколки Кармы) → постоянные бонусы, новые системы.
5. Глубже → выбор **Пути**, **Ascension** в новый мир со своим ресурсом и правилом.
6. Поздняя игра: **законы Дао / кузница правил** — меняют формулы, а не только множители.

Сессия: открыл → забрал оффлайн → купил/пробил/настроил автоматизацию → закрыл. Без спама тапов.

---

## 2. Лестница рангов (полная)

Каждый major-ранг (где применимо) имеет подступени: **Early / Mid / Late / Peak**.  
Полная таблица — `data/ranks.json` (поля `id`, `cost_qi`, `prod_mult`, `unlocks`, `stage`).

| # | Major (`major`) | RU | Типичный unlock |
|---|-----------------|----|-----------------|
| 0 | `mortal` | Смертный | Базовые улучшения |
| 1 | `qi_practitioner` | Практик Ци | Духовные корни / таланты |
| 2 | `foundation` | Основание | Техники; на Late — артефакты |
| 3 | `core_formation` | Золотое Ядро | Автопокупка; на Peak — Rebirth |
| 4 | `nascent_soul` | Душа Начала | Превью путей; Peak — Ascension в Spirit World |
| 5 | `soul_transformation` | Преображение Души | Усиление вторичных ресурсов |
| 6 | `void_refinement` | Очищение Пустоты | Законы Дао |
| 7 | `body_integration` | Слияние Тела | — |
| 8 | `mahayana` | Махаяна | Трибуляция |
| 9 | `immortal` | Бессмертный (Ascendant→Emperor) | Небесный мир |
| 10 | `heavenly` | Небесный Владыка | Авторитет Дао |
| 11 | `beyond` | Запредельное | Sovereign → Law Weaver → Reality Bender → Dao Embodiment → **Beyond Heaven** |

**Крупные прорывы (major) — что открывают**

| Major | Требование (вход Early/ключ) | Unlock |
|-------|------------------------------|--------|
| Практик Ци | `qi_early` | `spiritual_roots` |
| Основание | `foundation_early` | `techniques`; Late → `artifacts_basic` |
| Золотое Ядро | `core_early` | `automation_buy_upgrades`; Peak → `rebirth_unlock` |
| Душа Начала | `nascent_early` | `paths_preview`; Peak → Spirit World |
| Пустота | `void_early` | `dao_laws` |
| Бессмертный | `immortal_ascendant` | Heavenly World |
| Небесный | `heavenly_lord` | `dao_authority` |
| Beyond | `dimension_sovereign`+ | `reality_rules` → `law_rewrite` → `endgame_loop` |

Подступени между major дают `prod_mult` и ритм покупок без новой системы каждый раз.

---

## 3. Тренировки / улучшения

Список stage 1–3: `data/upgrades.json`.

Типы эффектов:

- `flat_prod` — плоский вклад в `(1 + flat_sum)`
- `mult_prod` — аддитивный пул `mult_add` → фактор `(1 + mult_add)`
- `speed_mult` — ускорение производства
- `cost_reduction` — скидка на стоимости (cap 80%)

Стоимость: `base_cost * growth^level * (1 - cost_red)`.  
Unlock привязан к `unlock_rank`.

---

## 4. Rebirth

- Валюта: **Karma Shards** (`karma_shards`) — `data/rebirth.json`
- Доступ: ранг `core_peak` (index 15)
- Формула награды — §5 в `FORMULAS.md`
- **Сбрасывается:** Ци, уровни улучшений, текущий ранг (с учётом start-rank boost), мирские ресурсы текущего забега
- **Сохраняется:** карма, счётчик rebirth, таланты, артефакты, путь, автоматизация, мир Ascension, research, купленное в karma shop

### Тиры Rebirth

| min_rebirths | RU | Unlock |
|--------------|----|--------|
| 1 | Первое перерождение | Karma shop; буст оффлайн-эфф. |
| 3 | Тройное колесо | Автопрорыв; реролл таланта |
| 5 | Пять путей | Выбор пути; базовый гача артефактов |
| 10 | Десять кругов | Авто-Rebirth; advanced shop; старт с более высокого ранга |
| 25 | Адепт Сансары | Врата Ascension; dual-resource gen |

`perm_mult_per_karma`: +5% к производству за осколок (аддитивно к 1.0).

---

## 5. Ascension и миры

Данные: `data/worlds.json`.

| Мир | Ресурс | Механика |
|-----|--------|----------|
| Mortal World | Ци | Классический idle |
| Spirit World | Духовная Сущность | Каналы: % производства в сущность → скидка прорывов |
| Heavenly World | Осколки Дао | Циклы трибуляции: давление → всплеск + краткая смена формулы |
| Void Dimension | Пыль Пустоты | Энтропия: неиспользованная Ци → пыль; пыль покупает rewrite одного правила |
| Chaos Origin | Семя Хаоса | Кузница Правил: сборка кастомной формулы на забег |

Каждый мир — не «ещё один множитель», а **другое решение** (распределение %, тайминг трибуляции, баланс энтропии, пресет законов).

---

## 6. Духовные корни и таланты

`data/talents.json`. Unlock: `qi_early`.

- Редкости: common → mythic (веса и диапазоны множителей в JSON)
- Корни-стихии: fire/water/wood/metal/earth/thunder/void
- До 3 экипированных; синергии (`synergy_with` + `synergy_bonus`)
- Апгрейд за карму: `cost_base * growth^level`, +0.02 к эффекту / уровень

---

## 7. Артефакты

`data/artifacts.json`. Unlock: `foundation_late`.

Пассивные эффекты, редкости, часть с `path_bonus` (сильнее на своём пути).  
Апгрейд за Ци; max_equipped = 4.

---

## 8. Пять путей (механики разные)

Unlock: rebirth ≥ 5. Данные: `data/paths.json`.

| Path ID | RU | Механика |
|---------|----|----------|
| `heavenly_sword` | Небесный Меч | **Burst cycles:** заряд → короткий xN всплеск; вне бурста слегка слабее |
| `demon_emperor` | Демонический Император | **Sacrifice:** сжечь % Ци/уровень ради бурста и перманентного прироста; без жертв штраф |
| `immortal` | Бессмертный | **Compound + offline:** медленный compound; лучший оффлайн (до 100% eff); слабее в коротких сессиях |
| `world_devourer` | Пожиратель Миров | **Absorb:** ест вторичные ресурсы → Ци + Devour Mult за разнообразие |
| `time_lord` | Владыка Времени | **Time manipulation:** chrono charge → time-skip / x2–x5 speed (не клик за ресурс) |

Путь качается своей валютой (`sword_intent`, `demon_blood`, …).

---

## 9. Автоматизация (порядок)

`data/automation.json`:

1. Автопокупка улучшений — `core_early`
2. Автопрорыв — rebirth ≥ 3
3. Автоэкипировка талантов — rebirth ≥ 5
4. Авто-Rebirth — rebirth ≥ 10
5. Авто-активация пути — path level ≥ 5
6. Автобаланс ресурсов мира — ascension ≥ 1
7. Авто-кузница правил — `law_weaver`

---

## 10. Оффлайн

- Базовая эффективность 75% (`balance.offline.efficiency`)
- Soft-cap 8 h (далее eff × 0.5), hard-cap 24 h
- Immortal path / karma shop повышают eff (cap 100%)
- Closed-form если производство стабильно; иначе chunked (`chunk_seconds`)

---

## 11. Late-game: смена правил (не только множители)

1. **Tribulation cycles** (Heavenly): периодическое давление; успех меняет формулу на окно (например flat→mult).
2. **Entropy drain** (Void): производство vs сгорание Ци в пыль — skill expression.
3. **Dao Laws / Rule Forge:** слоты правил (рост, стоимость, время, оффлайн). Игрок собирает билд формулы на забег.
4. **Law rewrite:** одно правило за пыль/семя — например «прорывы не тратят Ци, а тратят время» или «улучшения дают уровни пачками».
5. **Endgame loop (Beyond Heaven):** мета-слой поверх Ascension — престиж законов, коллекция пресетов.

---

## 12. План этапов (spec §7)

### Stage 1 — играбельная база (сейчас целимся сюда в данных + симе)
- Авто Ци, ранги Mortal→Core Peak, улучшения, сейвы, оффлайн-расчёт
- UI: вкладки Cultivation / Upgrades / Ranks (+ заглушки остальных)
- Контент: ranks+upgrades stage=1 в JSON

### Stage 2
- Rebirth + Karma shop, таланты, артефакты, автоматизация 1–4
- Ascension → Spirit World
- Черновики JSON уже в `data/` (stage: 2)

### Stage 3
- 5 путей, Heavenly/Void/Chaos миры, research, dao laws / rule forge
- JSON stage: 3

### Stage 4
- Арт-полировка, ачивки, статистика, глубокий баланс, оптимизация APK

---

## 13. Целевой пейсинг (active best strategy)

Проверено симом (`sim/reports/`):

| Веха | Цель | Факт (rebirth_early / best_roi) |
|------|------|----------------------------------|
| Первое улучшение | ≤ 15 s | ~6 s |
| Первый прорыв | ~2–5 min | ~1.4 min |
| Практик Ци | — | ~8 min |
| Основание | — | ~22 min |
| Ядро (early) | — | ~42 min |
| Первый Rebirth | ~30–60 min | ~59 min |
| Стены early/mid | ≤10 / ≤30 min | 0 стен |

Слабые стратегии (greedy) медленнее — это ок: учит ROI/прорывам.
