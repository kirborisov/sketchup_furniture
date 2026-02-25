# sketchup_furniture/tests/test_drawers.rb
# Тесты для ящиков

# Мок SketchUp API
module Sketchup
  def self.active_model; Model.new; end
  class Model
    def start_operation(*args); end
    def commit_operation; end
    def active_entities; Entities.new; end
  end
  class Entities
    def add_group; Group.new; end
    def add_face(*args); Face.new; end
    def add_dimension_linear(*args); nil; end
  end
  class Group
    attr_accessor :name
    def entities; Sketchup::Entities.new; end
    def transform!(*args); end
  end
  class Face
    def normal; Vector.new; end
    def pushpull(*args); end
  end
  class Vector; def z; 1; end; def y; 0; end; end
end

module Geom
  class Vector3d
    def initialize(*args); end
  end
  class Transformation
    def self.translation(v); new; end
    def initialize; end
  end
end

# Загружаем библиотеку
Dir.chdir(File.dirname(__FILE__) + '/..')
load 'sketchup_furniture.rb'

# Простой тест-фреймворк
$tests_passed = 0
$tests_failed = 0

def assert_equal(expected, actual, message = "")
  if expected == actual
    $tests_passed += 1
    puts "  ✓ #{message}"
  else
    $tests_failed += 1
    puts "  ✗ #{message}"
    puts "    Ожидалось: #{expected}"
    puts "    Получено: #{actual}"
  end
end

def assert(condition, message = "")
  if condition
    $tests_passed += 1
    puts "  ✓ #{message}"
  else
    $tests_failed += 1
    puts "  ✗ #{message}"
  end
end

def test(name)
  puts "\n#{name}"
  yield
end

# === ТЕСТЫ НАПРАВЛЯЮЩИХ ===

test "BallBearingSlide — параметры по умолчанию" do
  slide = SketchupFurniture::Components::Drawers::Slides::BallBearing.new(length: 400)
  
  assert_equal 400, slide.length, "длина"
  assert_equal 35, slide.height, "высота профиля"
  assert_equal 13, slide.thickness, "толщина на сторону"
  assert_equal 26, slide.width_reduction, "уменьшение ширины ящика"
  assert_equal :full, slide.extension, "полное выдвижение"
  assert_equal 25, slide.load_capacity, "нагрузка"
end

test "BallBearingSlide — подбор длины для глубины шкафа" do
  # Глубина 400мм → длина 350мм (400 - 50 = 350)
  slide = SketchupFurniture::Components::Drawers::Slides::BallBearing.for_depth(400)
  assert_equal 350, slide.length, "длина для глубины 400мм"
  
  # Глубина 500мм → длина 450мм
  slide2 = SketchupFurniture::Components::Drawers::Slides::BallBearing.for_depth(500)
  assert_equal 450, slide2.length, "длина для глубины 500мм"
end

test "BallBearingSlide — мягкое закрывание" do
  slide = SketchupFurniture::Components::Drawers::Slides::BallBearing.new(length: 400, soft_close: true)
  assert slide.soft_close?, "soft_close включён"
  assert slide.hardware_name.include?("плавное"), "название содержит 'плавное'"
end

# === ТЕСТЫ КОРОБА ===

test "DrawerBox — размеры" do
  box = SketchupFurniture::Components::Drawers::DrawerBox.new(738, 100, 350)
  
  assert_equal 738, box.width, "ширина"
  assert_equal 100, box.height, "высота"
  assert_equal 350, box.depth, "глубина"
  assert_equal 10, box.box_thickness, "толщина стенок (фанера)"
  assert_equal 4, box.bottom_thickness, "толщина дна (ДВП)"
  
  # Внутренние размеры
  assert_equal 718, box.inner_width, "внутренняя ширина (738 - 2×10)"
  assert_equal 330, box.inner_depth, "внутренняя глубина (350 - 2×10)"
end

# === ТЕСТЫ ЯЩИКА ===

