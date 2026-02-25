# sketchup_furniture/tests/test_doors.rb
# Тесты для дверей

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
    def entityID; object_id; end
  end
  class Face
    def normal; Vector.new; end
    def pushpull(*args); end
  end
  class Vector; def z; 1; end; def y; 0; end; end
end

module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x = 0, y = 0, z = 0)
      @x = x; @y = y; @z = z
    end
  end
  class Vector3d
    def initialize(*args); end
  end
  class Transformation
    def self.translation(v); new; end
    def self.rotation(point, axis, angle); new; end
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

# === ТЕСТЫ DOOR ===

test "Door — создание" do
  door = SketchupFurniture::Components::Fronts::Door.new(
    400, 600, name: "Тест дверь"
  )
  
  assert_equal 400, door.width, "ширина"
  assert_equal 600, door.height, "высота"
  assert_equal "Тест дверь", door.name, "имя"
  assert_equal :left, door.hinge_side, "петли по умолчанию — слева"
end

test "Door — петли справа" do
  door = SketchupFurniture::Components::Fronts::Door.new(
    400, 600, hinge_side: :right
  )
  
  assert_equal :right, door.hinge_side, "петли справа"
end

test "Door — толщина фасада" do
  door = SketchupFurniture::Components::Fronts::Door.new(
    400, 600, facade_material: :ldsp_16
  )
  assert_equal 16, door.facade_thickness, "толщина ЛДСП 16"
  
  door2 = SketchupFurniture::Components::Fronts::Door.new(
    400, 600, facade_material: :mdf_19
  )
  assert_equal 19, door2.facade_thickness, "толщина МДФ 19"
end

test "Door — начальное состояние (закрыта)" do
  door = SketchupFurniture::Components::Fronts::Door.new(400, 600)
  assert !door.open?, "дверь закрыта"
end

test "Door — build генерирует cut item" do
  door = SketchupFurniture::Components::Fronts::Door.new(
    400, 600, name: "Дверь тест"
  )
  door.build
  
  cuts = door.all_cut_items
  assert_equal 1, cuts.length, "1 деталь в раскрое"
  assert_equal "Фасад", cuts[0].name, "название детали"
  assert_equal 600, cuts[0].length, "длина (большая сторона)"
  assert_equal 400, cuts[0].width, "ширина (меньшая сторона)"
end

test "Door — open/close" do
  door = SketchupFurniture::Components::Fronts::Door.new(400, 600)
  door.build
  
  assert !door.open?, "начальное — закрыта"
  
  door.open
  assert door.open?, "после open — открыта"
  
  door.close
  assert !door.open?, "после close — закрыта"
end

test "Door — open с углом" do
  door = SketchupFurniture::Components::Fronts::Door.new(400, 600)
  door.build
  
  door.open(45)
  assert door.open?, "открыта на 45°"
end

test "Door — нет фурнитуры (петли)" do
  door = SketchupFurniture::Components::Fronts::Door.new(400, 600)
  door.build
  
  hw = door.all_hardware_items
  assert_equal 0, hw.length, "нет фурнитуры"
end

test "Door — регистрируется в DrawerTool" do
  SketchupFurniture::Tools::DrawerTool.clear
  
  door = SketchupFurniture::Components::Fronts::Door.new(400, 600)
  door.build
  
  assert_equal 1, SketchupFurniture::Tools::DrawerTool.count, "зарегистрирована в DrawerTool"
end

# === ТЕСТЫ CABINET С ДВЕРЬЮ ===

test "Cabinet — door (1 дверь)" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door
  
  config = cab.instance_variable_get(:@doors_config)
  assert_equal 1, config[:count], "1 дверь"
end

test "Cabinet — doors 2 (две створки)" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.doors(2)
  
  config = cab.instance_variable_get(:@doors_config)
  assert_equal 2, config[:count], "2 двери"
end

test "Cabinet — door: build создаёт объект" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door
  cab.build
  
  assert_equal 1, cab.door_objects.length, "1 дверь создана"
end

test "Cabinet — doors 2: build создаёт 2 объекта" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.doors(2)
  cab.build
  
  assert_equal 2, cab.door_objects.length, "2 двери создано"
end

test "Cabinet — door: фасад в раскрое" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 1, facades.length, "1 фасад в раскрое"
end

test "Cabinet — doors 2: 2 фасада в раскрое" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.doors(2)
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 2, facades.length, "2 фасада в раскрое"
end

test "Cabinet — door: фасад покрывает боковины (cabinet_w - gap)" do
  # cabinet_w = 600, facade_gap = 3
  # facade_w = 600 - 3 = 597, facade_h = 700 - 3 = 697
  # CutItem: length = 697, width = 597
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 597, facades[0].width, "ширина фасада = cabinet_w - gap (597)"
end

test "Cabinet — door: высота фасада = side_height - gap" do
  # side_height = 700 (no plinth/legs)
  # facade_h = 700 - 3 = 697
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 697, facades[0].length, "высота фасада = side_height - gap (697)"
end

