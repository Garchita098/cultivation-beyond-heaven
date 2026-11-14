# TECH PLAN — Cultivation: Beyond Heaven

Godot **4.x**, GDScript, Android portrait **720×1280**.  
Репозиторий позже скаффолдит cloud agent из этого плана + `data/*.json` + `docs/*`.  
Сейчас: только `/workspace/cbh/`, без git/GitHub/внешних аккаунтов.

---

## 1. Архитектура Autoload

| Singleton | Ответственность |
|-----------|-----------------|
| `GameState` | Текущий рантайм: qi (BigNum), rank_index, upgrade_levels, karma, unlocks, path, world, timers |
| `BigNum` | mantissa+exponent; ops; format; to/from save string; защита от NaN/Inf |
| `Economy` | Формулы из `docs/FORMULAS.md`; production, costs, breakthrough, rebirth, path hooks |
| `SaveSystem` | serialize/deserialize; version; migrations; atomic write; autosave |
| `OfflineCalc` | closed-form или chunked; cap; выдаёт gained + лог событий |
| `Content` | Загрузка `res://data/*.json` (и опционально `.tres` обёртки); валидация schema_version |
| `EventBus` | Сигналы: `qi_changed`, `rank_up`, `rebirth_done`, `feature_unlocked` (UI подписка) |

Поток кадра:

```
_process(delta):
  GameState.tick(delta)           # копит время
  Economy.apply_production(...)   # qi += prod * delta * speed
  Automation.try_act(...)         # stage 2+
  SaveSystem.maybe_autosave()
```

Пауза приложения → `SaveSystem.save()` + timestamp; resume → `OfflineCalc.run()`.

---

## 2. Data-driven контент

Каталог (уже в репо-заготовке):

```
data/
  balance.json
  ranks.json
  upgrades.json
  rebirth.json
  worlds.json
  talents.json
  artifacts.json
  paths.json
  automation.json
```

- **SSOT** для сима (`sim/`) и игры.  
- Godot: копировать/symlink в `res://data/`.  
- Опционально `Content` генерирует `.tres` Resource на импорте для инспектора — не дублировать числа вручную.  
- `schema_version` в каждом файле; Content падает громко при несовместимости.

---

## 3. BigNum

**Канон:** `struct { float mantissa; int exponent }` (в GDScript — класс `BigNum`).

- Нормализация после каждой op
- Сравнение через выравнивание exponent
- Формат UI: K/M/B… затем scientific (`balance.bignum`)
- Сейв: строка (`"0"`, decimal, или `"1.23e45"`) — **не** сырой float
- Любой non-finite → `zero()` + `push_error`

Референс-логика: `sim/bignum.py`.

---

## 4. Save versioning + migration

```json
{
  "save_version": 1,
  "timestamp_unix": 0,
  "qi": "1.5e10",
  "lifetime_qi": "...",
  "rank_index": 12,
  "upgrade_levels": {"breath_meditation": 40},
  "karma_shards": "12",
  "rebirth_count": 1,
  "unlocked": ["rebirth_unlock"],
  "path_id": null,
  "world_id": "mortal_world",
  "meta": {}
}
```

- Файл: `user://save_v{N}.json` + `user://save_latest.json`
- Запись: temp → rename (atomic на Android)
- `SaveSystem.migrate(data, from_ver → CURRENT)`: цепочка функций `migrate_1_to_2`, …
- При поломке: backup `.bak`, не молча wipe

---

## 5. OfflineCalc

1. `absent = now - last_timestamp` clamp hard_cap
2. Если нет time-varying эффектов (burst/sacrifice active): closed-form из FORMULAS §6
3. Иначе: симуляция чанками `chunk_seconds` (макс. N чанков; дальше average)
4. UI: экран «Пока вас не было» с gained + кнопкой забрать (уже применено к state)

---

## 6. UI screen map (720×1280)

```
┌────────────────────────────┐  0..56   status: Qi | qi/s | rank short
│  [Qi big]  [qi/s]  [rank]  │
├────────────────────────────┤  56..980 content (tab body)
│                            │
│     TAB CONTENT AREA       │
│                            │
├────────────────────────────┤  980..1120 secondary action (breakthrough / rebirth)
│      PRIMARY CTA           │
├────────────────────────────┤  1120..1280 bottom nav (7 tabs, scrollable)
│ 🌱 ⬆ 🏅 ✨ 🗡 ♻️ 🔬        │
└────────────────────────────┘
```

