## Мебельный конструктор SketchUp — полный DSL по построению

Этот файл — **краткий, но полный справочник по DSL**, который используется для построения шкафов, гардеробов и кухонь.  
Он собран **на основе кода** (`Wardrobe`, `Kitchen`, `Column`, `Cabinet` и пр.), чтобы отразить **все доступные возможности при построении**.

---

## 1. Общий подход к построению

- **Гардероб / шкаф**: `Wardrobe.new "Имя", depth: 400, thickness: 18 do ... end.build`
- **Кухня**: `Kitchen.new "Имя" do ... end.build`

После `.build` всегда доступны:

- **`summary`** — сводка
- **`print_cut_list`** — раскрой
- **`print_hardware_list`** — фурнитура
- **`show_dimensions(mode)` / `hide_dimensions`** — размеры
- **`activate_drawer_tool`** — двойной клик по ящикам/дверям
- **`open_all_drawers` / `close_all_drawers`** и работа с отдельными ящиками

---

## 1.1. Кухня из YAML (рекомендуемый рабочий процесс)

Вместо Ruby DSL можно редактировать **YAML-файл** и обновлять модель кнопкой:

1. Редактируй `examples/kitchen.yaml` (ширины, высоты, наполнение шкафов).
2. В SketchUp: **Plugins → Мебель: Обновить из YAML** — кухня пересоберётся из файла.
3. Для другого файла: **Plugins → Мебель: Открыть YAML...** — выбрать файл и обновить.

Путь по умолчанию можно задать в консоли:
```ruby
SketchupFurniture::UI::Menu.project_path = "путь/к/kitchen.yaml"
```

Схема YAML см. в `examples/kitchen.yaml`.

---

## 2. Wardrobe — гардероб / шкаф

```ruby
Wardrobe.new(name = "Шкаф", depth: 400, thickness: 18) do
  column 900 do
    base 450, name: "Тумба" do
      # ... содержимое шкафа ...
    end

    cabinet 1450, name: "Одежда" do
      # ...
    end

    top 800, name: "Антресоль", shelf: 400
  end
end.build
```

- **Конструктор**
  - `name` — имя шкафа
  - `depth` — общая глубина
  - `thickness` — толщина корпуса (ЛДСП)

- **DSL внутри `Wardrobe`**
  - `column(width, name: nil) { ... }` — добавить колонну шириной `width`
    - Внутри колонны используется DSL `Column` (см. ниже).

- **Методы после `.build`**
  - `build(context = nil)` — построить модель
  - `summary`
  - `print_cut_list`
  - `print_hardware_list`
  - **Размеры**:
    - `show_dimensions(mode = :overview)` — `:off`, `:overview`, `:sections`, `:detailed`
    - `hide_dimensions`
    - `dimensions_mode`
  - **Ящики**:
    - `activate_drawer_tool` — двойной клик
    - `all_drawers` — массив всех ящиков
    - `open_all_drawers(amount: nil)`
    - `close_all_drawers`
    - `open_drawer(column_idx, module_idx = 0, drawer_idx = 0, amount: nil)`
    - `close_drawer(column_idx, module_idx = 0, drawer_idx = 0)`

---

## 3. Kitchen — кухня (нижний/верхний ряд + столешница)

```ruby
Kitchen.new "Кухня" do
  lower depth: 560, height: 820 do
    plinth 100                # или legs 100
    cabinet 600, name: "Мойка" do
      # ...
    end
  end

  upper depth: 300, height: 600, at: 1400 do
    cabinet 600, name: "Сушка" do
      # ...
    end
  end

  countertop 38, overhang: 30
end.build
```

- **Конструктор**
  - `Kitchen.new(name = "Кухня")`

- **Нижний ряд**
  - `lower(depth: 560, height: 720) { ... }`
    - `depth` — глубина нижних шкафов
    - `height` — высота **вместе с опорой**
    - Внутри `lower`:
      - `plinth(height, **options)` — цоколь по умолчанию
      - `legs(height, **options)` — ножки по умолчанию
      - `cabinet(width, name: nil, height: nil, **options) { ... }` — шкаф, DSL как у `Cabinet`
        - `width` — ширина модуля
        - `height` — **опциональная** высота именно этого шкафа (если не указана — берётся высота ряда `lower`)

- **Верхний ряд**
  - `upper(depth: 300, height: 600, at: 1400) { ... }`
    - `depth` — глубина верхних шкафов
    - `height` — высота верхних шкафов
    - `at` — высота низа верхнего ряда от пола
    - Внутри `upper`:
      - `cabinet(width, name: nil, height: nil, **options) { ... }`
        - `height` — при указании переопределяет высоту только этого верхнего шкафа

- **Столешница**
  - `countertop(thickness = 38, overhang: 30, depth: nil)`
    - `thickness` — толщина
    - `overhang` — свес спереди
    - `depth` — полная глубина (если не указана — `lower_depth + overhang`)