test "Drawer — расчёт размеров короба" do
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    150,                    # высота ящика
    cabinet_width: 764,     # внутренняя ширина шкафа
    cabinet_depth: 400      # глубина шкафа
  )
  
  # Ширина короба = внутр.ширина - 2×толщина_направляющей
  # 764 - 26 = 738
  assert_equal 738, drawer.box.width, "ширина короба"
  
  # Глубина короба = длина направляющей (350мм для глубины 400)
  # 350 (направляющая) - 20 (back_gap) = 330
  assert_equal 330, drawer.box.depth, "глубина короба"
  
  # Высота короба = высота_ящика - высота_направляющей - зазор
  # 150 - 35 - 3 = 112
  assert_equal 112, drawer.box_height, "высота короба"
end

# === ТЕСТЫ CABINET С ЯЩИКАМИ ===

test "Cabinet — добавление ящиков" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawer(150)
  cab.drawer(150)
  cab.drawer(100)
  
  assert_equal 3, cab.instance_variable_get(:@drawers_config).length, "количество ящиков"
end

test "Cabinet — drawers (несколько одинаковых)" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawers(4, height: 100)
  
  assert_equal 4, cab.instance_variable_get(:@drawers_config).length, "количество ящиков"
  cab.instance_variable_get(:@drawers_config).each do |cfg|
    assert_equal 100, cfg[:height], "высота каждого ящика"
  end
end

test "Cabinet — drawer с параметрами" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400)
  cab.drawer(150, slide: :ball_bearing, soft_close: true, draw_slides: true)
  
  cfg = cab.instance_variable_get(:@drawers_config).first
  assert_equal :ball_bearing, cfg[:slide], "тип направляющих"
  assert cfg[:soft_close], "плавное закрывание"
  assert cfg[:draw_slides], "рисовать направляющие"
end

# === ТЕСТЫ DRAWER_ROW ===

test "Cabinet — drawer_row: конфигурация ряда" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 382
    drawer 382
  end
  
  rows = cab.instance_variable_get(:@drawer_rows_config)
  assert_equal 1, rows.length, "количество рядов"
  assert_equal 150, rows[0][:height], "высота ряда"
  assert_equal 2, rows[0][:drawers].length, "количество ящиков в ряду"
  assert_equal 382, rows[0][:drawers][0][:width], "ширина первого ящика"
  assert_equal 382, rows[0][:drawers][1][:width], "ширина второго ящика"
end

test "Cabinet — drawer_row: несколько рядов" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 600, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 382
    drawer 382
  end
  cab.drawer_row(height: 200) do
    drawer 764  # на всю ширину
  end
  
  rows = cab.instance_variable_get(:@drawer_rows_config)
  assert_equal 2, rows.length, "количество рядов"
  assert_equal 2, rows[0][:drawers].length, "ящиков в 1 ряду"
  assert_equal 1, rows[1][:drawers].length, "ящиков во 2 ряду"
  assert_equal 764, rows[1][:drawers][0][:width], "ширина единственного ящика"
end

test "Cabinet — drawer_row: параметры наследуются от ряда" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawer_row(height: 150, soft_close: true, back_gap: 30) do
    drawer 382
    drawer 382
  end
  
  rows = cab.instance_variable_get(:@drawer_rows_config)
  assert rows[0][:drawers][0][:soft_close], "soft_close наследуется"
  assert_equal 30, rows[0][:drawers][0][:back_gap], "back_gap наследуется"
  assert rows[0][:drawers][1][:soft_close], "soft_close наследуется (2)"
end

test "Cabinet — drawer_row: параметры ящика переопределяют ряд" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawer_row(height: 150, soft_close: false) do
    drawer 382, soft_close: true
    drawer 382
  end
  
  rows = cab.instance_variable_get(:@drawer_rows_config)
  assert rows[0][:drawers][0][:soft_close], "1-й ящик: soft_close переопределён"
  assert !rows[0][:drawers][1][:soft_close], "2-й ящик: soft_close от ряда"
end

test "Cabinet — drawer_row: построение создаёт объекты" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 382
    drawer 382
  end
  cab.build
  
  assert_equal 2, cab.drawer_objects.length, "создано 2 объекта ящиков"
end

