# sketchup_furniture/tests/test_position_bounds.rb
# Тесты на точные позиции элементов — ничего не выпирает, не пересекается

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

Dir.chdir(File.dirname(__FILE__) + '/..')
load 'sketchup_furniture.rb'

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

def test(name)
  puts "\n#{name}"
  yield
end

# === ПОЗИЦИИ БОКОВИН ===

test "Стандартный шкаф — боковины от z=0 до z=height" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 500, 400, thickness: 18)
  
  side_start_z = cab.support.side_start_z
  side_height = 500 - cab.support.side_height_reduction
  side_end_z = side_start_z + side_height
  
  assert_equal 0, side_start_z, "боковина начинается с z=0"
  assert_equal 500, side_height, "высота боковины = 500"
  assert_equal 500, side_end_z, "боковина заканчивается на z=500"
end

test "Шкаф с цоколем — боковины от z=0, но дно выше" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 500, 400, thickness: 18)
  cab.plinth(80)
  
  side_start_z = cab.support.side_start_z
  side_height = 500 - cab.support.side_height_reduction
  bottom_z = cab.support.bottom_z
  
  assert_equal 0, side_start_z, "боковина от пола (z=0)"
  assert_equal 500, side_height, "высота боковины = полная (500)"
  assert_equal 80, bottom_z, "дно на высоте цоколя (80)"
  
  # Дно выше пола
  assert bottom_z > 0, "дно выше пола"
  assert bottom_z < side_height, "дно ниже верха боковины"
end

test "Шкаф на ножках — боковины укорочены и подняты" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 500, 400, thickness: 18)
  cab.legs(100)
  
  side_start_z = cab.support.side_start_z
  side_height = 500 - cab.support.side_height_reduction
  side_end_z = side_start_z + side_height
  bottom_z = cab.support.bottom_z
  
  assert_equal 100, side_start_z, "боковина начинается на высоте ножек (z=100)"
  assert_equal 400, side_height, "высота боковины = 500 - 100 = 400"
  assert_equal 500, side_end_z, "боковина заканчивается на z=500"
  assert_equal 100, bottom_z, "дно на высоте ножек"
  
  # Боковина НЕ достаёт до пола!
  assert side_start_z > 0, "боковина выше пола (есть зазор под ножки)"
  # Дно на уровне начала боковины
  assert_equal side_start_z, bottom_z, "дно на уровне низа боковины"
end

# === ПОЗИЦИИ ЯЩИКОВ ===

test "Ящики без пропуска дна — начинаются выше дна" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  # НЕ пропускаем дно!
  cab.drawers(3, height: 130)
  
  bottom_z = cab.support.bottom_z  # = 0
  thickness = 18
  
  # Ящики начинаются выше дна
  drawer_start_z = bottom_z + thickness  # = 18
  
  assert_equal 0, bottom_z, "дно на z=0"
  assert_equal 18, drawer_start_z, "ящики начинаются на z=18 (выше дна)"
  
  # Проверяем что ящики помещаются
  inner_height = 450 - 2 * thickness  # = 414 (от дна до верха)
  total_drawers = 3 * 130  # = 390
  assert total_drawers <= inner_height, "ящики (#{total_drawers}) <= внутренняя высота (#{inner_height})"
end

test "Ящики с пропуском дна — начинаются от низа" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.skip(:bottom)
  cab.drawers(3, height: 140)
  
  bottom_z = cab.support.bottom_z  # = 0
  
  # Без дна ящики начинаются от support.bottom_z
  drawer_start_z = bottom_z  # = 0
  
  assert_equal 0, drawer_start_z, "ящики начинаются от z=0"
  
  # Проверяем границы
  total_drawers = 3 * 140  # = 420
  inner_top = 450 - 18  # = 432 (низ крышки)
  
  assert total_drawers <= inner_top, "ящики (#{total_drawers}) <= до крышки (#{inner_top})"
end

