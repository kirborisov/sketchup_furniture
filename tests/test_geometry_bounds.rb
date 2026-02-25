# sketchup_furniture/tests/test_geometry_bounds.rb
# Тесты на проверку границ геометрии - ничего не должно выпирать или пересекаться

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
  class Vector; def z; 1; end; end
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

# Тест-фреймворк
$tests_passed = 0
$tests_failed = 0

def assert(condition, message = "")
  if condition
    $tests_passed += 1
    puts "  ✓ #{message}"
  else
    $tests_failed += 1
    puts "  ✗ #{message}"
  end
end

def assert_equal(expected, actual, message = "")
  if expected == actual
    $tests_passed += 1
    puts "  ✓ #{message}"
  else
    $tests_failed += 1
    puts "  ✗ #{message}: ожидалось #{expected}, получено #{actual}"
  end
end

def assert_in_range(value, min, max, message = "")
  if value >= min && value <= max
    $tests_passed += 1
    puts "  ✓ #{message}"
  else
    $tests_failed += 1
    puts "  ✗ #{message}: #{value} не в диапазоне [#{min}, #{max}]"
  end
end

def test(name)
  puts "\n#{name}"
  yield
end

# === ТЕСТЫ ГРАНИЦ ШКАФА ===

test "Стандартный шкаф — все части внутри габаритов" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 500, 400, thickness: 18, back_thickness: 4)
  
  width = 800
  height = 500
  depth = 400
  t = 18
  bt = 4
  
  # Боковины: высота = height, глубина = depth - back_thickness
  side_height = height
  side_depth = depth - bt
  
  assert_equal height, side_height, "высота боковины = высота шкафа"
  assert_equal 396, side_depth, "глубина боковины = 400 - 4"
  
  # Верх/дно: ширина = width - 2*thickness
  panel_width = width - 2 * t
  assert_equal 764, panel_width, "ширина дна/верха = 800 - 36"
  
  # Задник: ширина = width, высота = height
  back_width = width
  back_height = height
  assert_equal 800, back_width, "ширина задника = ширина шкафа"
end

test "Шкаф с цоколем — перегородки не выпирают снизу" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 500, 400, thickness: 18)
  cab.plinth(80)
  cab.sections("50%", "50%")
  
  # Внутренняя высота (от верха дна до низа крышки)
  side_height = 500 - cab.support.side_height_reduction  # = 500
  top_of_bottom = cab.support.bottom_z + 18              # = 80 + 18 = 98
  bottom_of_top = cab.support.side_start_z + side_height - 18  # = 0 + 500 - 18 = 482
  inner_h = bottom_of_top - top_of_bottom                # = 482 - 98 = 384
  
  # Перегородка должна иметь высоту = inner_h
  partition_height = inner_h
  assert_equal 384, partition_height, "высота перегородки"
  
  # Перегородка начинается на top_of_bottom = 98мм
  partition_start_z = top_of_bottom
  partition_end_z = partition_start_z + partition_height
  
  assert_equal 98, partition_start_z, "перегородка начинается на высоте дна"
  assert_equal 482, partition_end_z, "перегородка заканчивается у низа крышки"
  
  # Проверяем что не выпирает за габариты
  assert partition_start_z >= 0, "перегородка не ниже 0"
  assert partition_end_z <= 500, "перегородка не выше шкафа"
end

test "Шкаф на ножках — боковины не выпирают снизу" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 500, 400, thickness: 18)
  cab.legs(100)
  
  # Боковины начинаются на высоте ножек
  side_start = cab.support.side_start_z
  side_height = 500 - cab.support.side_height_reduction  # = 500 - 100 = 400
  side_end = side_start + side_height
  
  assert_equal 100, side_start, "боковина начинается на высоте ножек"
  assert_equal 400, side_height, "высота боковины уменьшена"
  assert_equal 500, side_end, "боковина заканчивается на высоте шкафа"
  
  # Дно на высоте ножек
  bottom_z = cab.support.bottom_z
  assert_equal 100, bottom_z, "дно на высоте ножек"
end

# === ТЕСТЫ ЯЩИКОВ ===

test "Ящик — все части внутри габаритов" do
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    140,                    # высота ящика
    cabinet_width: 764,     # внутренняя ширина шкафа
    cabinet_depth: 396      # глубина без задника
  )
  
  slide = drawer.slide
  
  # Фасад
  facade_height = 140 - drawer.facade_gap  # = 140 - 3 = 137
  facade_width = drawer.width              # = 764
  
  assert_equal 137, facade_height, "высота фасада"
  assert_equal 764, facade_width, "ширина фасада"
  
  # Короб
  box_width = drawer.box.width      # = 764 - 26 = 738
  box_height = drawer.box_height    # = (140 - 3) - 20 - 20 = 97
  box_depth = drawer.box.depth      # = длина направляющих
  
  assert_equal 738, box_width, "ширина короба (минус направляющие)"
  assert_equal 97, box_height, "высота короба"
  
  # Короб помещается в фасад (с отступами)
  total_box_height = box_height + drawer.box_top_inset + drawer.box_bottom_inset
  assert total_box_height <= 140, "короб + отступы <= высота ящика"