test "Cabinet — drawer_row: три ящика в ряд" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(900, 450, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 288
    drawer 288
    drawer 288
  end
  
  rows = cab.instance_variable_get(:@drawer_rows_config)
  assert_equal 3, rows[0][:drawers].length, "3 ящика в ряду"
end

test "Cabinet — drawer_row: можно комбинировать с обычными drawers" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 600, 400, name: "Комод")
  # Обычные ящики
  cab.drawers(2, height: 150)
  # Ряд ящиков
  cab.drawer_row(height: 150) do
    drawer 382
    drawer 382
  end
  
  config = cab.instance_variable_get(:@drawers_config)
  rows = cab.instance_variable_get(:@drawer_rows_config)
  assert_equal 2, config.length, "2 обычных ящика"
  assert_equal 1, rows.length, "1 ряд ящиков"
end

test "Cabinet — drawer_row: cut items и hardware генерируются" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 382
    drawer 382
  end
  cab.build
  
  cuts = cab.all_cut_items
  facade_cuts = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 2, facade_cuts.length, "2 фасада в раскрое"
  
  hw = cab.all_hardware_items
  slides = hw.select { |h| h.name.include?("Направляющая") }
  assert_equal 2, slides.length, "2 комплекта направляющих"
end

# === ТЕСТЫ ПЕРЕГОРОДКИ И ПОЛКИ ===

test "Cabinet — drawer_row: перегородки в раскрое (2 ящика)" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 373
    drawer 373
  end
  cab.build
  
  cuts = cab.all_cut_items
  partitions = cuts.select { |c| c.name.include?("Перегородка ящиков") }
  assert_equal 1, partitions.length, "1 перегородка между 2 ящиками"
  # CutItem: length >= width, поэтому 396 > 150
  assert_equal 150, partitions[0].width, "высота перегородки = высота ряда"
end

test "Cabinet — drawer_row: перегородки (3 ящика в ряд)" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(900, 450, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 252
    drawer 252
    drawer 252
  end
  cab.build
  
  cuts = cab.all_cut_items
  partitions = cuts.select { |c| c.name.include?("Перегородка ящиков") }
  assert_equal 2, partitions.length, "2 перегородки между 3 ящиками"
end

test "Cabinet — drawer_row: горизонтальная полка между рядами" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 600, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 373
    drawer 373
  end
  cab.drawer_row(height: 200) do
    drawer 764
  end
  cab.build
  
  cuts = cab.all_cut_items
  shelves = cuts.select { |c| c.name.include?("Полка ящиков") }
  assert_equal 1, shelves.length, "1 полка между 2 рядами"
end

test "Cabinet — drawer_row: нет полки если один ряд" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 373
    drawer 373
  end
  cab.build
  
  cuts = cab.all_cut_items
  shelves = cuts.select { |c| c.name.include?("Полка ящиков") }
  assert_equal 0, shelves.length, "нет полок если 1 ряд"
end

test "Cabinet — drawer_row: 3 ряда = 2 полки" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 800, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 373
    drawer 373
  end
  cab.drawer_row(height: 150) do
    drawer 764
  end
  cab.drawer_row(height: 150) do
    drawer 373
    drawer 373
  end
  cab.build
  
  cuts = cab.all_cut_items
  shelves = cuts.select { |c| c.name.include?("Полка ящиков") }
  assert_equal 2, shelves.length, "2 полки между 3 рядами"
end

test "Cabinet — drawer_row: нет перегородки если 1 ящик на ряд" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawer_row(height: 200) do
    drawer 764
  end
  cab.build
  
  cuts = cab.all_cut_items
  partitions = cuts.select { |c| c.name.include?("Перегородка ящиков") }
  assert_equal 0, partitions.length, "нет перегородок для 1 ящика"
end

# === ТЕСТЫ COUNT ===

test "Cabinet — drawer_row: count автоматически делит ширину" do
  # inner_w = 800 - 2*18 = 764
  # 2 ящика, 1 перегородка = 764 - 18 = 746, по 373 каждый
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод", thickness: 18)
  cab.drawer_row(height: 150, count: 2)
  
  rows = cab.instance_variable_get(:@drawer_rows_config)
  # resolve happens at build time, so build first
  cab.build
  
  assert_equal 2, cab.drawer_objects.length, "создано 2 ящика"
end

test "Cabinet — drawer_row: count: 3 создаёт 3 ящика + 2 перегородки" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(900, 450, 400, name: "Комод", thickness: 18)
  cab.drawer_row(height: 150, count: 3)
  cab.build
  
  assert_equal 3, cab.drawer_objects.length, "3 ящика"
  
  cuts = cab.all_cut_items
  partitions = cuts.select { |c| c.name.include?("Перегородка ящиков") }
  assert_equal 2, partitions.length, "2 перегородки"
end

test "Cabinet — drawer_row: count ширина ящиков = (inner_w - перегородки) / count" do
  # inner_w = 800 - 2*18 = 764
  # count: 2, 1 partition = 764 - 18 = 746, drawer_w = 373
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод", thickness: 18)
  cab.drawer_row(height: 150, count: 2)
  cab.build
  
  rows = cab.instance_variable_get(:@drawer_rows_config)
  assert_equal 373, rows[0][:drawers][0][:width], "ширина ящика = 373"
  assert_equal 373, rows[0][:drawers][1][:width], "ширина ящика = 373"
end

# === ТЕСТЫ ПОЛКА НАД ПОСЛЕДНИМ РЯДОМ ===

test "Cabinet — drawer_row: полка над последним рядом если нет верха (stretchers)" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.stretchers  # skip(:top)
  cab.drawer_row(height: 150, count: 2)
  cab.build
  
  cuts = cab.all_cut_items
  shelves = cuts.select { |c| c.name.include?("Полка ящиков") }
  assert_equal 1, shelves.length, "полка над последним рядом (нет верха)"
end

test "Cabinet — drawer_row: нет доп полки если есть верхняя панель" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  # top не пропущен — есть верхняя панель
  cab.drawer_row(height: 150, count: 2)
  cab.build
  
  cuts = cab.all_cut_items
  shelves = cuts.select { |c| c.name.include?("Полка ящиков") }
  assert_equal 0, shelves.length, "нет доп полки — есть верхняя панель"
end

test "Cabinet — drawer_row: нет доп полки если 1 ящик без верха" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.stretchers
  cab.drawer_row(height: 150, count: 1)
  cab.build
  
  cuts = cab.all_cut_items
  shelves = cuts.select { |c| c.name.include?("Полка ящиков") }
  assert_equal 0, shelves.length, "нет полки — 1 ящик, нет перегородок"
end

# === ТЕСТЫ SMART PANELS ===

test "Cabinet — drawer_row: нет полки между рядами из одного ящика" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 600, 400, name: "Комод")
  cab.drawer_row(height: 150) do
    drawer 764
  end
  cab.drawer_row(height: 200) do
    drawer 764
  end
  cab.build
  
  cuts = cab.all_cut_items
  shelves = cuts.select { |c| c.name.include?("Полка ящиков") }
  assert_equal 0, shelves.length, "нет полки — оба ряда по 1 ящику"