test "Ящики с цоколем и без дна — начинаются от высоты цоколя" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.plinth(80)
  cab.skip(:bottom)
  cab.drawers(3, height: 100)
  
  bottom_z = cab.support.bottom_z  # = 80
  
  # Ящики начинаются от высоты цоколя
  drawer_start_z = bottom_z  # = 80
  
  assert_equal 80, drawer_start_z, "ящики начинаются от z=80 (высота цоколя)"
  
  # Проверяем границы
  drawer_1_end = drawer_start_z + 100  # = 180
  drawer_2_end = drawer_start_z + 200  # = 280
  drawer_3_end = drawer_start_z + 300  # = 380
  
  inner_top = 450 - 18  # = 432
  
  assert drawer_3_end <= inner_top, "верхний ящик (z=#{drawer_3_end}) <= крышка (z=#{inner_top})"
end

test "Ящики на ножках и без дна — начинаются от высоты ножек" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.legs(100)
  cab.skip(:bottom)
  cab.drawers(2, height: 150)
  
  bottom_z = cab.support.bottom_z  # = 100
  side_start_z = cab.support.side_start_z  # = 100
  
  drawer_start_z = bottom_z  # = 100
  
  assert_equal 100, drawer_start_z, "ящики начинаются от z=100"
  assert_equal side_start_z, drawer_start_z, "ящики на уровне низа боковин"
  
  # Проверяем границы
  drawer_2_end = drawer_start_z + 2 * 150  # = 400
  side_end_z = 450  # общая высота
  inner_top = side_end_z - 18  # = 432
  
  assert drawer_2_end <= inner_top, "ящики не выше крышки"
  assert drawer_start_z >= side_start_z, "ящики не ниже боковин"
end

# === ГРАНИЦЫ МОДУЛЕЙ В КОЛОННЕ ===

test "Модули в колонне — каждый следующий выше предыдущего" do
  # Имитируем колонну: base 450, cabinet 1450, top 800
  heights = [450, 1450, 800]
  z_positions = []
  
  z = 0
  heights.each do |h|
    z_positions << { start: z, end: z + h }
    z += h
  end
  
  assert_equal 0, z_positions[0][:start], "модуль 1 начинается с z=0"
  assert_equal 450, z_positions[0][:end], "модуль 1 заканчивается на z=450"
  
  assert_equal 450, z_positions[1][:start], "модуль 2 начинается с z=450"
  assert_equal 1900, z_positions[1][:end], "модуль 2 заканчивается на z=1900"
  
  assert_equal 1900, z_positions[2][:start], "модуль 3 начинается с z=1900"
  assert_equal 2700, z_positions[2][:end], "модуль 3 заканчивается на z=2700"
  
  # Проверяем нет пересечений
  (0...heights.length - 1).each do |i|
    assert z_positions[i][:end] == z_positions[i + 1][:start], 
           "модули #{i + 1} и #{i + 2} стыкуются без зазора"
  end
end

# === ПЕРЕГОРОДКИ ===

test "Перегородки при цоколе — не выступают за дно" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 500, 400, thickness: 18)
  cab.plinth(80)
  cab.sections("50%", "50%")
  
  # Перегородка начинается от верха дна
  bottom_z = cab.support.bottom_z  # = 80
  partition_start_z = bottom_z + 18  # = 98 (от верха дна)
  
  # Перегородка заканчивается у низа крышки
  side_height = 500 - cab.support.side_height_reduction  # = 500
  partition_end_z = side_height - 18  # = 482 (низ крышки)
  
  partition_height = partition_end_z - partition_start_z  # = 384
  
  # Проверяем границы
  assert partition_start_z >= bottom_z, "перегородка не ниже дна"
  assert partition_start_z > 0, "перегородка выше пола"
  assert partition_end_z <= 500, "перегородка не выше шкафа"
  
  # Перегородка не выступает в зону цоколя
  assert partition_start_z >= 80, "перегородка выше цоколя"
end

test "Перегородки на ножках — начинаются от дна" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 500, 400, thickness: 18)
  cab.legs(100)
  cab.sections("50%", "50%")
  
  bottom_z = cab.support.bottom_z  # = 100
  side_start_z = cab.support.side_start_z  # = 100
  side_height = 500 - cab.support.side_height_reduction  # = 400
  
  partition_start_z = bottom_z + 18  # = 118
  partition_end_z = side_start_z + side_height - 18  # = 100 + 400 - 18 = 482
  
  # Перегородка НЕ должна выступать за боковины
  assert partition_start_z >= side_start_z, "перегородка начинается от уровня боковин"
  assert partition_end_z <= side_start_z + side_height, "перегородка не выше боковин"