test "Cabinet — doors 2: ширины фасадов + зазоры = cabinet_width" do
  # cabinet_w = 800, 2 doors, facade_gap = 3
  # total_facade_w = 800 - 2*3 = 794, each door = 397
  # facade_h = 700 - 3 = 697
  # CutItem: length = 697, width = 397
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 700, 300, name: "Шкаф")
  cab.doors(2)
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  # width в CutItem = min(facade_w, facade_h) = facade_w (т.к. 397 < 697)
  widths = facades.map { |f| f.width }
  assert_equal 800, widths.sum + 2 * 3, "фасады + зазоры = cabinet_width"
end

test "Cabinet — doors 2: каждая створка ≈ половина ширины" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 700, 300, name: "Шкаф")
  cab.doors(2)
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  widths = facades.map { |f| f.width }
  
  widths.each do |w|
    assert_equal 397, w, "створка = 397 (половина от 794)"
  end
end

test "Cabinet — door: петли автоматически left" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door
  cab.build
  
  assert_equal :left, cab.door_objects[0].hinge_side, "петли слева"
end

test "Cabinet — doors 2: петли left + right" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 700, 300, name: "Шкаф")
  cab.doors(2)
  cab.build
  
  assert_equal :left, cab.door_objects[0].hinge_side, "левая дверь — петли слева"
  assert_equal :right, cab.door_objects[1].hinge_side, "правая дверь — петли справа"
end

test "Cabinet — door: нет фурнитуры" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door
  cab.build
  
  hw = cab.all_hardware_items
  hinges = hw.select { |h| h.name && h.name.include?("Петля") }
  assert_equal 0, hinges.length, "нет петель"
end

test "Cabinet — door с цоколем: высота учитывает plinth" do
  # height = 700, plinth = 100
  # PlinthSupport: side_height_reduction = 0, side_start_z = 0
  # side_height = 700 - 0 = 700
  # facade_h = 700 - 3 = 697
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.plinth(100)
  cab.door
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 1, facades.length, "1 фасад"
  assert_equal 697, facades[0].length, "высота фасада = 700 - 3"
end

test "Cabinet — door с ножками: высота фасада учитывает ножки" do
  # height = 700, legs = 100
  # LegsSupport: side_height_reduction = 100
  # side_height = 700 - 100 = 600
  # facade_h = 600 - 3 = 597
  # CutItem: length = max(597, 597) = 597, width = 597
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.legs(100)
  cab.door
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  # facade_w = 597, facade_h = 597 — оба одинаковые!
  assert_equal 597, facades[0].length, "высота фасада = 600 - 3 (с ножками)"
  assert_equal 597, facades[0].width, "ширина фасада = 600 - 3 (с ножками)"
end

test "Cabinet — door + полки: можно комбинировать" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.shelves([200, 400])
  cab.door
  cab.build
  
  assert_equal 1, cab.door_objects.length, "дверь создана"
  cuts = cab.all_cut_items
  shelves = cuts.select { |c| c.name.include?("Полка") }
  assert_equal 2, shelves.length, "полки на месте"
end

test "Cabinet — door: open/close работает" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door
  cab.build
  
  d = cab.door_objects[0]
  assert !d.open?, "начальное — закрыта"
  
  d.open
  assert d.open?, "открыта"
  
  d.close
  assert !d.open?, "закрыта"
end

test "Cabinet — door с материалом MDF" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door(facade_material: :mdf_19)
  cab.build
  
  cuts = cab.all_cut_items
  facades = cuts.select { |c| c.name.include?("Фасад") }
  assert_equal 19, facades[0].thickness, "толщина МДФ 19"
  assert_equal "МДФ", facades[0].material, "материал МДФ"
end

test "Cabinet — doors 2 зарегистрированы в DrawerTool" do
  SketchupFurniture::Tools::DrawerTool.clear
  
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 700, 300, name: "Шкаф")
  cab.doors(2)
  cab.build
  
  assert_equal 2, SketchupFurniture::Tools::DrawerTool.count, "2 двери зарегистрированы"
end

test "Cabinet — door + drawer: обе зарегистрированы" do
  SketchupFurniture::Tools::DrawerTool.clear
  
  # Нижний шкаф с ящиком + дверь верхнего
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door
  cab.build
  
  count_doors = SketchupFurniture::Tools::DrawerTool.count
  
  cab2 = SketchupFurniture::Assemblies::Cabinet.new(600, 300, 300, name: "Ящики")
  cab2.drawers(1, height: 150)
  cab2.build
  
  # 1 дверь + 1 ящик = 2
  assert_equal count_doors + 1, SketchupFurniture::Tools::DrawerTool.count, "дверь + ящик зарегистрированы"
end

# === ИТОГИ ===

puts "\n" + "=" * 50
puts "РЕЗУЛЬТАТЫ: #{$tests_passed} пройдено, #{$tests_failed} провалено"
puts "=" * 50

exit($tests_failed > 0 ? 1 : 0)
