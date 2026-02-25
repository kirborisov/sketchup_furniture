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

# === ТЕСТЫ РАМОЧНОЙ ДВЕРИ (FrameDoor) ===

test "FrameDoor — создание с параметрами по умолчанию" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600)
  
  assert_equal 50, door.frame_width, "ширина бруска = 50"
  assert_equal 20, door.frame_thickness, "толщина рамки = 20"
  assert_equal 10, door.tenon, "шип = 10"
  assert_equal 2, door.panel_gap, "зазор филёнки = 2"
  assert_equal 6, door.panel_thickness, "толщина филёнки = 6"
  assert_equal 10, door.groove_depth, "глубина паза = 10 (= tenon)"
end

test "FrameDoor — наследует Door" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600)
  assert door.is_a?(SketchupFurniture::Components::Fronts::Door), "is_a? Door"
end

test "FrameDoor — толщина фасада = frame_thickness" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600, frame_thickness: 22)
  assert_equal 22, door.facade_thickness, "толщина фасада = frame_thickness"
end

test "FrameDoor — frame_thickness из конфига" do
  old = SketchupFurniture.config.frame_thickness
  SketchupFurniture.config.frame_thickness = 25
  
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600)
  assert_equal 25, door.frame_thickness, "из конфига"
  
  SketchupFurniture.config.frame_thickness = old
end

test "FrameDoor — frame_thickness явный переопределяет конфиг" do
  old = SketchupFurniture.config.frame_thickness
  SketchupFurniture.config.frame_thickness = 25
  
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600, frame_thickness: 18)
  assert_equal 18, door.frame_thickness, "явный = 18"
  
  SketchupFurniture.config.frame_thickness = old
end

test "FrameDoor — расчёт внутреннего проёма" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600, frame_width: 50)
  
  assert_equal 300, door.inner_opening_width, "проём ширина = 300"
  assert_equal 500, door.inner_opening_height, "проём высота = 500"
end

test "FrameDoor — расчёт размеров филёнки" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(
    400, 600, frame_width: 50, groove_depth: 10, panel_gap: 2
  )
  
  assert_equal 316, door.panel_width, "ширина филёнки = 316"
  assert_equal 516, door.panel_height, "высота филёнки = 516"
end

test "FrameDoor — расчёт длины поперечины (с шипами)" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(
    400, 600, frame_width: 50, tenon: 10
  )
  
  assert_equal 320, door.rail_length, "длина поперечины = 320"
end

test "FrameDoor — ширина паза = толщина филёнки" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600, panel_thickness: 6)
  assert_equal 6, door.groove_width, "ширина паза = 6"
end

test "FrameDoor — смещение паза (центрирован)" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(
    400, 600, frame_thickness: 20, panel_thickness: 6
  )
  assert_equal 7, door.groove_offset, "смещение паза = 7"
end

test "FrameDoor — custom frame_width" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600, frame_width: 40)
  assert_equal 40, door.frame_width, "frame_width = 40"
  assert_equal 320, door.inner_opening_width, "проём = 320"
end

test "FrameDoor — custom groove_depth отличается от tenon" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(
    400, 600, tenon: 10, groove_depth: 12
  )
  assert_equal 10, door.tenon, "шип = 10"
  assert_equal 12, door.groove_depth, "паз = 12"
  assert_equal 320, door.panel_width, "ширина филёнки с groove=12"
end

test "FrameDoor — build генерирует cut items" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600, frame_width: 50)
  door.build
  
  cuts = door.all_cut_items
  assert_equal 5, cuts.length, "5 деталей в раскрое"
end

test "FrameDoor — стойки в раскрое" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(
    400, 600, frame_width: 50, frame_thickness: 20
  )
  door.build
  
  cuts = door.all_cut_items
  stiles = cuts.select { |c| c.name == "Стойка рамки" }
  assert_equal 2, stiles.length, "2 стойки"
  
  stiles.each do |s|
    assert_equal 600, s.length, "длина стойки = высота двери"
    assert_equal 50, s.width, "ширина стойки = frame_width"
    assert_equal 20, s.thickness, "толщина = frame_thickness"
    assert_equal "Массив", s.material, "материал = Массив"
  end
end

test "FrameDoor — поперечины в раскрое (с шипами)" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(
    400, 600, frame_width: 50, tenon: 10
  )
  door.build
  
  cuts = door.all_cut_items
  rails = cuts.select { |c| c.name == "Поперечина рамки" }
  assert_equal 2, rails.length, "2 поперечины"
  
  rails.each do |r|
    assert_equal 320, r.length, "длина поперечины (с шипами)"
    assert_equal 50, r.width, "ширина поперечины = frame_width"
    assert_equal "Массив", r.material, "материал = Массив"
  end
end

test "FrameDoor — филёнка в раскрое" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(
    400, 600, frame_width: 50, groove_depth: 10, panel_gap: 2, panel_thickness: 6
  )
  door.build
  
  cuts = door.all_cut_items
  panels = cuts.select { |c| c.name == "Филёнка" }
  assert_equal 1, panels.length, "1 филёнка"
  
  p = panels[0]
  assert_equal 516, p.length, "длина филёнки (большая сторона)"
  assert_equal 316, p.width, "ширина филёнки (меньшая сторона)"
  assert_equal 6, p.thickness, "толщина = 6мм"
  assert_equal "Фанера", p.material, "материал = Фанера"