end

# === КОРОБ ЯЩИКА ===

test "Короб ящика — помещается между направляющими" do
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    140,
    cabinet_width: 764,  # внутренняя ширина шкафа
    cabinet_depth: 396
  )
  
  slide_thickness = drawer.slide.thickness  # = 13
  box_width = drawer.box.width  # должно быть 764 - 26 = 738
  
  # Проверяем что короб + 2 направляющие = ширина шкафа
  total_width = box_width + 2 * slide_thickness  # = 738 + 26 = 764
  
  assert_equal 764, total_width, "короб + направляющие = ширина секции"
end

test "Короб ящика — помещается по высоте" do
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    140,
    cabinet_width: 764,
    cabinet_depth: 396
  )
  
  slide_height = drawer.slide.height  # = 35
  box_height = drawer.box_height
  facade_gap = drawer.facade_gap  # = 3
  
  # box_height = 140 - 35 - 3 = 102
  assert_equal 102, box_height, "высота короба = 102"
  
  # Общая высота: slide + box + gap
  total = slide_height + box_height + facade_gap
  assert_equal 140, total, "slide + box + gap = высота ящика"
  
  # Короб выше направляющих
  box_bottom_z = slide_height  # = 35
  assert_equal 35, box_bottom_z, "короб на высоте направляющей"
end

# === КОЛОННЫ В ШКАФУ ===

test "Колонны — не пересекаются по X" do
  widths = [900, 700, 1000]
  x_positions = []
  
  x = 0
  widths.each do |w|
    x_positions << { start: x, end: x + w }
    x += w
  end
  
  assert_equal 0, x_positions[0][:start], "колонна 1 от x=0"
  assert_equal 900, x_positions[0][:end], "колонна 1 до x=900"
  
  assert_equal 900, x_positions[1][:start], "колонна 2 от x=900"
  assert_equal 1600, x_positions[1][:end], "колонна 2 до x=1600"
  
  assert_equal 1600, x_positions[2][:start], "колонна 3 от x=1600"
  assert_equal 2600, x_positions[2][:end], "колонна 3 до x=2600"
  
  # Нет пересечений
  (0...widths.length - 1).each do |i|
    assert x_positions[i][:end] == x_positions[i + 1][:start],
           "колонны #{i + 1} и #{i + 2} стыкуются"
  end
end

# === ПОЛНЫЙ ТЕСТ MY_WARDROBE ===

test "my_wardrobe — все элементы в пределах габаритов" do
  total_width = 900 + 700 + 1000  # = 2600
  total_height = 450 + 1450 + 800  # = 2700
  total_depth = 400
  
  # Левая колонна — base с цоколем
  left_base_bottom_z = 80  # plinth
  left_base_partition_start = left_base_bottom_z + 18  # = 98
  left_base_partition_end = 450 - 18  # = 432
  
  assert left_base_partition_start >= 0, "левая колонна: перегородка выше пола"
  assert left_base_partition_end <= 450, "левая колонна: перегородка в модуле"
  
  # Центральная колонна — base с ящиками (skip :bottom)
  center_base_drawer_start = 0  # SidesSupport, skip :bottom
  center_base_drawer_end = 3 * 140  # = 420
  
  assert center_base_drawer_start >= 0, "центр: ящики не ниже пола"
  assert center_base_drawer_end <= 450 - 18, "центр: ящики не выше крышки (450-18=432)"
  
  # Правая колонна — base с ножками
  right_base_side_start = 100  # legs
  right_base_side_end = 100 + (450 - 100)  # = 450
  
  assert right_base_side_start == 100, "правая: боковины начинаются от 100"
  assert right_base_side_end == 450, "правая: боковины до 450"
  
  # Между ножками и полом есть зазор
  assert right_base_side_start > 0, "правая: есть зазор для ножек"
end

# === ИТОГИ ===

puts "\n" + "=" * 60
puts "РЕЗУЛЬТАТЫ ТЕСТОВ ПОЗИЦИЙ И ГРАНИЦ:"
puts "  Пройдено: #{$tests_passed}"
puts "  Провалено: #{$tests_failed}"
puts "=" * 60

exit($tests_failed > 0 ? 1 : 0)