end

test "Cabinet — drawer_row: полка если один ряд с перегородкой" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 600, 400, name: "Комод")
  cab.drawer_row(height: 150, count: 2)
  cab.drawer_row(height: 200) do
    drawer 764
  end
  cab.build
  
  cuts = cab.all_cut_items
  shelves = cuts.select { |c| c.name.include?("Полка ящиков") }
  assert_equal 1, shelves.length, "полка — верхний ряд с перегородками"
end

# === ТЕСТЫ FACADE_GAP ===

test "Config — facade_gap по умолчанию 3" do
  cfg = SketchupFurniture::Core::Config.new
  assert_equal 3, cfg.facade_gap, "facade_gap = 3"
end

test "Config — facade_gap можно менять" do
  old = SketchupFurniture.config.facade_gap
  SketchupFurniture.config.facade_gap = 5
  assert_equal 5, SketchupFurniture.config.facade_gap, "facade_gap = 5"
  SketchupFurniture.config.facade_gap = old
end

# === ТЕСТЫ FACADE РАЗМЕРЫ ===

test "Cabinet — drawer_row: фасад шире колонки (покрывает перегородку)" do
  # inner_w = 800 - 2*18 = 764
  # 2 ящика, column_w = (764-18)/2 = 373
  # facade_w = (764 - 3) / 2 = 380.5 → 381 + 380
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод", thickness: 18)
  cab.drawer_row(height: 150, count: 2)
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 2, facades.length, "2 фасада"
  
  # Оба фасада шире 373 (покрывают перегородку)
  facades.each do |f|
    fw = [f.length, f.width].max
    assert fw > 373, "фасад (#{fw}) шире колонки (373)"
  end
  
  # Сумма фасадов + зазор = inner_w
  widths = facades.map { |f| [f.length, f.width].max }
  assert_equal 764, widths.sum + 3, "фасады + зазор = inner_w"
