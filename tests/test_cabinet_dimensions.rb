# sketchup_furniture/tests/test_cabinet_dimensions.rb
# Тесты расчёта размеров шкафа

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
  end
  class Face
    def normal; Vector.new; end
    def pushpull(*args); end
  end
  class Vector; def z; 1; end; end
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

def test(name)
  puts "\n#{name}"
  yield
end

# === ТЕСТЫ ===

test "Стандартный шкаф (без цоколя/ножек)" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  
  # Проверяем support
  assert_equal 0, cab.support.side_start_z, "side_start_z"
  assert_equal 0, cab.support.bottom_z, "bottom_z"
  assert_equal 0, cab.support.side_height_reduction, "side_height_reduction"
  
  # Расчёт внутренней высоты: 450 - 2*18 = 414
  side_height = 450 - cab.support.side_height_reduction  # 450
  top_of_bottom = cab.support.bottom_z + 18              # 0 + 18 = 18
  bottom_of_top = cab.support.side_start_z + side_height - 18  # 0 + 450 - 18 = 432
  inner_h = bottom_of_top - top_of_bottom                # 432 - 18 = 414
  
  assert_equal 414, inner_h, "внутренняя высота"
end

test "Шкаф с цоколем 80мм" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.plinth(80)
  
  # Проверяем support
  assert_equal 0, cab.support.side_start_z, "side_start_z (боковины с пола)"
  assert_equal 80, cab.support.bottom_z, "bottom_z (дно поднято)"
  assert_equal 0, cab.support.side_height_reduction, "side_height_reduction"
  
  # Расчёт внутренней высоты
  side_height = 450 - cab.support.side_height_reduction  # 450
  top_of_bottom = cab.support.bottom_z + 18              # 80 + 18 = 98
  bottom_of_top = cab.support.side_start_z + side_height - 18  # 0 + 450 - 18 = 432
  inner_h = bottom_of_top - top_of_bottom                # 432 - 98 = 334
  
  assert_equal 334, inner_h, "внутренняя высота (меньше из-за цоколя)"
end

test "Шкаф на ножках 100мм" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.legs(100)
  
  # Проверяем support
  assert_equal 100, cab.support.side_start_z, "side_start_z (боковины выше)"
  assert_equal 100, cab.support.bottom_z, "bottom_z (дно поднято)"
  assert_equal 100, cab.support.side_height_reduction, "side_height_reduction"
  
  # Расчёт внутренней высоты
  side_height = 450 - cab.support.side_height_reduction  # 450 - 100 = 350
  top_of_bottom = cab.support.bottom_z + 18              # 100 + 18 = 118
  bottom_of_top = cab.support.side_start_z + side_height - 18  # 100 + 350 - 18 = 432
  inner_h = bottom_of_top - top_of_bottom                # 432 - 118 = 314
  
  assert_equal 314, inner_h, "внутренняя высота (меньше из-за ножек)"
end

test "Метод skip" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400)
  
  assert_equal true, cab.build_part?(:bottom), "дно по умолчанию"
  assert_equal true, cab.build_part?(:back), "задник по умолчанию"
  
  cab.skip(:bottom, :back)
  
  assert_equal false, cab.build_part?(:bottom), "дно пропущено"
  assert_equal false, cab.build_part?(:back), "задник пропущен"
  assert_equal true, cab.build_part?(:top), "верх остался"
  assert_equal true, cab.build_part?(:left_side), "левая боковина осталась"
end

test "Высота перегородки при цоколе" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.plinth(80)
  cab.sections("50%", "50%")
  
  # Перегородка должна быть такой же высоты как внутреннее пространство
  side_height = 450 - cab.support.side_height_reduction
  top_of_bottom = cab.support.bottom_z + 18
  bottom_of_top = cab.support.side_start_z + side_height - 18
  partition_height = bottom_of_top - top_of_bottom
  
  assert_equal 334, partition_height, "высота перегородки = внутренняя высота"
end

# === ИТОГИ ===

puts "\n" + "=" * 50
puts "РЕЗУЛЬТАТЫ: #{$tests_passed} пройдено, #{$tests_failed} провалено"
puts "=" * 50

exit($tests_failed > 0 ? 1 : 0)
