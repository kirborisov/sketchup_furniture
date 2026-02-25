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

# === ИТОГИ ===

puts "\n" + "=" * 50
puts "РЕЗУЛЬТАТЫ: #{$tests_passed} пройдено, #{$tests_failed} провалено"
puts "=" * 50

exit($tests_failed > 0 ? 1 : 0)