end

test "Cabinet — drawer_row: фасад покрывает горизонтальную полку" do
  # 2 ряда: 150 + 18 (полка) + 200 = 368
  # total_facade_h = 368 - 2*3 = 362
  # facade_h[0] = round(150/350 * 362) = 155
  # facade_h[1] = 362 - 155 = 207
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 600, 400, name: "Комод", thickness: 18)
  cab.drawer_row(height: 150, count: 2)
  cab.drawer_row(height: 200) do
    drawer 764
  end
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  
  # Фасад нижнего ряда выше 147 (150-3) — покрывает полку
  row0_facades = facades[0..1]
  row0_fh = [row0_facades[0].length, row0_facades[0].width].min
  assert row0_fh > 147, "фасад ряда 1 (#{row0_fh}) выше 147 — покрывает полку"
  
  # Фасад верхнего ряда выше 197 (200-3) — покрывает полку
  row1_facade = facades[2]
  row1_fh = [row1_facade.length, row1_facade.width].min
  assert row1_fh > 197, "фасад ряда 2 (#{row1_fh}) выше 197 — покрывает полку"
end

test "Cabinet — drawer_row: 1 ящик — фасад = inner_w" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод", thickness: 18)
  cab.drawer_row(height: 150) do
    drawer 764
  end
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 1, facades.length, "1 фасад"
  
  fw = [facades[0].length, facades[0].width].max
  assert_equal 764, fw, "фасад = inner_w (нет перегородок)"
end

# === ТЕСТЫ FACADE_GAP FALLBACK ===

test "Drawer — facade_gap берётся из конфига" do
  old = SketchupFurniture.config.facade_gap
  SketchupFurniture.config.facade_gap = 5
  
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    150, cabinet_width: 764, cabinet_depth: 400
  )
  assert_equal 5, drawer.facade_gap, "facade_gap из конфига"
  # box_height = 150 - 35 - 5 = 110
  assert_equal 110, drawer.box_height, "box_height с facade_gap=5"
  
  SketchupFurniture.config.facade_gap = old
end

test "Drawer — facade_gap можно передать явно" do
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    150, cabinet_width: 764, cabinet_depth: 400, facade_gap: 4
  )
  assert_equal 4, drawer.facade_gap, "facade_gap явный"
  # box_height = 150 - 35 - 4 = 111
  assert_equal 111, drawer.box_height, "box_height с facade_gap=4"
end

test "Drawer — facade_gap fallback если конфиг nil" do
  old = SketchupFurniture.config.facade_gap
  SketchupFurniture.config.facade_gap = nil
  
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    150, cabinet_width: 764, cabinet_depth: 400
  )
  assert_equal 3, drawer.facade_gap, "facade_gap fallback = 3"
  assert_equal 112, drawer.box_height, "box_height с fallback"
  
  SketchupFurniture.config.facade_gap = old
end

# === ТЕСТЫ ОБЫЧНЫХ DRAWERS С FACADE_GAP ===

test "Cabinet — обычные drawers строятся (не nil)" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawers(2, height: 150)
  cab.build
  
  assert_equal 2, cab.drawer_objects.length, "2 ящика создано"
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 2, facades.length, "2 фасада"
end

test "Cabinet — drawers по позициям строятся" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, name: "Комод")
  cab.drawers([0, 150, 350])
  cab.build
  
  assert_equal 3, cab.drawer_objects.length, "3 ящика по позициям"
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 3, facades.length, "3 фасада"
end

test "Cabinet — смешанные drawers + drawer_row строятся" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 700, 400, name: "Комод")
  cab.drawers(2, height: 100)
  cab.drawer_row(height: 150, count: 2)
  cab.build
  
  assert_equal 4, cab.drawer_objects.length, "4 ящика (2 обычных + 2 в ряду)"
end

# === ИТОГИ ===

puts "\n" + "=" * 50
puts "РЕЗУЛЬТАТЫ: #{$tests_passed} пройдено, #{$tests_failed} провалено"
puts "=" * 50

exit($tests_failed > 0 ? 1 : 0)