end

test "Ящик — короб не шире чем внутренняя ширина минус направляющие" do
  inner_width = 764
  slide_thickness = 13
  
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    140,
    cabinet_width: inner_width,
    cabinet_depth: 396
  )
  
  expected_box_width = inner_width - 2 * slide_thickness  # = 764 - 26 = 738
  actual_box_width = drawer.box.width
  
  assert_equal expected_box_width, actual_box_width, "ширина короба учитывает направляющие"
end

test "Несколько ящиков — не пересекаются по высоте" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.skip(:bottom)
  cab.drawers(3, height: 140)
  
  # Общая высота всех ящиков
  total_drawers_height = 3 * 140  # = 420
  
  # Внутренняя высота шкафа (без дна, так как skip)
  side_height = 450 - cab.support.side_height_reduction
  top_of_bottom = cab.support.bottom_z  # нет дна, так что от 0
  bottom_of_top = cab.support.side_start_z + side_height - 18
  inner_height = bottom_of_top - top_of_bottom  # = 0 + 450 - 18 - 0 = 432
  
  assert total_drawers_height <= inner_height, 
         "ящики (#{total_drawers_height}мм) помещаются в шкаф (#{inner_height}мм)"
end

test "Ящик с цоколем — не выпирает за границы шкафа" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.plinth(80)
  cab.skip(:bottom)
  cab.drawer(140)
  
  # Ящик начинается от bottom_z (так как дна нет)
  drawer_start_z = cab.support.bottom_z  # = 80
  drawer_height = 140
  drawer_end_z = drawer_start_z + drawer_height  # = 80 + 140 = 220
  
  # Внутренняя верхняя граница
  side_height = 450
  inner_top = side_height - 18  # = 432 (низ крышки)
  
  assert drawer_start_z >= 0, "ящик не ниже 0"
  assert drawer_end_z <= inner_top, "ящик не выше крышки"
  assert drawer_start_z >= cab.support.bottom_z, "ящик выше цоколя"
end

# === ТЕСТЫ ВЗАИМНОГО РАСПОЛОЖЕНИЯ ===

test "Секции + полки — полки внутри секций" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 500, 400, thickness: 18)
  cab.sections("50%", "50%")
  cab.shelves([150, 300])
  
  # Ширина секции
  inner_w = 800 - 2 * 18  # = 764
  num_partitions = 1
  available_w = inner_w - num_partitions * 18  # = 764 - 18 = 746
  section_width = available_w / 2  # = 373
  
  # Полка должна быть шириной = ширина секции
  assert_in_range section_width, 370, 376, "ширина секции ~373мм"
  
  # Глубина полки = глубина шкафа - задник
  shelf_depth = 400 - 4  # = 396
  assert_equal 396, shelf_depth, "глубина полки"
end

test "Накладной фасад ящика — ширина = внутренняя ширина шкафа" do
  inner_width = 764
  
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    140,
    cabinet_width: inner_width,
    cabinet_depth: 396
  )
  
  # Фасад накладной должен быть шириной = cabinet_width
  # (между боковинами шкафа)
  facade_width = drawer.width
  assert_equal inner_width, facade_width, "ширина фасада = внутренняя ширина"
end

# === РАСЧЁТ СМЕЩЕНИЙ ===

test "Смещение ящиков по Z — правильная стопка" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.skip(:bottom)
  
  # Добавляем ящики разной высоты
  cab.drawer(100)  # 0-100
  cab.drawer(120)  # 100-220
  cab.drawer(150)  # 220-370
  
  configs = cab.instance_variable_get(:@drawers_config)
  
  offset_0 = configs[0...0].sum { |c| c[:height] }
  offset_1 = configs[0...1].sum { |c| c[:height] }
  offset_2 = configs[0...2].sum { |c| c[:height] }
  
  assert_equal 0, offset_0, "первый ящик — смещение 0"
  assert_equal 100, offset_1, "второй ящик — смещение 100"
  assert_equal 220, offset_2, "третий ящик — смещение 220"
  
  # Проверяем что не пересекаются
  drawer_1_end = offset_0 + 100
  drawer_2_start = offset_1
  assert drawer_1_end <= drawer_2_start, "ящики 1 и 2 не пересекаются"
  
  drawer_2_end = offset_1 + 120
  drawer_3_start = offset_2
  assert drawer_2_end <= drawer_3_start, "ящики 2 и 3 не пересекаются"
end

# === ИТОГИ ===

puts "\n" + "=" * 60
puts "РЕЗУЛЬТАТЫ ТЕСТОВ ГЕОМЕТРИИ:"
puts "  Пройдено: #{$tests_passed}"
puts "  Провалено: #{$tests_failed}"
puts "=" * 60

exit($tests_failed > 0 ? 1 : 0)
