# ART DIRECTION — Cultivation: Beyond Heaven

Тёмное восточное фэнтези: духовная энергия, нефрит, золото трибуляции, фиолетовая пустота. Лёгкая графика (2D UI + силуэты + glow), без тяжёлого 3D.

## Палитра (hex)

| Роль | Hex | Заметка |
|------|-----|---------|
| Фон глубокий | `#0B0E17` | основной canvas |
| Фон панели | `#141A2A` | карточки |
| Обводка | `#1E2A44` | тонкие рамки |
| Ци (primary) | `#5CE1FF` | энергия, прогресс |
| Нефрит | `#3DDBA0` | успех, подтверждение |
| Золото небес | `#F0C75E` | прорывы, rare |
| Фиолет Дао | `#A78BFA` | таланты, пути |
| Демон. алый | `#E85D5D` | жертва, danger |
| Текст primary | `#E8EEF8` | заголовки |
| Текст muted | `#8B97B0` | вторичный |
| Glow Ци | `#5CE1FF80` | 50% alpha |
| Glow золото | `#F0C75E66` | прорыв |

## UI-стиль

- Вертикальный портрет **720×1280** (logical); safe area top/bottom.
- Карточки с мягким glow по краю активного ресурса.
- Круговой/дуговой progress ring вокруг силуэта культиватора на вкладке Cultivation.
- Иконки: line-art + одноцветная заливка энергии; размер тач-цели ≥ 48 dp.
- Шрифт: геометрический гротеск для чисел (BigNum), слегка «каллиграфический» для заголовков рангов (без нечитаемой декоративности).
- Анимации: пульсация ауры 2–4 s loop; вспышка при прорыве; без particle hell.

## Ассеты stage 1 (обязательные)

1. `bg_mortal_night.png` — тёмный горный храм / луна / туман
2. `cultivator_silhouette.png` — медитирующий силуэт (базовый)
3. Aura states (overlay / modulate):
   - `aura_mortal.png` (тусклый серо-голубой)
   - `aura_qi.png` (яркая Ци)
   - `aura_foundation.png` (нефрит)
   - `aura_core.png` (золотое ядро)
4. Иконки ресурсов: `icon_qi.png`
5. Иконки улучшений (8–11 шт. stage 1): breath, body, meridian, spirit_sense, qi_sea, foundation_pill, core_flame, swift_circulation, insight_scroll
6. Иконки вкладок (7): cultivation, upgrades, ranks, talents, artifacts, rebirth, research
7. UI chrome: panel_9slice, button_jade, button_gold, progress_fill, breakthrough_flash
8. Символ/лого: `symbol_dao_circle.png` (простой круг Дао)

## Prompt templates (image generator)

Общий суффикс: `dark eastern fantasy, cultivation xianxia, spiritual energy, celestial symbols, UI game asset, clean readable silhouette, soft glow, no text, no watermark, vertical composition`

**Background:**
`ancient mountain temple under violet night sky, jade mist, distant moon, dark eastern fantasy, cultivation xianxia, spiritual energy, soft glow, no text, no watermark, vertical 9:16`

**Cultivator:**
`silhouette of meditating cultivator lotus position, flowing robe, calm posture, dark eastern fantasy, soft cyan spiritual aura, clean readable silhouette, no face detail, no text, game UI asset`

**Aura Qi:**
`abstract spiritual energy aura ring, cyan and white particles, soft glow, transparent background, game VFX overlay, no text`

**Aura Core:**
`golden core energy aura, molten gold and white, celestial symbols faintly, soft glow, transparent background, game VFX overlay, no text`

**Icon Qi:**
`simple icon of swirling qi energy orb, cyan jade, flat game icon, soft glow, centered, transparent background, no text`

**Upgrade icon (generic):**
`flat game icon, [SUBJECT], jade and gold on dark, soft glow, centered, transparent background, no text, cultivation xianxia`

Подставлять SUBJECT: `breath meditation swirl`, `tempered body fist`, `open meridians diagram`, `spirit eye`, `qi sea wave`, `alchemy pill`, `core flame`, `circulation arrows`, `insight scroll`.

## Stage 2+ (черновик)

- Отдельные фоны Spirit / Heavenly world
- Иконки талантов по стихиям, артефакты, символы 5 путей
- VFX burst (Heavenly Sword), sacrifice (Demon), chrono sand (Time Lord)