end

test "FrameDoor — нет фурнитуры" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600)
  door.build
  
  assert_equal 0, door.all_hardware_items.length, "нет фурнитуры"
end

test "FrameDoor — open/close наследуется" do
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600)
  door.build
  
  assert !door.open?, "закрыта"
  door.open
  assert door.open?, "открыта"
  door.close
  assert !door.open?, "закрыта"
end

test "FrameDoor — регистрируется в DrawerTool" do
  SketchupFurniture::Tools::DrawerTool.clear
  
  door = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600)
  door.build
  
  assert_equal 1, SketchupFurniture::Tools::DrawerTool.count, "зарегистрирована"
end

test "FrameDoor — hinge_side" do
  dl = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600, hinge_side: :left)
  assert_equal :left, dl.hinge_side, "петли слева"
  
  dr = SketchupFurniture::Components::Fronts::FrameDoor.new(400, 600, hinge_side: :right)
  assert_equal :right, dr.hinge_side, "петли справа"
end

test "Door :solid — не имеет frame-методов" do
  door = SketchupFurniture::Components::Fronts::Door.new(400, 600)
  
  assert !door.respond_to?(:inner_opening_width), "нет inner_opening_width"
  assert !door.respond_to?(:panel_width), "нет panel_width"
  assert !door.respond_to?(:rail_length), "нет rail_length"
end

# === ТЕСТЫ CABINET + FRAME DOOR ===

test "Cabinet — door type: :frame создаёт FrameDoor" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door(type: :frame)
  cab.build
  
  assert_equal 1, cab.door_objects.length, "1 дверь создана"
  assert cab.door_objects[0].is_a?(SketchupFurniture::Components::Fronts::FrameDoor), "FrameDoor"
end

test "Cabinet — doors 2, type: :frame создаёт FrameDoor" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 700, 300, name: "Шкаф")
  cab.doors(2, type: :frame)
  cab.build
  
  assert_equal 2, cab.door_objects.length, "2 двери"
  cab.door_objects.each { |d| assert d.is_a?(SketchupFurniture::Components::Fronts::FrameDoor), "FrameDoor" }
end

test "Cabinet — door без type создаёт Door (solid)" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door
  cab.build
  
  d = cab.door_objects[0]
  assert d.is_a?(SketchupFurniture::Components::Fronts::Door), "Door"
  assert !d.is_a?(SketchupFurniture::Components::Fronts::FrameDoor), "не FrameDoor"
end

test "Cabinet — frame door: 5 cut items в раскрое на дверь" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door(type: :frame)
  cab.build
  
  cuts = cab.all_cut_items
  stiles = cuts.select { |c| c.name == "Стойка рамки" }
  rails = cuts.select { |c| c.name == "Поперечина рамки" }
  panels = cuts.select { |c| c.name == "Филёнка" }
  
  assert_equal 2, stiles.length, "2 стойки"
  assert_equal 2, rails.length, "2 поперечины"
  assert_equal 1, panels.length, "1 филёнка"
end

test "Cabinet — frame door с custom параметрами" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.door(type: :frame, frame_width: 40, panel_thickness: 8)
  cab.build
  
  d = cab.door_objects[0]
  assert_equal 40, d.frame_width, "frame_width = 40"
  assert_equal 8, d.panel_thickness, "panel_thickness = 8"
end

test "Cabinet — doors 2, type: :frame: раскрой 10 деталей" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 700, 300, name: "Шкаф")
  cab.doors(2, type: :frame)
  cab.build
  
  cuts = cab.all_cut_items
  stiles = cuts.select { |c| c.name == "Стойка рамки" }
  rails = cuts.select { |c| c.name == "Поперечина рамки" }
  panels = cuts.select { |c| c.name == "Филёнка" }
  
  assert_equal 4, stiles.length, "4 стойки (2 двери × 2)"
  assert_equal 4, rails.length, "4 поперечины"
  assert_equal 2, panels.length, "2 филёнки"
end

test "Cabinet — frame door + полки совмещаются" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 700, 300, name: "Шкаф")
  cab.shelves([200, 400])
  cab.door(type: :frame)
  cab.build
  
  assert_equal 1, cab.door_objects.length, "дверь создана"
  cuts = cab.all_cut_items
  shelves = cuts.select { |c| c.name.include?("Полка") }
  assert_equal 2, shelves.length, "полки на месте"
end

# === ТЕСТЫ CONFIG ===

test "Config — frame_thickness по умолчанию 20" do
  cfg = SketchupFurniture::Core::Config.new
  assert_equal 20, cfg.frame_thickness, "frame_thickness = 20"
end

test "Config — frame_thickness можно менять" do
  old = SketchupFurniture.config.frame_thickness
  SketchupFurniture.config.frame_thickness = 22
  assert_equal 22, SketchupFurniture.config.frame_thickness, "frame_thickness = 22"
  SketchupFurniture.config.frame_thickness = old
end

# === ИТОГИ ===

puts "\n" + "=" * 50
puts "РЕЗУЛЬТАТЫ: #{$tests_passed} пройдено, #{$tests_failed} провалено"
puts "=" * 50

exit($tests_failed > 0 ? 1 : 0)