- **После `.build`**
  - `summary` — габариты, количество нижних/верхних шкафов, толщина столешницы, возможный размер фартука
  - `print_cut_list`
  - `print_hardware_list`
  - `show_dimensions(mode = :overview)`, `hide_dimensions`, `dimensions_mode`
  - `activate_drawer_tool`, `all_drawers`, `open_all_drawers`, `close_all_drawers`
  - **`rebuild_cabinet(name)`** — пересобрать один шкаф по имени без пересборки всей кухни:
    - находит группу шкафа в модели по `name`
    - удаляет её
    - строит новый шкаф с текущими параметрами DSL в той же позиции
    - остальная кухня и ручные правки не затрагиваются
    - Пример: `$kitchen.rebuild_cabinet("Шкаф 5, ящики")` — после изменения DSL для этого шкафа

---

## 4. Column — вертикальная колонна

Используется внутри `Wardrobe`.

```ruby
column 900, name: "Левая" do
  base 450, name: "Тумба" do
    # ...
  end

  cabinet 1450, name: "Одежда" do
    # ...
  end

  top 800, name: "Антресоль", shelf: 400
end
```

- **Методы DSL**
  - `base(height, name: nil, **options) { ... }`
    - Напольный шкаф (с опорой), DSL как у `Cabinet`
  - `cabinet(height, name: nil, **options) { ... }`
    - Обычный шкаф, DSL как у `Cabinet`
  - `top(height, name: nil, shelf: nil, **options)`
    - Антресоль; опционально сразу добавляет полку `shelf(z)`

---

## 5. Cabinet — центральный DSL (содержимое шкафа)

`Cabinet` используется:

- внутри `Column` (`base`, `cabinet`, `top`)
- внутри `Kitchen.lower` / `Kitchen.upper` (`cabinet`)

```ruby
cabinet 600, name: "Шкаф" do
  # Опора
  plinth 80, front_panel: true
  # или
  legs 100, count: 6

  # Секции и полки
  sections "50%", "50%"
  shelf 300
  shelves [300, 600, 900]

  # Ящики
  drawer 150
  drawers 3, height: 140

  # Двери
  doors 2, type: :frame
end
```

### 5.1 Пропуск частей корпуса

Доступные части: `:bottom`, `:top`, `:back`, `:left_side`, `:right_side`

```ruby
skip :bottom          # без дна
skip :back            # без задней стенки
skip :top             # без верха
skip :left_side       # без левой боковины
skip :right_side      # без правой боковины

skip :bottom, :back   # несколько сразу
```

### 5.2 Полки и секции

- **Полка**
  - `shelf(z_position, adjustable: true)`
    - `z_position` — высота от низа шкафа (внутри)
    - `adjustable` — фиксированная или регулировочная

- **Несколько полок**
  - `shelves(*positions)` — массив высот, например `shelves [300, 600, 900]`

- **Разделительная полка над ящиками**

```ruby
separator_shelf   # автоматически ставит полку над вертикальной колонкой ящиков
                  # удобно для схемы «ящик снизу, дверь сверху»
```

- **Вертикальные секции**

```ruby
sections "50%", "50%"        # проценты
sections "30%", "70%"
sections "33%", "34%", "33%"

sections 400, 400, 328       # абсолютные ширины (мм)
```

При изменении ширины колонны процентные секции пересчитываются автоматически.

### 5.3 Ящики

**Одиночный ящик**

```ruby
drawer 150                      # высота 150мм
drawer 200, slide: :ball_bearing, soft_close: true
drawer 150, type: :frame        # рамочный фасад
```

**Несколько одинаковых ящиков**

```ruby
drawers 4, height: 140
drawers 4, height: 140, slide: :ball_bearing
```

**Ящики по явным высотам (позиции Z)**  
Если передать массив, то интерпретируется как список позиций:

```ruby
drawers [0, 150, 350],
        slide: :ball_bearing,
        type: :frame,
        box_top_inset: 20,
        box_bottom_inset: 20
```

**Основные опции ящика / группы ящиков**

- `height` — высота фасада (для одиночных/группы)
- `slide` — тип направляющих (`:ball_bearing` и др.)
- `soft_close` — плавное закрывание
- `draw_slides` — рисовать направляющие
- `back_gap` — зазор до задней стенки
- `box_top_inset` / `box_bottom_inset` — отступы короба от фасада
- `type` — `:solid` или `:frame`
- `frame_width`, `frame_thickness`, `tenon`, `panel_gap`,
  `panel_thickness`, `groove_depth` — параметры рамочного фасада

### 5.4 Ряд ящиков (горизонтально)

```ruby
drawer_row height: 150, count: 2

# Высота по всей внутренней высоте шкафа (height не указан)
drawer_row count: 2

drawer_row height: 150 do
  drawer 400   # явная ширина левого
  drawer 346   # правого
end
```

- `height` — высота ряда
- `count` — количество ящиков с автоматическим делением по ширине  
  (если не задан, ширины задаются через вложенные `drawer width`)