| Tab id | RU | Stage |
|--------|-----|-------|
| `cultivation` | Культивация | 1 — силуэт, аура, ring progress to next rank |
| `upgrades` | Улучшения | 1 — список buy |
| `ranks` | Ранги | 1 — лестница, требования |
| `talents` | Таланты/техники | 2 — заглушка stage 1 |
| `artifacts` | Артефакты | 2 — заглушка |
| `rebirth` | Rebirth/Ascension | 2 — заглушка / preview at unlock |
| `research` | Исслед./авто | 2–3 — заглушка |

Навигация одним пальцем; CTA прорыва — крупная кнопка, не «тап ради Ци».

Сцены (предложение):

```
res://scenes/main.tscn          # shell + tab host
res://scenes/tabs/*.tscn
res://ui/components/BigNumLabel.tscn
res://ui/components/UpgradeRow.tscn
res://ui/theme/cbh_theme.tres
```

---

## 7. Структура проекта Godot (для cloud agent)

```
godot/
  project.godot
  autoload/*.gd
  scripts/economy/*.gd
  scripts/save/*.gd
  scenes/...
  data/          # копия JSON
  assets/...
  export_presets.cfg
  test/          # GUT или headless scripts
```

---

## 8. Headless test strategy

1. **Python SSOT sim** (уже есть): `python3 sim/run_sim.py` — пейсинг, стены, magnitude. CI step #1.
2. **Godot headless:** `godot4 --headless -s res://test/test_economy.gd`  
   - Загрузка JSON, сверка `production` с фикстурами из `sim/reports/golden_ticks.json` (сгенерировать из сима)
3. **GUT** (опционально): BigNum ops, save migrate, offline caps
4. **Screenshot tests:** Xvfb + godot windowed → `DisplayServer` capture или external `import`/`scrot`  
   ```
   Xvfb :99 -screen 0 720x1280x24 &
   export DISPLAY=:99
   godot4 --path . --resolution 720x1280
   # после загрузки сцены — скрипт делает Viewport.get_texture() save png
   ```
5. Порог: diff PNG через `perceptualdiff` / простой RMSE; только smoke для CI

Golden file: симулятор пишет `sim/reports/golden_ticks.json` (t, qi, prod, rank) для сверки GDScript.

---

## 9. GitHub Actions — Android APK

Не создавать репо сейчас; когда cloud agent поднимет GitHub:

```yaml
# .github/workflows/android.yml (черновик)
# - checkout
# - setup Godot 4.x + Android export templates
# - keytool -genkey ... debug.keystore (CI-only, secrets later for release)
# - godot --headless --export-debug "Android" build/cbh-debug.apk
# - run python sim/run_sim.py
# - upload APK artifact
# - optional: Xvfb screenshot job
```

Шаги:

1. Кэш Godot editor + export templates
2. `keytool -genkeypair -keystore debug.keystore -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=CBH CI"`
3. `export_presets.cfg`: package `com.cbh.cultivation`, portrait, minSdk 24
4. Artifact `cbh-debug.apk`
5. Job `economy-sim` на Python 3.11 без Godot — быстрый гейт баланса

---

## 10. Соответствие сима и игры

| Модуль Python | GDScript |
|---------------|----------|
| `sim/economy.py` | `Economy.gd` |
| `sim/bignum.py` | `BigNum.gd` |
| `sim/bots.py` | не в игре; только CI |
| `data/*.json` | `res://data/*.json` |

Любое изменение формулы — сначала `FORMULAS.md` + JSON + sim, потом порт в GDScript.

---

## 11. Stage 1 implementation checklist (для cloud agent)

- [ ] Godot project + autoloads stubs
- [ ] BigNum + Economy reading JSON
- [ ] Main UI 3 tabs + stubs
- [ ] Save/Load + OfflineCalc
- [ ] Headless production fixture test
- [ ] Android debug export preset
- [ ] Wire CI draft

Не трогать Living Dungeon / Akudama. Отдельный проект.