- если `height` не указан и ряд один — он занимает **всю внутреннюю высоту** шкафа
- Наследуемые опции (как у `drawers`):  
  `slide`, `soft_close`, `draw_slides`, `back_gap`,  
  `box_top_inset`, `box_bottom_inset`,  
  `type`, `frame_width`, `frame_thickness`, `tenon`,  
  `panel_gap`, `panel_thickness`, `groove_depth`

Между ящиками автоматически добавляются перегородки и полки между рядами (если есть перегородки).

### 5.5 Двери и глухая панель

**Двери**

```ruby
doors 1                          # одна сплошная дверь
doors 2                          # две створки
doors 1, facade_material: :mdf_19
doors 2, type: :frame, frame_width: 40

# Двери над выдвижными ящиками в том же шкафу
doors 1, over_drawers: true
```

- `count` — 1 или 2
- опции те же, что и у фасадов:
  - `type` (`:solid` / `:frame`)
  - `facade_material`
  - `frame_width`, `frame_thickness`, `tenon`,
    `panel_gap`, `panel_thickness`, `groove_depth`
  - `over_drawers` — если `true`, двери строятся **над** вертикальной колонкой ящиков
    в этом же `cabinet` (нижняя часть — выдвижные, верхняя — дверца/дверцы).

Петли и направление открывания рассчитываются автоматически.

**Глухая панель**

```ruby
blind_panel side: :left, width: 100, facade_material: :ldsp_16
```

- `side` — `:left` или `:right`
- `width` — ширина панели (если `nil`, вычисляется)
- `facade_material` — материал панели

Глухая панель создаёт нерухомую фасадную часть без петель (например, как боковую заглушку рядом с дверями).

### 5.6 Опоры (тип опоры шкафа)

По умолчанию шкаф стоит **на боковинах** (`SidesSupport`).

- **Цоколь**

```ruby
plinth 80
plinth 80, front_panel: true   # с цокольной планкой спереди
```

- **Ножки**

```ruby
legs 100                       # автоматический расчёт количества
legs 100, count: 6, adjustable: true
```

- **Стойка на боковинах (стандарт)**

```ruby
on_sides                       # явное указание
```

- **Царги**

```ruby
stretchers                     # стандартные (горизонтальные элементы)
stretchers :sink, width: 80    # под мойку — на ребро
```

При использовании `stretchers` верхняя крышка (`:top`) автоматически пропускается.

---

## 6. Глобальная конфигурация фасадов

Через модуль `SketchupFurniture.config` можно глобально настроить параметры фасадов:

```ruby
SketchupFurniture.config.facade_gap = 3        # зазор между фасадами (мм)
SketchupFurniture.config.frame_thickness = 20  # толщина рамочного фасада
SketchupFurniture.config.drawer_row_overlay = true  # фасады рядов прикрывают дно/верх
```

Доступны, в частности:

- `facade_gap` — зазор между фасадами ящиков/дверей
- `frame_thickness` — толщина рамочного фасада по умолчанию
- `drawer_row_overlay` — если `true`, фасады рядов ящиков (`drawer_row`) растягиваются по фасадной зоне корпуса и прикрывают дно и верх с зазором `facade_gap/2` (по умолчанию `false`)

---

## 7. Результаты и отчёты

Для объектов `Wardrobe` и `Kitchen`:

- **Сводка**

```ruby
wardrobe.summary
```

- **Таблица раскроя**

```ruby
wardrobe.print_cut_list
```

- **Фурнитура**

```ruby
wardrobe.print_hardware_list
```

Аналогичные методы есть у `Kitchen`.

---

## 8. Краткий чек‑лист при построении

- **1.** Выбрать тип:
  - `Wardrobe.new ...` — колонны, шкафы, антресоли
  - `Kitchen.new ...` — нижний/верхний ряд, столешница
- **2.** Внутри задать модули:
  - `column`, `base`, `cabinet`, `top` (для Wardrobe/Column)
  - `lower`, `upper`, `cabinet`, `countertop` (для Kitchen)
- **3.** Внутри каждого шкафа (`cabinet`/`base`/`top`) настроить:
  - опору: `plinth`, `legs`, `on_sides`, `stretchers`
  - внутренности: `sections`, `shelf` / `shelves`
  - ящики: `drawer`, `drawers`, `drawer_row`
  - двери и панели: `doors`, `blind_panel`
  - пропуски: `skip :bottom, :back, ...`
- **4.** Вызвать:
  - `.build`
  - затем по необходимости `.summary`, `.print_cut_list`, `.print_hardware_list`, `.show_dimensions`, `.activate_drawer_tool`, `.open_all_drawers` и т.д.

Этот файл можно использовать как **шпаргалку по DSL**: все ключевые методы сгруппированы по уровням (`Wardrobe` / `Kitchen` → `Column` → `Cabinet`) и соответствуют реальному коду библиотеки.

